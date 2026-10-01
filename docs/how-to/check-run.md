# Check whether a run succeeded

Use three levels of checking: Slurm, WRF, and output files.

## 1. Did Slurm finish normally?

```bash
sacct -j YOUR_JOB_ID \
  --format=JobID,State,ExitCode,Elapsed,NodeList,AllocCPUS
```

For a normal batch job, look for:

```text
State:    COMPLETED
ExitCode: 0:0
```

## 2. Did WRF reach normal completion?

```bash
CASE=my-case

LOG=$(find ".wrfkit/logs/$CASE" \
  -maxdepth 1 -type d -name '*_wrf' | sort | tail -1)

tar -xOf "$LOG/native-logs.tar" rsl.out.0000 |
  grep "SUCCESS COMPLETE WRF"
```

If the line appears, rank 0 reported normal WRF completion.

## 3. Are the expected output files present?

```bash
ls ".wrfkit/work/$CASE"/wrfout_d01_*
```

Also check timestamps and file sizes match the experiment you intended.

## 4. If WRF did not finish

List the archived logs:

```bash
tar -tf "$LOG/native-logs.tar" | head
```

Read rank 0 error output:

```bash
tar -xOf "$LOG/native-logs.tar" rsl.error.0000 | tail -80
```

Then use [Troubleshooting](../troubleshooting.md).

!!! note "Program success is only the first check"
    A completed WRF run still needs scientific quality control before its output
    is used in research.
