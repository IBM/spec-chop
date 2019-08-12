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

scPrint "Seting up Microprobe environment ..."

set +u

cd "$SPEC_CHOP_MICROPROBE_PATH" 
# shellcheck disable=SC1091
. ./activate_microprobe
command -v mp_mpt2tst.py
# shellcheck disable=SC2103
cd - > /dev/null

set -e # Finish right after a non-zero return command
set -u # Finish right after a undefined expression is used
set -a # All following variables are exported

outputpath="$SPEC_CHOP_DB_BASEPATH/LSF_logs/"
scPrint "Setting output directory in $outputpath"
mkdir -p "$outputpath"

for cspec in $SPEC_CHOP_BENCHMARKS; do

    while [ "$(bjobs | grep -c "$(whoami)")" -gt "$SPEC_CHOP_MAX_LSF_JOBS" ]; do
        scPrint "Wait jobs to finish ... (sleep a minute)"
        sleep 60
    done;

    timestamp=$(date +%Y%m%d%H%M%S%N)
    rm -f "$outputpath/$timestamp.$cspec.output" "$outputpath/$timestamp.$cspec.error"
    
    scPrint "Submitting MPT2TST generation job for $cspec ..."
    bsub -W "$SPEC_CHOP_LSF_MAX_TIME" -J "mpt2tst-$cspec" -env "SPEC_CHOP_MPT2TST_BENCH=$cspec" -o "$outputpath/$timestamp.$cspec.output" -e "$outputpath/$timestamp.$cspec.error" "$SPEC_CHOP_PATH/spec-chop-mpt2tst.sh"

done;

exit 0
