#!/usr/bin/env python
import argparse
from pathlib import Path

import xarray as xr
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def plot_t2(ds, outpath: Path):
    t2 = ds["T2"].isel(Time=0) - 273.15
    lat = ds["XLAT"].isel(Time=0)
    lon = ds["XLONG"].isel(Time=0)

    fig, ax = plt.subplots(figsize=(8, 6))
    m = ax.pcolormesh(lon, lat, t2, shading="auto")
    fig.colorbar(m, ax=ax, label="T2 (°C)")
    ax.set_xlabel("Longitude")
    ax.set_ylabel("Latitude")
    ax.set_title("2-m Temperature")
    fig.tight_layout()
    fig.savefig(outpath, dpi=150)
    plt.close(fig)


def plot_hgt(ds, outpath: Path):
    hgt = ds["HGT"].isel(Time=0)
    lat = ds["XLAT"].isel(Time=0)
    lon = ds["XLONG"].isel(Time=0)

    fig, ax = plt.subplots(figsize=(8, 6))
    m = ax.pcolormesh(lon, lat, hgt, shading="auto")
    fig.colorbar(m, ax=ax, label="Terrain height (m)")
    ax.set_xlabel("Longitude")
    ax.set_ylabel("Latitude")
    ax.set_title("Terrain Height")
    fig.tight_layout()
    fig.savefig(outpath, dpi=150)
    plt.close(fig)


def plot_wind10(ds, outpath: Path):
    u10 = ds["U10"].isel(Time=0)
    v10 = ds["V10"].isel(Time=0)
    wspd = np.sqrt(u10**2 + v10**2)
    lat = ds["XLAT"].isel(Time=0)
    lon = ds["XLONG"].isel(Time=0)

    # quiver 간격 줄이기
    step = 10

    fig, ax = plt.subplots(figsize=(8, 6))
    m = ax.pcolormesh(lon, lat, wspd, shading="auto")
    fig.colorbar(m, ax=ax, label="10-m wind speed (m s$^{-1}$)")
    ax.quiver(
        lon.values[::step, ::step],
        lat.values[::step, ::step],
        u10.values[::step, ::step],
        v10.values[::step, ::step],
        scale=80,
    )
    ax.set_xlabel("Longitude")
    ax.set_ylabel("Latitude")
    ax.set_title("10-m Wind")
    fig.tight_layout()
    fig.savefig(outpath, dpi=150)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("wrfout", help="Path to wrfout_d01_* file")
    parser.add_argument(
        "--outdir",
        default="figures",
        help="Directory where PNG files will be saved",
    )
    args = parser.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    ds = xr.open_dataset(args.wrfout)

    stem = Path(args.wrfout).name
    plot_t2(ds, outdir / f"{stem}_t2.png")
    plot_hgt(ds, outdir / f"{stem}_hgt.png")
    plot_wind10(ds, outdir / f"{stem}_wind10.png")

    print(f"Saved plots to: {outdir}")


if __name__ == "__main__":
    main()
