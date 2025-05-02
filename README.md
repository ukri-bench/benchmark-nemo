# NEMO Spack
This repository contains the spack package to build and install NEMO (Nucleus for European Modelling of the Ocean) model.

![GitHub CI](https://github.com/ukri-bench/nemo/actions/workflows/ci-nemo.yml/badge.svg)

## Recommended steps:
### Copy spack configuration files
Copy all files in spack-configs/yoursystem to .spack directory, check `environment.sh` for the location of `.spack`
### Install spack
Spack v1 (latest) has changed how it handles compilers, the changes have been reflected in `spack-configs/archer2/packages.yaml`. Please install the latest spack version to use them.
~~Install spack v0.23.1(recommended) or older. Spack v1 changed how it manages compilers inside `compilers.yaml` which breaks current config files.~~
### Modify the environment
Modify `environment.sh` to set paths for your spack and temp directories. It is recommended that the temporary directory must be something fast and accessible since it will be used for spack build caches. Load this file with `source environment.sh` before proceeding.
### Add the repo
 Spack can add external repos with `spack repo add "path"`.
### Install NEMO
`spack install nemo%cce +mpi config=ORCA2_ICE_PISCES` or with a compiler of your choice.
### Load NEMO and build your run directory
NEMO has complex requirements for running it. A number of modifications are needed in the namelist files to create a running config. This spack package aims to provide a simple script called `nemo-wrapper`, which can be used to set all these options. The wrapper script will modify itself depending on your enabled options. Here's an example of the wrapper script with ORCA2_ICE_PISCES and mpi enabled.
```
$ nemo-wrapper -h
  Usage: nemo-wrapper [OPTIONS]

  Options:
  -d, --dir path        Run directory path (default: CurrentDirectory/NEMO_RUNDIR)
  -i, --lon num         (required) No. of NEMO MPI processes in the i (longitudinal) direction
  -j, --lat num         (required) No. of NEMO MPI processes in the j (latitudinal) direction
  -t, --timesteps num   No. of timesteps (default: 24)
  -n, --namelist path   Namelist file path (default: nemo_path/EXP00/namelist_cfg)
  --extra-paths paths   Extra paths to link in the run directory (colon separated)
  +stats                Enable run.stat
  +timings              Enable NEMO timings in the timing.output file (requires: gnuplot)
  -h, --help            Show this help message and exit

```

To run `ORCA2_ICE_PISCES`, you will also need to add extra files. This can be done with:
```sh
wget -N https://gws-access.jasmin.ac.uk/public/nemo/sette_inputs/r4.2.0/ORCA2_ICE_v4.2.0.tar.gz && tar -xvzf ORCA2_ICE_v4.2.0.tar.gz
```
You can then run:
```sh
nemo-wrapper -i 4 -j 9 -t 6 +stats +timings --extra-paths "$PWD/ORCA2_ICE_v4.2.0"
```

The run directory will be created in either the current directory, or in directory provided by `-d`.

### Create SLURM script
The `run_nemo.sbatch` demonstrates how to run nemo. Modify this before running your config.

> This work was funded by the Engineering and Physical Sciences Research Council (EPSRC) as part of the Benchmarking for Exascale Computing project EP/Z53321X/1.
