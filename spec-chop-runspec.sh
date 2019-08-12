#!/usr/bin/env sh
#
# ----------------------------------------------------------------------------
#
# Copyright 2019 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ----------------------------------------------------------------------------
#
# SPEC-CHOP: ChopStiX support scripts to run SPEC benchmarks 
#
# Author: Ramon Bertran Monfort <rbertra@us.ibm.com>
#
# Copyright 2018 IBM Corporation
# IBM (c) 2018 All rights reserved
#

set -e # Finish right after a non-zero return command
set -u # Finish right after a undefined expression is used
set -a # All following variables are exported

SPEC_CHOP_PATH=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
. "$SPEC_CHOP_PATH/spec-chop.config"

scPrint "Sourcing SPEC environment ..."
cd "$SPEC_CHOP_SPEC_INSTALL_DIR"
. "$SPEC_CHOP_SPEC_INSTALL_DIR/shrc"
scPrint "SPEC environment sourced"

set -e # Finish right after a non-zero return command
set -u # Finish right after a undefined expression is used
set -a # All following variables are exported

if [ $# -ne 1 ]; then
    scError "Need one argument: benchmark to run"
fi
bench=$1

scPrint "SPEC-CHOP Environment:"
env | grep "^SPEC_CHOP" >&2 

scPrint "Creating temporary sandbox for the run ..."
temp=$(mktemp --suffix=.cfg)
tempdir=$(mktemp -d)
sed "s#@@SPEC_CHOP_TEMPROOT@@#$tempdir#g" < "$SPEC_CHOP_CONFIGURATION_FILE" > "$temp"

if [ ! -d "$SPEC_CHOP_SPEC_INSTALL_DIR/benchspec/CPU/$bench/build" ]; then
    scError "Need to compile benchmark $bench first"
fi

if [ ! -d "$SPEC_CHOP_SPEC_INSTALL_DIR/benchspec/CPU/$bench/exe" ]; then
    scError "Need to compile benchmark $bench first"
fi

mkdir -p "$tempdir/benchspec/CPU/$bench"
cp -fr "$SPEC_CHOP_SPEC_INSTALL_DIR/benchspec/CPU/$bench/build"  "$tempdir/benchspec/CPU/$bench"
cp -fr "$SPEC_CHOP_SPEC_INSTALL_DIR/benchspec/CPU/$bench/exe"  "$tempdir/benchspec/CPU/$bench"

scPrint "Launching run of $bench ..."
scPrint "Command: runcpu -n $SPEC_CHOP_BENCH_REPETITIONS --config ${SPEC_CHOP_CONFIGURATION_FILE} --action=run -i $SPEC_CHOP_BENCH_INPUT_SIZE $bench"
set +e
SPEC_CHOP_BENCH_NAME="$bench" runcpu -I -n "$SPEC_CHOP_BENCH_REPETITIONS" --config "${temp}" --action=run -i "$SPEC_CHOP_BENCH_INPUT_SIZE" "$bench" 
set -e

set +e
scPrint "Dump log:"
cat "$tempdir/result/CPU2017.001.log" >&2 
scPrint "Dump debug log:"
cat "$tempdir/result/CPU2017.001.log.debug" >&2 
set -e

scPrint "Cleaning up..."
rm -fr "$temp" "$tempdir"

exit 0
