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

environ="$SPEC_CHOP_LSF_DEFAULT_ENVIRON" 
outputpath="$SPEC_CHOP_DB_BASEPATH/LSF_logs/"

while [ $# -gt 0 ]; do
    environ="${environ}SPEC_CHOP_$1"
    shift
    environ="$environ=$1,"
    shift
done;

scPrint "Setting output directory in $outputpath"
mkdir -p "$outputpath"
scPrint "LSF submission environment: $environ"

if [ "$(echo "$environ" | grep -c SPEC_CHOP_WRAPPER)" -eq 0 ]; then
    scPrint "WARNING: ---------------------------------------------------------"
    scPrint "WARNING: No SPEC_CHOP_WRAPPER defined. SPEC will run standalone   " 
    scPrint "WARNING: without any sampling/tracing mechanism                   "
    scPrint "WARNING: ---------------------------------------------------------"
    scPrint "Use Ctrl-C to cancel submission..."
    sleep 3
fi

for cspec in $SPEC_CHOP_BENCHMARKS; do

    while [ "$(bjobs | grep -c "$(whoami)")" -gt "$SPEC_CHOP_MAX_LSF_JOBS" ]; do
        scPrint "Wait jobs to finish ... (sleep a minute)"
        sleep 60
    done;

    scPrint "Submmiting SPEC $cspec for executing in LSF ..."
    scPrint "Cleaning previous logs ..."

    timestamp=$(date +%Y%m%d%H%M%S%N)
    rm -f "$outputpath/$timestamp.$cspec.output" "$outputpath/$timestamp.$cspec.error"

    bsub -W "$SPEC_CHOP_LSF_MAX_TIME" -J "$cspec" -env "${environ}SPEC_CHOP_BENCH_NAME=$cspec" -o "$outputpath/$timestamp.$cspec.output" -e "$outputpath/$timestamp.$cspec.error" "$SPEC_CHOP_PATH/spec-chop-runspec.sh" "$cspec"

    scPrint "$cspec submitted for execution"
    scPrint "Logs will be generated here: $outputpath/$timestamp.$cspec.output and $outputpath/$timestamp.$cspec.error"

done;

exit 0
