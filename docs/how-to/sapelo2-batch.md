# Run WRF with sbatch on Sapelo2

Use this guide after WPS has already created `met_em.*` files for your case.

The repository includes:

```text
examples/sapelo2-single-node.sbatch
```

It requests **one node** and **16 MPI tasks**.

## 1. Submit from the login node

You do not need an interactive shell to submit an `sbatch` job.

```bash
cd ~/work/project/wrfkit

WRFKIT_CASE=athens-smoke \
  sbatch examples/sapelo2-single-node.sbatch
```

Slurm prints a job number:

```text
Submitted batch job 48718022
```

Your number will be different.

## 2. Check the queue

```bash
squeue -j YOUR_JOB_ID
```

Typical states:

| State | Meaning |
| --- | --- |
| `PD` | Waiting in the queue |
| `R` | Running |
| gone from `squeue` | Finished or stopped; check `sacct` |

## 3. Check the final Slurm result

```bash
sacct -j YOUR_JOB_ID \
  --format=JobID,State,ExitCode,Elapsed,NodeList,AllocCPUS
```

A normal run should show the main job as:

```text
COMPLETED   0:0
```

## 4. Check WRF itself

```bash
CASE=athens-smoke

LOG=$(find ".wrfkit/logs/$CASE" \
  -maxdepth 1 -type d -name '*_wrf' | sort | tail -1)

tar -xOf "$LOG/native-logs.tar" rsl.out.0000 |
  grep "SUCCESS COMPLETE WRF"
```

## What wrfkit does with your 16 tasks

You request resources from Slurm:

```text
1 node
16 tasks / CPUs for WRF
```

wrfkit then uses the validated single-node bridge:

```text
Slurm allocation
      |
      v
one child srun task holding 16 CPUs
      |
      v
enter Nix once
      |
      v
mpirun -np 16
      |
      v
16 WRF MPI ranks
```

This avoids entering the rootless-Nix environment once per MPI rank.

!!! warning "Do not wrap wrfctl in another 16-rank srun"
    Avoid:

    ```bash
    srun -n 16 ./wrfctl exec wrf --case my-case
    ```

    Use the command already inside the example script:

    ```bash
    ./wrfctl exec wrf --case my-case
    ```

## Use another case

```bash
WRFKIT_CASE=my-case \
  sbatch examples/sapelo2-single-node.sbatch
```

The example assumes `met_em.*` already exists for that case. It runs
`prepare wrf`, `real`, and `wrf`.

Multi-node execution is not yet claimed as validated.
