#!/usr/bin/env python3
"""TOML case configuration loader and native namelist overlay renderer."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import pathlib
import re
import shlex
import sys
import tomllib

ROOT = pathlib.Path(__file__).resolve().parents[1]


def die(message: str, code: int = 2) -> None:
    print(f"wrfkit config: {message}", file=sys.stderr)
    raise SystemExit(code)


def load_case(name: str):
    if not re.fullmatch(r"[A-Za-z0-9._-]+", name):
        die(f"invalid case name: {name}")
    case_dir = ROOT / "cases" / name
    path = case_dir / "case.toml"
    if not case_dir.is_dir():
        die(f"case not found: {case_dir}")
    if not path.is_file():
        die(f"case.toml not found: {path}")
    try:
        with path.open("rb") as handle:
            data = tomllib.load(handle)
    except tomllib.TOMLDecodeError as exc:
        die(f"{path}: {exc}")
    version = data.get("schema_version", 1)
    if version != 1:
        die(f"unsupported schema_version: {version}")
    return case_dir, data


def utc_datetime(value, field: str) -> dt.datetime:
    if isinstance(value, dt.datetime):
        result = value
    elif isinstance(value, str):
        try:
            result = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            die(f"{field} must be an ISO-8601 datetime")
    else:
        die(f"{field} must be a TOML datetime or ISO-8601 string")
    if result.tzinfo is None:
        die(f"{field} must include an explicit UTC offset; use a trailing Z")
    return result.astimezone(dt.timezone.utc)


def forcing_settings(data):
    forcing = data.get("forcing")
    if not isinstance(forcing, dict):
        die("missing [forcing] table")
    provider = str(forcing.get("provider", "")).lower()
    if provider != "gfs":
        die(f"unsupported forcing.provider for current implementation: {provider!r}")

    product = str(forcing.get("product", "0p25"))
    if product != "0p25":
        die(f"unsupported GFS product for current implementation: {product!r}")

    cycle = utc_datetime(forcing.get("cycle"), "forcing.cycle")
    if cycle.minute or cycle.second or cycle.microsecond or cycle.hour not in (0, 6, 12, 18):
        die("forcing.cycle must be a GFS cycle at 00/06/12/18 UTC")

    hours = forcing.get("forecast_hours")
    if not isinstance(hours, list) or not hours or any(
        not isinstance(value, int) or value < 0 for value in hours
    ):
        die("forcing.forecast_hours must be a non-empty array of non-negative integers")

    subset = forcing.get("subset")
    if not isinstance(subset, dict):
        die("missing [forcing.subset] table")
    for key in ("west", "east", "north", "south"):
        if key not in subset or not isinstance(subset[key], (int, float)):
            die(f"forcing.subset.{key} must be numeric")

    return {
        "FORCING_PROVIDER": provider,
        "GFS_PRODUCT": product,
        "GFS_DATE": cycle.strftime("%Y%m%d"),
        "GFS_CYCLE": cycle.strftime("%H"),
        "GFS_FORECAST_HOURS": " ".join(f"{value:03d}" for value in hours),
        "GFS_LEFTLON": str(subset["west"]),
        "GFS_RIGHTLON": str(subset["east"]),
        "GFS_TOPLAT": str(subset["north"]),
        "GFS_BOTTOMLAT": str(subset["south"]),
    }


def validate_time_forcing(data) -> None:
    time = data.get("time")
    if not isinstance(time, dict) or "start" not in time or "end" not in time:
        return
    start = utc_datetime(time["start"], "time.start")
    end = utc_datetime(time["end"], "time.end")
    if end <= start:
        die("time.end must be after time.start")

    forcing = data.get("forcing", {})
    if str(forcing.get("provider", "")).lower() != "gfs":
        return
    cycle = utc_datetime(forcing.get("cycle"), "forcing.cycle")
    hours = forcing.get("forecast_hours", [])
    available = {cycle + dt.timedelta(hours=value) for value in hours}
    interval = time.get("forcing_interval_seconds")
    if interval is None:
        return
    if not isinstance(interval, int) or interval <= 0:
        die("time.forcing_interval_seconds must be a positive integer")
    duration_seconds = int((end - start).total_seconds())
    if duration_seconds % interval != 0:
        die("time range must be an integer multiple of time.forcing_interval_seconds")

    required = set()
    current = start
    while current <= end:
        required.add(current)
        current += dt.timedelta(seconds=interval)
    missing = sorted(required - available)
    if missing:
        rendered = ", ".join(value.strftime("%Y-%m-%d %HZ") for value in missing)
        die(f"GFS forecast_hours do not cover required WPS times: {rendered}")


def shell_env(name: str) -> None:
    _, data = load_case(name)
    validate_time_forcing(data)
    env = forcing_settings(data)
    geography = data.get("geography", {})
    env["GEOG_DATASET"] = str(geography.get("dataset", ""))
    env["GEOG_RESOLUTION"] = str(geography.get("resolution", ""))
    domain = data.get("domain", {})
    env["MAX_DOM"] = str(domain.get("max_dom", 1))
    for key, value in env.items():
        print(f"{key}={shlex.quote(value)}")


def format_scalar(value):
    if isinstance(value, bool):
        return ".true." if value else ".false."
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return repr(value)
    if isinstance(value, dt.datetime):
        value = utc_datetime(value, "advanced namelist datetime")
        return "'" + value.strftime("%Y-%m-%d_%H:%M:%S") + "'"
    if isinstance(value, str):
        return "'" + value.replace("'", "''") + "'"
    die(f"unsupported TOML value type in namelist override: {type(value).__name__}")


def format_value(value, raw: bool = False):
    if raw:
        if not isinstance(value, str):
            die("raw namelist override values must be TOML strings")
        return value
    if isinstance(value, list):
        return ", ".join(format_scalar(item) for item in value)
    return format_scalar(value)


def patch_namelist(path: pathlib.Path, patches) -> bool:
    original = path.read_text()
    lines = original.splitlines()

    for section, values in patches.items():
        section_re = re.compile(rf"^\s*&{re.escape(section)}\b", re.IGNORECASE)
        start = next((i for i, line in enumerate(lines) if section_re.search(line)), None)
        if start is None:
            if lines and lines[-1].strip():
                lines.append("")
            lines.append(f"&{section}")
            for key, value in values.items():
                lines.append(f" {key:<35} = {value},")
            lines.append("/")
            continue

        end = next(
            (
                i
                for i in range(start + 1, len(lines))
                if re.match(r"^\s*/\s*(?:!.*)?$", lines[i])
            ),
            None,
        )
        if end is None:
            die(f"{path}: unterminated &{section} namelist section")

        for key, value in values.items():
            key_re = re.compile(rf"^(\s*){re.escape(key)}\s*=", re.IGNORECASE)
            index = next(
                (i for i in range(start + 1, end) if key_re.search(lines[i])), None
            )
            rendered = f" {key:<35} = {value},"

            if index is None:
                lines.insert(end, rendered)
                end += 1
                continue

            # Preserve the native file's existing whitespace and inline comment.
            # case.toml is an overlay, not a namelist formatter: changing one
            # value should not create unrelated formatting churn in Git diffs.
            existing = lines[index]
            value_match = re.match(
                rf"^(\s*{re.escape(key)}\s*=\s*)(.*?)(\s*,\s*)(!.*)?$",
                existing,
                re.IGNORECASE,
            )
            if value_match:
                prefix, _, comma, comment = value_match.groups()
                lines[index] = f"{prefix}{value}{comma}{comment or ''}"
            else:
                indent = key_re.search(existing).group(1)
                lines[index] = f"{indent}{key:<35} = {value},"

            # If the overwritten value was a multiline array, discard plain
            # continuation lines while retaining following comments/assignments.
            j = index + 1
            while j < end:
                stripped = lines[j].strip()
                if not stripped or stripped.startswith("!"):
                    break
                if re.match(
                    r"^[A-Za-z_][A-Za-z0-9_%]*(?:\([^)]*\))?\s*=", stripped
                ):
                    break
                if stripped == "/":
                    break
                del lines[j]
                end -= 1

    updated = "\n".join(lines) + ("\n" if original.endswith("\n") else "")
    if updated == original:
        return False

    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(updated)
    temporary.replace(path)
    return True


def build_patches(data):
    wps, wrf = {}, {}

    def set_value(target, section, key, value, raw=False):
        target.setdefault(section, {})[key] = format_value(value, raw=raw)

    namelist = data.get("namelist", {})
    managed = bool(namelist.get("managed", True))
    if not managed:
        return managed, wps, wrf

    domain = data.get("domain", {})
    max_dom = int(domain.get("max_dom", 1))
    if max_dom < 1:
        die("domain.max_dom must be >= 1")

    for key in (
        "parent_id",
        "parent_grid_ratio",
        "i_parent_start",
        "j_parent_start",
        "e_we",
        "e_sn",
        "e_vert",
        "parent_time_step_ratio",
    ):
        value = domain.get(key)
        if isinstance(value, list) and len(value) != max_dom:
            die(f"domain.{key} must contain exactly domain.max_dom values")

    time = data.get("time", {})
    if "start" in time and "end" in time:
        start = utc_datetime(time["start"], "time.start")
        end = utc_datetime(time["end"], "time.end")
        if end <= start:
            die("time.end must be after time.start")
        set_value(wps, "share", "start_date", [start.strftime("%Y-%m-%d_%H:%M:%S")] * max_dom)
        set_value(wps, "share", "end_date", [end.strftime("%Y-%m-%d_%H:%M:%S")] * max_dom)

        for key, attribute, width in (
            ("start_year", "year", 4),
            ("start_month", "month", 2),
            ("start_day", "day", 2),
            ("start_hour", "hour", 2),
            ("start_minute", "minute", 2),
            ("start_second", "second", 2),
        ):
            component = getattr(start, attribute)
            set_value(
                wrf,
                "time_control",
                key,
                ", ".join(f"{component:0{width}d}" for _ in range(max_dom)),
                raw=True,
            )
        for key, attribute, width in (
            ("end_year", "year", 4),
            ("end_month", "month", 2),
            ("end_day", "day", 2),
            ("end_hour", "hour", 2),
            ("end_minute", "minute", 2),
            ("end_second", "second", 2),
        ):
            component = getattr(end, attribute)
            set_value(
                wrf,
                "time_control",
                key,
                ", ".join(f"{component:0{width}d}" for _ in range(max_dom)),
                raw=True,
            )

        duration = int((end - start).total_seconds())
        days, remainder = divmod(duration, 86400)
        hours, remainder = divmod(remainder, 3600)
        minutes, seconds = divmod(remainder, 60)
        for key, value in (
            ("run_days", days),
            ("run_hours", hours),
            ("run_minutes", minutes),
            ("run_seconds", seconds),
        ):
            set_value(wrf, "time_control", key, value)

    interval = time.get("forcing_interval_seconds")
    if interval is not None:
        set_value(wps, "share", "interval_seconds", interval)
        set_value(wrf, "time_control", "interval_seconds", interval)

    set_value(wps, "share", "max_dom", max_dom)
    set_value(wrf, "domains", "max_dom", max_dom)

    for key in (
        "parent_id",
        "parent_grid_ratio",
        "i_parent_start",
        "j_parent_start",
        "e_we",
        "e_sn",
    ):
        if key in domain:
            set_value(wps, "geogrid", key, domain[key])

    for key in ("dx", "dy"):
        if key in domain:
            value = domain[key][0] if isinstance(domain[key], list) else domain[key]
            set_value(wps, "geogrid", key, value)

    for key in (
        "map_proj",
        "ref_lat",
        "ref_lon",
        "truelat1",
        "truelat2",
        "stand_lon",
        "pole_lat",
        "pole_lon",
    ):
        if key in domain:
            set_value(wps, "geogrid", key, domain[key])

    geography = data.get("geography", {})
    if "resolution" in geography:
        value = geography["resolution"]
        if not isinstance(value, list):
            value = [value] * max_dom
        set_value(wps, "geogrid", "geog_data_res", value)
    set_value(wps, "geogrid", "geog_data_path", "geog")

    for key in (
        "e_we",
        "e_sn",
        "e_vert",
        "parent_grid_ratio",
        "i_parent_start",
        "j_parent_start",
        "parent_time_step_ratio",
        "feedback",
        "smooth_option",
        "p_top_requested",
    ):
        if key in domain:
            set_value(wrf, "domains", key, domain[key])
    for key in ("dx", "dy"):
        if key in domain:
            set_value(wrf, "domains", key, domain[key])
    if "parent_id" in domain:
        identifiers = (
            list(domain["parent_id"])
            if isinstance(domain["parent_id"], list)
            else [domain["parent_id"]]
        )
        if identifiers:
            identifiers[0] = 0
        set_value(wrf, "domains", "parent_id", identifiers)
    if "time_step" in domain:
        set_value(wrf, "domains", "time_step", domain["time_step"])

    model = data.get("model", {})
    if "time_step" in model:
        set_value(wrf, "domains", "time_step", model["time_step"])

    physics = data.get("physics", {})
    if "suite" in physics:
        set_value(wrf, "physics", "physics_suite", physics["suite"])

    output = data.get("output", {})
    if "history_interval_minutes" in output:
        set_value(wrf, "time_control", "history_interval", output["history_interval_minutes"])
    if "frames_per_outfile" in output:
        set_value(wrf, "time_control", "frames_per_outfile", output["frames_per_outfile"])
    if "restart" in output:
        set_value(wrf, "time_control", "restart", output["restart"])
    if "restart_interval_minutes" in output:
        set_value(wrf, "time_control", "restart_interval", output["restart_interval_minutes"])

    # Escape hatch: every table below advanced.wps/advanced.wrf maps directly
    # to a native namelist group. Unknown section/key names are intentionally
    # accepted so new WRF/WPS options do not require a wrfkit release.
    advanced = data.get("advanced", {})
    for family, target, raw in (
        ("wps", wps, False),
        ("wrf", wrf, False),
        ("wps_raw", wps, True),
        ("wrf_raw", wrf, True),
    ):
        tables = advanced.get(family, {})
        if not tables:
            continue
        if not isinstance(tables, dict):
            die(f"[advanced.{family}] must contain namelist section tables")
        for section, values in tables.items():
            if not isinstance(values, dict):
                die(f"[advanced.{family}.{section}] must be a table")
            for key, value in values.items():
                set_value(target, section, key, value, raw=raw)

    return managed, wps, wrf


def configure(name: str, check_only: bool) -> None:
    case_dir, data = load_case(name)
    validate_time_forcing(data)
    managed, wps, wrf = build_patches(data)

    for filename in ("namelist.wps", "namelist.input"):
        if not (case_dir / filename).is_file():
            die(f"{filename} not found: {case_dir / filename}")

    print(f"Case: {name}")
    print(f"  TOML: {case_dir / 'case.toml'}")
    print(f"  namelist managed: {'true' if managed else 'false'}")

    if not managed:
        print("  native namelists: read-only (wrfkit will not modify them)")
        return

    print(f"  WPS overrides: {sum(map(len, wps.values()))}")
    print(f"  WRF overrides: {sum(map(len, wrf.values()))}")

    if check_only:
        print("  check only: no files changed")
        return

    wps_changed = patch_namelist(case_dir / "namelist.wps", wps)
    wrf_changed = patch_namelist(case_dir / "namelist.input", wrf)
    print(f"  namelist.wps: {'updated' if wps_changed else 'unchanged'}")
    print(f"  namelist.input: {'updated' if wrf_changed else 'unchanged'}")


def display_value(value) -> str:
    if isinstance(value, list):
        return "[" + ", ".join(str(item) for item in value) + "]"
    return str(value)


def display_datetime(value, field: str) -> str:
    return utc_datetime(value, field).strftime("%Y-%m-%d %H:%M:%SZ")


def summarize_case(name: str) -> None:
    _, data = load_case(name)
    validate_time_forcing(data)
    managed, wps, wrf = build_patches(data)

    print("Scientific configuration")
    print(f"  case:        {name}")

    time = data.get("time", {})
    if "start" in time and "end" in time:
        print(
            "  period:      "
            f"{display_datetime(time['start'], 'time.start')} -> "
            f"{display_datetime(time['end'], 'time.end')}"
        )
    if "forcing_interval_seconds" in time:
        print(f"  input step:  {time['forcing_interval_seconds']} s")

    forcing = data.get("forcing", {})
    print(f"  forcing:     {forcing.get('provider', '<unset>')} {forcing.get('product', '<unset>')}")
    if "cycle" in forcing:
        print(f"  cycle:       {display_datetime(forcing['cycle'], 'forcing.cycle')}")
    if "forecast_hours" in forcing:
        print(f"  fcst hours:  {display_value(forcing['forecast_hours'])}")
    subset = forcing.get("subset", {})
    if isinstance(subset, dict) and all(k in subset for k in ("west", "east", "south", "north")):
        print(
            "  subset:      "
            f"W={subset['west']} E={subset['east']} "
            f"S={subset['south']} N={subset['north']}"
        )

    geography = data.get("geography", {})
    print(
        "  geography:   "
        f"{geography.get('dataset', '<unset>')} "
        f"({geography.get('resolution', '<unset>')})"
    )

    domain = data.get("domain", {})
    print(f"  domains:     {domain.get('max_dom', 1)}")
    for key, label, suffix in (
        ("dx", "dx", " m"),
        ("dy", "dy", " m"),
        ("e_we", "e_we", ""),
        ("e_sn", "e_sn", ""),
        ("e_vert", "e_vert", ""),
    ):
        if key in domain:
            print(f"  {label + ':':12}{display_value(domain[key])}{suffix}")

    model = data.get("model", {})
    if "time_step" in model:
        print(f"  time step:   {model['time_step']} s")

    physics = data.get("physics", {})
    if "suite" in physics:
        print(f"  physics:     {physics['suite']}")

    output = data.get("output", {})
    if "history_interval_minutes" in output:
        print(f"  history:     {output['history_interval_minutes']} min")

    advanced = data.get("advanced", {})
    advanced_wps = sum(
        len(values)
        for family in ("wps", "wps_raw")
        for values in advanced.get(family, {}).values()
        if isinstance(values, dict)
    )
    advanced_wrf = sum(
        len(values)
        for family in ("wrf", "wrf_raw")
        for values in advanced.get(family, {}).values()
        if isinstance(values, dict)
    )

    if managed:
        print(
            "  namelists:   managed "
            f"({sum(map(len, wps.values()))} WPS / "
            f"{sum(map(len, wrf.values()))} WRF overrides)"
        )
    else:
        print("  namelists:   manual/read-only")
    if advanced_wps or advanced_wrf:
        print(f"  advanced:    {advanced_wps} WPS / {advanced_wrf} WRF native overrides")


def normalized_for_fingerprint(value):
    if isinstance(value, dt.datetime):
        if value.tzinfo is None:
            return value.isoformat()
        return value.astimezone(dt.timezone.utc).isoformat()
    if isinstance(value, dt.date):
        return value.isoformat()
    if isinstance(value, dt.time):
        return value.isoformat()
    if isinstance(value, dict):
        return {
            key: normalized_for_fingerprint(item)
            for key, item in sorted(value.items())
        }
    if isinstance(value, list):
        return [normalized_for_fingerprint(item) for item in value]
    return value


def case_fingerprint(name: str) -> None:
    _, data = load_case(name)
    validate_time_forcing(data)

    relevant = dict(data)
    case_meta = dict(relevant.get("case", {}))
    case_meta.pop("description", None)
    if case_meta:
        relevant["case"] = case_meta
    else:
        relevant.pop("case", None)

    payload = json.dumps(
        normalized_for_fingerprint(relevant),
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    ).encode("utf-8")
    print(hashlib.sha256(payload).hexdigest())


def main() -> None:
    parser = argparse.ArgumentParser(description="wrfkit TOML case configuration")
    commands = parser.add_subparsers(dest="command", required=True)

    env_parser = commands.add_parser("env", help="emit shell-safe resolved case variables")
    env_parser.add_argument("--case", required=True)

    summary_parser = commands.add_parser(
        "summary", help="show resolved scientific configuration without changing files"
    )
    summary_parser.add_argument("--case", required=True)

    fingerprint_parser = commands.add_parser(
        "fingerprint", help="emit a preparation-relevant case fingerprint"
    )
    fingerprint_parser.add_argument("--case", required=True)

    config_parser = commands.add_parser(
        "config", help="validate case.toml and update managed native namelists"
    )
    config_parser.add_argument("--case", required=True)
    config_parser.add_argument(
        "--check", action="store_true", help="validate and show the plan without writing files"
    )

    args = parser.parse_args()
    if args.command == "env":
        shell_env(args.case)
    elif args.command == "summary":
        summarize_case(args.case)
    elif args.command == "fingerprint":
        case_fingerprint(args.case)
    else:
        configure(args.case, args.check)


if __name__ == "__main__":
    main()
