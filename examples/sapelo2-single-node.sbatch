#!/usr/bin/env bash
#SBATCH --job-name=wrfkit-wrf
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=16
#SBATCH --time=02:00:00
#SBATCH --mem=64G
#SBATCH --output=wrfkit-%j.out
#SBATCH --error=wrfkit-%j.err

set -Eeuo pipefail

# Override at submission time if needed:
#   WRFKIT_CASE=my-case sbatch examples/sapelo2-single-node.sbatch
CASE=${WRFKIT_CASE:-athens-smoke}
REPO=${WRFKIT_REPO:-$HOME/work/project/wrfkit}

cd "$REPO"

# Safe to call on each allocated node. If managed Nix is already working,
# bootstrap exits successfully without reinstalling it.
./bootstrap --profile sapelo2

# wrfkit owns the single-node Slurm -> Nix -> OpenMPI launch topology.
export OMP_NUM_THREADS=1

# This example assumes WPS has already produced met_em.* for the selected case.
./wrfctl prepare wrf --case "$CASE"
./wrfctl exec real --case "$CASE"
./wrfctl exec wrf --case "$CASE"
