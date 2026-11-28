# NEMO benchmark

Scripts, configurations and results for benchmarking NEMO (Nucleus for European Modelling of the Ocean) on UK HPC systems.

![GitHub CI](https://github.com/ukri-bench/benchmark-nemo/actions/workflows/ci-nemo.yml/badge.svg)

The NEMO Spack package (with the `nemo-wrapper` run-directory script) lives in [ukri-bench/spack-packages](https://github.com/ukri-bench/spack-packages).

## Contents

- `NEMO_Benchmarking_Report.pdf`: final benchmarking report.
- `benchmark-results/`: `run.stat` outputs for ARCHER2, Isambard-3 and Isambard-AI (ORCA1, ORCA025, ORCA12 and ORCA36-like configurations), the namelists used, scaling plots and the scripts that generate them.
- `spack-configs/`: Spack `packages.yaml` for ARCHER2, Isambard-3 and Isambard-AI.
- `build_*.sh`, `etc/`: scripts for building NEMO and its dependencies manually. See [MANUAL_COMPILATION.md](MANUAL_COMPILATION.md).
- `run_nemo.sbatch`: example Slurm job script.

## Building with Spack

### Install Spack

Spack v1.x is required. CI uses Spack v1.2.2.

### Add the system configuration

Copy `spack-configs/<system>/packages.yaml` into your Spack user configuration directory: `$SPACK_USER_CONFIG_PATH`, or `~/.spack` by default.

### Add the package repository

```sh
spack repo add https://github.com/ukri-bench/spack-packages
```

### Install NEMO

```sh
spack install nemo +mpi +ice +pisces config=ORCA2_ICE_PISCES %cce
```

Replace `%cce` with your compiler (`gcc`, `nvhpc`, `oneapi` or `cce`). The `ice` and `pisces` variants are off by default. Without them, the SI3 sea-ice and PISCES/TOP components are removed from the build, even for `config=ORCA2_ICE_PISCES`.

## Running NEMO

### Create a run directory

NEMO needs a number of namelist changes to produce a runnable configuration. The `nemo-wrapper` script installed with the package makes these and creates a run directory. Run `nemo-wrapper -h` to see the options for your build.

`ORCA2_ICE_PISCES` also needs extra input files:

```sh
wget -N https://gws-access.jasmin.ac.uk/public/nemo-vol1/sette_inputs/r4.2.0/ORCA2_ICE_v4.2.0.tar.gz
tar -xzf ORCA2_ICE_v4.2.0.tar.gz
```

Then create the run directory, here for a 4 × 9 MPI decomposition (36 processes) and 6 time steps:

```sh
nemo-wrapper -i 4 -j 9 -t 6 +stats +timings --extra-paths "$PWD/ORCA2_ICE_v4.2.0"
```

The run directory is created at `./NEMO_RUNDIR`, or at the path given with `-d`.

### Run

From the run directory, launch `nemo` with the number of processes from `-i` × `-j`:

```sh
cd NEMO_RUNDIR
mpirun -np 36 ./nemo
```

On a Slurm system, `run_nemo.sbatch` is an example job script for one 36-process node, set up for ARCHER2. Change the account, partition and QoS for your system.

> This work was funded by the Engineering and Physical Sciences Research Council (EPSRC) as part of the Benchmarking for Exascale Computing project EP/Z53321X/1.
