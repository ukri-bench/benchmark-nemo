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
### Install additional utilities
The `f90nml` is a small utility to edit fortran namelist files. It makes the job of editing them much easier and is extensively used in `create_runscript.sh`. This can either be installed with `pip3` or as we do on archer2 with `spack install py-f90nml%gcc@11`. Remember to load it before running `create_runscript.sh` if installed via spack.
### Add the repo
 Spack can add external repos with `spack repo add "path"`.
### Install NEMO
`spack install nemo%cce +mpi config=ORCA2_ICE_PISCES` or with a compiler of your choice.
### Create SLURM script
Some additional files are required for NEMO to run. The `create_runscript.sh` links these files to the run directory and modifies namelists for various options. Options include:
* `IPROC` and `JPROC` to specify domain decomposition and MPI ranks.
* `RUNLEN` to set no. of timesteps.
* `RUN_NAME` to set the name of run directory. This will be created in your current folder.
* `TIMING` to enable default nemo performance timers in `timing.output` in run directory.
* `STATS` enables `run.stat` file, which can be used to verify output (correctness) for each timestep.
* `NML_REF` the namelist file used.

Running `create_runscript.sh` will create a `run_nemo.sbatch` inside the run directory. Modify this before running your config.

NOTE: I am looking into automating this step in the near future with reframe or other alternatives.

> This work was funded by the Engineering and Physical Sciences Research Council (EPSRC) as part of the Benchmarking for Exascale Computing project EP/Z53321X/1.
