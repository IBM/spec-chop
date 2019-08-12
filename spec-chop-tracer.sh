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

for cspec in $SPEC_CHOP_BENCHMARKS; do

    # Look for sample DB for benchmark
    DB_NAME="$cspec.$SPEC_CHOP_SAMPLE_EVENT.$SPEC_CHOP_SAMPLE_PERIOD.db"
    DB_PATH="$(find "$SPEC_CHOP_DB_BASEPATH/sample/$SPEC_CHOP_SAMPLE_EVENT/$SPEC_CHOP_SAMPLE_PERIOD/" -name "$DB_NAME")"

    if [ -z "$DB_PATH" ]; then
        scPrint "No database found for $cspec using SAMPLE_EVENT=$SPEC_CHOP_SAMPLE_EVENT and SAMPLE_PERIOD=$SPEC_CHOP_SAMPLE_PERIOD" 
        continue
    fi

    scPrint "Database found: $DB_PATH"
    export CHOPSTIX_OPT_DATA="$DB_PATH"

    scPrint "Executing chop-score-table to find the right set of settings for the given constraints ..."
    temp=$(mktemp)
    cache_file="${DB_PATH}.chop-score-table"

    update_score=1
    error=0
    if [ -f "$cache_file" ]; then
        scPrint "Cache file found $cache_file"
        md5sum=$(echo "$(ls -ltha "$DB_PATH")" 0 "$SPEC_CHOP_MAX_FUNCTIONS" "$SPEC_CHOP_MIN_FUNCTION_SIZE" | md5sum)
        if [ "$(head -n 1 < "$cache_file")" = "$md5sum" ]; then
            scPrint "Cache contents up to date!"
            update_score=0
            cp -f "$cache_file" "$temp"
        fi
    fi

    if [ "$update_score" -eq 1 ]; then
        scPrint "No cache file found or requires update. Executing chop-score-table command ... "
        echo "$(ls -ltha "$DB_PATH") 0 $SPEC_CHOP_MAX_FUNCTIONS $SPEC_CHOP_MIN_FUNCTION_SIZE" | md5sum > "$temp"
        set +e
        chop-score-table "$DB_PATH" 0 "$SPEC_CHOP_MAX_FUNCTIONS" "$SPEC_CHOP_MIN_FUNCTION_SIZE" >> "$temp"
        set -e
        cp -f "$temp" "$cache_file" 
    fi

    set +e
    grep "chop list functions" < "$temp" > /dev/null 2>&1
    error=$?
    set -e

    if [ "$error" -ne 0 ]; then
        scPrint "WARNING --------------------------------------------------------------------------------"
        scPrint "WARNING Unable to find optimal settings for $cspec. Relax constraints of check input db "
        scPrint "WARNING --------------------------------------------------------------------------------"
        continue
    fi

    scPrint "Gathering information"
    listcmd=$(grep "chop list functions" < "$temp")
    coverage=$(grep "Best score" < "$temp" | cut -d " " -f 3 | cut -d "." -f 1)
    scPrint "Best coverage: $coverage%"

    if [ "$coverage" -lt "$SPEC_CHOP_MIN_COVERAGE" ]; then
        scPrint "WARNING --------------------------------------------------------------------------------"
        scPrint "WARNING Low coverage detected for $cspec. Use other tracing methods to increase coverage"
        scPrint "WARNING --------------------------------------------------------------------------------"
    fi

    scPrint "Processing selected functions"
    eval "$listcmd" | grep -v ^ID > "$temp" 
    while read -r line; do

        funcname=$(echo "$line" | cut -f 2);
        scPrint "Processing selected function: $funcname"

        size=$(printf "%06d" "$(echo "$line" | cut -f 3)");

        module=$(echo "$line" | cut -f 4);
        coverage=$(echo "$line" | cut -f 5);
        coverage=$(printf "%04d" "$(echo "$(echo "$coverage" | sed -e "s/%//") * 10" | bc | cut -d "." -f 1)")

        scPrint "Searching for module $module ..."
        module_file=$(find "$SPEC_CHOP_SPEC_INSTALL_DIR/benchspec/CPU/$cspec/exe/" -name "$module")

        if [ -z "$module_file" ]; then
            scPrint "WARNING --------------------------------------------------------------------------------"
            scPrint "WARNING Unable to find module $module for $cspec" 
            scPrint "WARNING --------------------------------------------------------------------------------"
            continue
        fi
        
        scPrint "Searching for addresses of $funcname in $module ..."
        addrs_begin=$(chop-marks-ppc64 "$module_file" "$funcname" -cache | grep begin | cut -d ' ' -f 2 | paste -sd ",")
        addrs_end=$(chop-marks-ppc64 "$module_file" "$funcname" -cache | grep end | cut -d ' ' -f 2 | paste -sd ",")

        if [ -z "$addrs_begin" ] || [ -z "$addrs_end" ]; then
            scPrint "WARNING --------------------------------------------------------------------------------"
            scPrint "WARNING Unable to find module addresses for $funcname in $module of $cspec" 
            scPrint "WARNING --------------------------------------------------------------------------------"
            continue
        fi

        cmd="$SPEC_CHOP_PATH/spec-chop-lsf-submit.sh"
        cmd="$cmd WRAPPER $SPEC_CHOP_PATH/spec-chop-wrapper-trace.sh"
        cmd="$cmd TRACE_PATH $SPEC_CHOP_DB_BASEPATH/trace/$SPEC_CHOP_SAMPLE_EVENT/$SPEC_CHOP_SAMPLE_PERIOD/$cspec/$coverage.$size.$module.$funcname"
        # shellcheck disable=SC2089
        cmd="$cmd BEGIN '$addrs_begin'"
        cmd="$cmd END '$addrs_end'"
        cmd="$cmd BENCHMARKS $cspec"
        cmd="$cmd BENCH_NAME $cspec"

        while [ "$(bjobs | grep -c "$(whoami)")" -gt "$SPEC_CHOP_MAX_LSF_JOBS" ]; do
            scPrint "Wait jobs to finish ... (sleep a minute)"
            sleep 60
        done;

        # shellcheck disable=SC2086,SC2090
        SPEC_CHOP_BENCHMARKS=$cspec $cmd  
        
    done < "$temp"
    rm -f "$temp"

done;

exit 0
