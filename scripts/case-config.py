#!/usr/bin/env python3
"""TOML case configuration loader and native namelist overlay renderer."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import shlex
import sys
import tomllib

ROOT = pathlib.Path(__file__).resolve().parents[1]

GEOGRAPHY_PROFILES = {
    "wps-lowres-mandatory": {
        "management": "managed",
        "storage_dir": "low-res-mandatory",
        "required_resolution": "lowres",
        "auto_acquire": True,
    },
    "wps-highres-mandatory": {
        "management": "managed",
        "storage_dir": "high-res-mandatory",
        "required_resolution": None,
        "auto_acquire": True,
    },
    "external": {
        "management": "external",
        "storage_dir": None,
        "required_resolution": None,
        "auto_acquire": False,
    },
}



def color_enabled(stream=sys.stdout) -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    mode = os.environ.get("WRFKIT_COLOR", "auto")
    if mode == "always":
        return True
    if mode == "never":
        return False
    return mode == "auto" and stream.isatty() and os.environ.get("TERM", "dumb") != "dumb"


def styled(text: str, code: str, stream=sys.stdout) -> str:
    return f"\033[{code}m{text}\033[0m" if color_enabled(stream) else text


def print_heading(text: str) -> None:
    print(styled(text, "1;36"))


def print_kv(label: str, value) -> None:
    if color_enabled(sys.stdout):
        label_text = styled(f"{label}:".ljust(13), "36")
        value_text = styled(str(value), "1")
        print(f"  {label_text} {value_text}")
    else:
        print(f"  {label + ':':13} {value}")


def die(message: str, code: int = 2) -> None:
    prefix = styled("[ERROR]", "1;31", sys.stderr)
    print(f"{prefix} wrfkit config: {message}", file=sys.stderr)
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


def geography_settings(data):
    geography = data.get("geography")
    if not isinstance(geography, dict):
        die("missing [geography] table")

    dataset = geography.get("dataset")
    if not isinstance(dataset, str) or not dataset.strip():
        die("geography.dataset must be a non-empty string")
    dataset = dataset.strip()

    profile = GEOGRAPHY_PROFILES.get(dataset)
    if profile is None:
        supported = ", ".join(sorted(GEOGRAPHY_PROFILES))
        die(
            f"unsupported geography.dataset: {dataset!r}; "
            f"recognized profiles: {supported}"
        )

    resolution = geography.get("resolution")
    if isinstance(resolution, str) and resolution.strip():
        selectors = [resolution.strip()]
    elif isinstance(resolution, list) and resolution and all(
        isinstance(value, str) and value.strip() for value in resolution
    ):
        selectors = [value.strip() for value in resolution]
        max_dom = int(data.get("domain", {}).get("max_dom", 1))
        if len(selectors) != max_dom:
            die(
                "geography.resolution array must contain exactly "
                "domain.max_dom values"
            )
    else:
        die("geography.resolution must be a non-empty string or array of strings")

    required = profile["required_resolution"]
    if required is not None and any(value != required for value in selectors):
        rendered = ", ".join(repr(value) for value in selectors)
        die(
            f"geography profile {dataset!r} requires geography.resolution="
            f"{required!r}; got {rendered}"
        )

    path = geography.get("path")
    if profile["management"] == "external":
        if not isinstance(path, str) or not path.strip():
            die('geography.path is required when geography.dataset="external"')
        path = path.strip()
        expanded = os.path.expandvars(os.path.expanduser(path))
        if not pathlib.Path(expanded).is_absolute() and ".." in pathlib.PurePath(expanded).parts:
            die(
                "relative geography.path must stay under data_root/geog; "
                "use an absolute path to reference another filesystem"
            )
    elif path is not None:
        die('geography.path is only valid when geography.dataset="external"')
    else:
        path = ""

    return {
        "GEOG_DATASET": dataset,
        "GEOG_RESOLUTION": ", ".join(selectors),
        "GEOG_MANAGEMENT": profile["management"],
        "GEOG_AUTO_ACQUIRE": "1" if profile["auto_acquire"] else "0",
        "GEOG_STORAGE_DIR": profile["storage_dir"] or "",
        "GEOG_PATH_SPEC": path,
    }


def resolve_geography_path(name: str, data_root: str) -> str:
    _, data = load_case(name)
    settings = geography_settings(data)

    root_text = os.path.expandvars(os.path.expanduser(data_root))
    geog_root = pathlib.Path(root_text) / "geog"

    if settings["GEOG_MANAGEMENT"] == "external":
        path_text = os.path.expandvars(os.path.expanduser(settings["GEOG_PATH_SPEC"]))
        path = pathlib.Path(path_text)
        if not path.is_absolute():
            path = geog_root / path
    else:
        path = geog_root / settings["GEOG_STORAGE_DIR"]

    return os.path.normpath(str(path))


def shell_env(name: str) -> None:
    _, data = load_case(name)
    validate_time_forcing(data)
    env = forcing_settings(data)
    env.update(geography_settings(data))
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
    geography_settings(data)
    managed, wps, wrf = build_patches(data)

    for filename in ("namelist.wps", "namelist.input"):
        if not (case_dir / filename).is_file():
            die(f"{filename} not found: {case_dir / filename}")

    print_heading("Case configuration")
    print_kv("case", name)
    print_kv("TOML", case_dir / "case.toml")
    print_kv("namelist managed", "true" if managed else "false")

    if not managed:
        print_kv("native namelists", "read-only (wrfkit will not modify them)")
        return

    print_kv("WPS overrides", sum(map(len, wps.values())))
    print_kv("WRF overrides", sum(map(len, wrf.values())))

    if check_only:
        print(styled("[OK]", "1;32") + " Check only; no files changed.")
        return

    wps_changed = patch_namelist(case_dir / "namelist.wps", wps)
    wrf_changed = patch_namelist(case_dir / "namelist.input", wrf)
    for filename, changed in (("namelist.wps", wps_changed), ("namelist.input", wrf_changed)):
        state = "updated" if changed else "unchanged"
        color = "1;33" if changed else "1;32"
        print(f"  {filename + ':':19} {styled(state, color)}")


def display_value(value) -> str:
    if isinstance(value, list):
        return "[" + ", ".join(str(item) for item in value) + "]"
    return str(value)


def display_datetime(value, field: str) -> str:
    return utc_datetime(value, field).strftime("%Y-%m-%d %H:%M:%SZ")


def summarize_case(name: str) -> None:
    _, data = load_case(name)
    validate_time_forcing(data)
    geography_settings(data)
    managed, wps, wrf = build_patches(data)

    print_heading("Scientific configuration")
    print_kv("case", name)

    time = data.get("time", {})
    if "start" in time and "end" in time:
        print_kv(
            "period",
            f"{display_datetime(time['start'], 'time.start')} -> "
            f"{display_datetime(time['end'], 'time.end')}",
        )
    if "forcing_interval_seconds" in time:
        print_kv("input step", f"{time['forcing_interval_seconds']} s")

    forcing = data.get("forcing", {})
    print_kv("forcing", f"{forcing.get('provider', '<unset>')} {forcing.get('product', '<unset>')}")
    if "cycle" in forcing:
        print_kv("cycle", display_datetime(forcing["cycle"], "forcing.cycle"))
    if "forecast_hours" in forcing:
        print_kv("fcst hours", display_value(forcing["forecast_hours"]))
    subset = forcing.get("subset", {})
    if isinstance(subset, dict) and all(k in subset for k in ("west", "east", "south", "north")):
        print_kv(
            "subset",
            f"W={subset['west']} E={subset['east']} "
            f"S={subset['south']} N={subset['north']}",
        )

    geography = data.get("geography", {})
    print_kv(
        "geography",
        f"{geography.get('dataset', '<unset>')} "
        f"({geography.get('resolution', '<unset>')})",
    )

    domain = data.get("domain", {})
    print_kv("domains", domain.get("max_dom", 1))
    for key, label, suffix in (
        ("dx", "dx", " m"),
        ("dy", "dy", " m"),
        ("e_we", "e_we", ""),
        ("e_sn", "e_sn", ""),
        ("e_vert", "e_vert", ""),
    ):
        if key in domain:
            print_kv(label, f"{display_value(domain[key])}{suffix}")

    model = data.get("model", {})
    if "time_step" in model:
        print_kv("time step", f"{model['time_step']} s")

    physics = data.get("physics", {})
    if "suite" in physics:
        print_kv("physics", physics["suite"])

    output = data.get("output", {})
    if "history_interval_minutes" in output:
        print_kv("history", f"{output['history_interval_minutes']} min")

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
        print_kv(
            "namelists",
            "managed "
            f"({sum(map(len, wps.values()))} WPS / "
            f"{sum(map(len, wrf.values()))} WRF overrides)",
        )
    else:
        print_kv("namelists", "manual/read-only")
    if advanced_wps or advanced_wrf:
        print_kv("advanced", f"{advanced_wps} WPS / {advanced_wrf} WRF native overrides")


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
    geography_settings(data)

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


def _as_domain_ints(data, key: str, max_dom: int):
    value = data.get("domain", {}).get(key)
    if value is None:
        die(f"domain.{key} is required for WRF decomposition planning")
    values = value if isinstance(value, list) else [value] * max_dom
    if len(values) != max_dom or any(
        not isinstance(item, int) or isinstance(item, bool) or item < 1
        for item in values
    ):
        die(f"domain.{key} must contain positive integers for every domain")
    return values


def _native_namelist_int(path: pathlib.Path, section: str, key: str, default: int):
    if not path.is_file():
        return default
    lines = path.read_text().splitlines()
    inside = False
    section_re = re.compile(rf"^\s*&{re.escape(section)}\b", re.IGNORECASE)
    key_re = re.compile(rf"^\s*{re.escape(key)}\s*=\s*(-?\d+)", re.IGNORECASE)
    for line in lines:
        if not inside:
            if section_re.search(line):
                inside = True
            continue
        if re.match(r"^\s*/", line):
            break
        match = key_re.search(line)
        if match:
            return int(match.group(1))
    return default


def _formatted_first_int(value, default: int):
    if value is None:
        return default
    match = re.search(r"-?\d+", str(value))
    return int(match.group(0)) if match else default


def _effective_nproc(case_dir: pathlib.Path, data):
    nproc_x = _native_namelist_int(case_dir / "namelist.input", "domains", "nproc_x", -1)
    nproc_y = _native_namelist_int(case_dir / "namelist.input", "domains", "nproc_y", -1)

    managed, _, wrf = build_patches(data)
    if managed:
        domains = wrf.get("domains", {})
        nproc_x = _formatted_first_int(domains.get("nproc_x"), nproc_x)
        nproc_y = _formatted_first_int(domains.get("nproc_y"), nproc_y)
    return nproc_x, nproc_y


def _mpaspect(tasks: int):
    best_diff = 2 * tasks
    best_x, best_y = 1, tasks
    for x in range(1, tasks + 1):
        if tasks % x:
            continue
        y = tasks // x
        difference = abs(x - y)
        if difference < best_diff:
            best_diff = difference
            best_x, best_y = x, y
    return best_x, best_y


def _decomposition_for(tasks: int, fixed_x: int, fixed_y: int):
    if fixed_x > 0 and fixed_y > 0:
        return (fixed_x, fixed_y) if fixed_x * fixed_y == tasks else None
    if fixed_x > 0:
        return (fixed_x, tasks // fixed_x) if tasks % fixed_x == 0 else None
    if fixed_y > 0:
        return (tasks // fixed_y, fixed_y) if tasks % fixed_y == 0 else None
    return _mpaspect(tasks)


def _patches_safe(e_we, e_sn, nproc_x: int, nproc_y: int):
    return all(
        (we // nproc_x) >= 10 and (sn // nproc_y) >= 10
        for we, sn in zip(e_we, e_sn)
    )


def mpi_plan(name: str, requested: int, shell: bool) -> None:
    if requested < 1:
        die("requested MPI tasks must be >= 1")

    case_dir, data = load_case(name)
    max_dom = int(data.get("domain", {}).get("max_dom", 1))
    e_we = _as_domain_ints(data, "e_we", max_dom)
    e_sn = _as_domain_ints(data, "e_sn", max_dom)
    fixed_x, fixed_y = _effective_nproc(case_dir, data)

    requested_mesh = _decomposition_for(requested, fixed_x, fixed_y)
    requested_safe = bool(
        requested_mesh
        and _patches_safe(e_we, e_sn, requested_mesh[0], requested_mesh[1])
    )

    selected = None
    selected_mesh = None
    for tasks in range(requested, 0, -1):
        mesh = _decomposition_for(tasks, fixed_x, fixed_y)
        if mesh and _patches_safe(e_we, e_sn, mesh[0], mesh[1]):
            selected = tasks
            selected_mesh = mesh
            break

    if selected is None or selected_mesh is None:
        die("no safe WRF MPI decomposition exists for this domain")

    req_x, req_y = requested_mesh if requested_mesh else (0, 0)
    sel_x, sel_y = selected_mesh
    source = "namelist" if fixed_x > 0 or fixed_y > 0 else "wrf-auto"

    values = {
        "WRFKIT_REQUESTED_TASKS": requested,
        "WRFKIT_REQUESTED_NPROC_X": req_x,
        "WRFKIT_REQUESTED_NPROC_Y": req_y,
        "WRFKIT_REQUESTED_SAFE": 1 if requested_safe else 0,
        "WRFKIT_WRF_TASKS": selected,
        "WRFKIT_NPROC_X": sel_x,
        "WRFKIT_NPROC_Y": sel_y,
        "WRFKIT_TASKS_ADJUSTED": 1 if selected != requested else 0,
        "WRFKIT_DECOMP_SOURCE": source,
    }

    if shell:
        for key, value in values.items():
            print(f"{key}={shlex.quote(str(value))}")
        return

    print_heading("WRF MPI decomposition")
    print(f"  requested:      {requested} tasks")
    if requested_mesh:
        print(
            f"  requested mesh: {req_x} x {req_y} "
            f"({'safe' if requested_safe else 'unsafe'})"
        )
    else:
        print("  requested mesh: incompatible with explicit nproc_x/nproc_y")
    print(f"  selected:       {selected} tasks ({sel_x} x {sel_y})")
    if selected != requested:
        print("  reason:         keep every decomposed WRF patch >= 10 grid cells")
    print(f"  source:         {source}")


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

    geog_path_parser = commands.add_parser(
        "geography-path", help="resolve the case geography directory for a data root"
    )
    geog_path_parser.add_argument("--case", required=True)
    geog_path_parser.add_argument("--data-root", required=True)

    mpi_parser = commands.add_parser(
        "mpi-plan", help="resolve a WRF-safe MPI task count and decomposition"
    )
    mpi_parser.add_argument("--case", required=True)
    mpi_parser.add_argument("--requested", required=True, type=int)
    mpi_parser.add_argument(
        "--shell", action="store_true", help="emit shell-safe key=value output"
    )

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
    elif args.command == "geography-path":
        print(resolve_geography_path(args.case, args.data_root))
    elif args.command == "mpi-plan":
        mpi_plan(args.case, args.requested, args.shell)
    else:
        configure(args.case, args.check)


if __name__ == "__main__":
    main()
