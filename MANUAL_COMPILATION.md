# COMPILE NEMO MANUALLY

NEMO and its dependencies are built and installed using spack where possible.

The steps below are described in the order in which they need to be completed. Some need to be run once, and others will be used regularly, depending on your workflow.

## Step 1- Setting compiler, versions etc

The compiler to be used, and versions of the compiler and dependencies including PSyclone, HDF5, netCDF, BOOST are defined in `set_version.sh`. Directories to be used throughout the workflow are set in `set_directories.sh`. In general, all of steps 2 owards will need to repeated following a change to these files.

The number of cores, sockets and other resources associated with a node are returned by `platform_info.sh`. Values are presently hard-coded for the ISAMBARD-AI nodes.

## Step 2- Building and using the spack environment

### ENSURE THAT SPACK HAS GCC AVAILABLE TO COMPILE NVHPC

The script `build_spack.sh` installs the dependencies needed for building/running NEMO. In general this should only need to be run once per user for each compiler/version. This may take a long time to run if the compiler itself needs to be downloaded and installed.

Some spack external package configurations are available in the spack-configs (for archer2 on spack v0.23 and isambard-ai on spack v1.1.1 latest)

The script will ultimately create a spack environment named `nemo_$COMPILER_$VERSION`. This can be activated using `spack env activate nemo_$COMPILER_$VERSION`, noting this is done automatically by other scripts listed below.

This script does not take any arguments or have any user-editable parts.

## Step 3- Building XIOS

Building XIOS via spack doesn not work at the time of writing, so it is built from source using `build.xios.sh`. In general this should only need to be run once per user for each compiler/version.

NOTE- this script installs a specific revision of the XIOS trunk, defined in `set_version.sh` and `head` should be considered mutable.

This script does not take any arguments or have any user-editable parts.

## Step 4- Building PSyclone
`build_psyclone.sh` clones (June 26 2025 version for now) psyclone repository and installs psyclone.

## Step 5- Building NEMO

`build_nemo.sh` clones a hard-coded repository and builds nemo itself.

Use argument $1 as clean to create a fresh build instead. This script also contains tranformation and config selection option at the start

NOTE: It is also possible to replace the MPI compiler with `psyclonefc` wrapper. Instructions on how to do this are in the [PSyclone repository] (https://github.com/stfc/PSyclone/tree/single_nemo_script/examples/nemo/scripts#set-up-environment-variables)

## Step 6- Running NEMO

The supplied `prep_nemo_input_example.sh` does not actually run nemo but rather prepares the input for a specific hard-coded example and generates a `sbatch` script.

This script has number of MPI processes IPROC, JPROC.

## Scripts in etc

The `etc` directory contains scripts that users should not usually need to run directly. These set versions, directories, node resources etc, and apply various fixes as part of the build process.
