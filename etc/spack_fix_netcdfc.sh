#!/usr/bin/env bash

# Copyright 2026 Kaan Olgu
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

#####################################################
# Fix netcdf-c spack package
#####################################################
# This file is sourced, so it uses 'return' rather than 'exit'.
#
# Find the package file from Spack, rather than from a fixed path: Spack v1
# keeps the builtin packages in a separate repository
FILE="$(spack location --package-dir netcdf-c)/package.py"

# Check if the file exists
if [[ ! -f "$FILE" ]]; then
    echo "File not found: $FILE"
    return 1
fi

# Define the line to be added with two tabs of indentation
LINE_TO_ADD=$'        # FIX: configure: error: Compiling a test with HDF5 failed.  Either hdf5.h cannot be found\n        config_args.append("CPPFLAGS=-I{0}/include".format(self.spec["hdf5"].prefix))'

# Check if the line is already present in the file
if grep -q 'CPPFLAGS=-I{0}/include' "$FILE"; then
    echo "The fix has already been applied. No changes made."
else
    # Use awk to insert the new line before the line containing "return config_args"
    # (passed through the environment: some awks reject newlines in -v values)
    NEWLINE="$LINE_TO_ADD" awk '/        return config_args/ {print ENVIRON["NEWLINE"]} {print}' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE" || return 1
    echo "Line added successfully."
fi