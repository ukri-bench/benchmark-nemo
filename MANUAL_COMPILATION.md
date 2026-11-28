# Compiling NEMO manually

These scripts build NEMO, XIOS and PSyclone by hand, with Spack providing the compiler, MPI and libraries. This is an alternative to the Spack package described in the [README](README.md).

Run the steps in order, from the repository root. Steps 2–4 normally need to be run once per compiler and version. Re-run them after changing the settings in step 1.

## Step 1: Choose the system, compiler and versions

`etc/set_versions.sh` sets:

- `SYSTEM_NAME`, which selects the platform file `etc/<SYSTEM_NAME>.sh`. Platform files exist for `archer2` and `isambard-ai`.
- The compiler (`COMPILER`, `COMPVER`, and `COMPVERP`, the version without dots, used in environment names).
- The MPI implementation (`MPIIMPL`) and the versions of HDF5, netCDF, Boost, XIOS and NEMO.

The platform file `etc/<SYSTEM_NAME>.sh` sets:

- `MAIN_DIR`, the top-level working directory. Change this to your own directory.
- Node resources (`CORES_PER_SOCKET`, `SOCKETS_PER_NODE`, `CORES_PER_NODE`), the CPU (and GPU) architecture, and MPI build options.

`etc/set_directories.sh` derives the other directories from `MAIN_DIR`. These include the Spack installation (`$MAIN_DIR/spack`), the scratch directory and the NEMO, XIOS and PSyclone source directories. It also sets `NEMO_EXTRA_INPUTS`, which is hard-coded and may need changing.

## Step 2: Build the Spack environment

Before running this step on a system where Spack will build `nvhpc`, make sure Spack has a GCC compiler available.

`build_spack.sh` installs the compiler (unless `INSTALL_COMP=0`), MPI, HDF5, netCDF, Boost and the other tools needed to build and run NEMO. This can take a long time if the compiler has to be built.

It creates a Spack environment in the directory `$ENVDIR/nemo_${COMPILER}_${COMPVERP}`. The other scripts activate it automatically. To use it yourself, run:

```sh
spack env activate $ENVDIR/nemo_${COMPILER}_${COMPVERP}
```

`spack-configs/<system>/packages.yaml` contains Spack external package settings for ARCHER2, Isambard-3 and Isambard-AI.

The script takes no arguments.

## Step 3: Build XIOS

XIOS can't currently be built with Spack, so `build_xios.sh` builds it from source. The XIOS major version and revision are set by `XIOSVER` and `XIOSREV` in `etc/set_versions.sh`. The default revision, `head`, changes over time; set a revision number for a reproducible build.

The script takes no arguments.

## Step 4: Install PSyclone

`build_psyclone.sh` clones PSyclone into `$PSYDIR`, checks out the `nemo_v5` branch and installs it with `pip` into the Spack environment's Python.

> **Note:** the `nemo_v5` branch no longer exists in the PSyclone repository. The checkout fails and the script then installs PSyclone's default branch instead.

## Step 5: Build NEMO

`build_nemo.sh` clones NEMO into `$NEMO_ROOT` (version `NMVER` from `etc/set_versions.sh`) if it isn't already there, and builds it.

The settings at the top of the script select the source configuration (`CONFIG_SRC`, default `ORCA2_ICE_PISCES`), the PSyclone transformation (`TRANS`), and whether to use MPI, XIOS and sea ice.

Pass `clean` as the first argument for a fresh build:

```sh
./build_nemo.sh clean
```

You can also use PSyclone's `psyclonefc` compiler wrapper in place of the MPI compiler. See the [PSyclone NEMO scripts README](https://github.com/stfc/PSyclone/blob/master/examples/nemo/scripts/README.md#set-up-environment-variables).

## Step 6: Prepare a run

`prep_nemo_input_example.sh` prepares, but doesn't run, an example. It creates a run directory under the NEMO configuration (`cfgs/BLDCFG/TESTRG`) and downloads the ORCA2 input files if needed. It also writes a Slurm script, `run_nemo.sbatch`, into the run directory and prints the command to submit it.

Edit the settings at the top of the script first. These include the MPI decomposition (`IPROC` × `JPROC`), the number of XIOS servers (`XPROC`), the run length (`RUNLEN`), OpenMP threads, and whether timing and `run.stat` output are enabled.

## Scripts in `etc`

The `etc` directory contains scripts that the build scripts call:

- the version, directory and platform settings described in step 1;
- `makenemo` and `sct_psyclone.sh`, which are copied into the NEMO source tree by `build_nemo.sh`;
- `spack_fix_netcdfc.sh`, which patches the Spack `netcdf-c` package.

You shouldn't normally need to run them directly.
