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

.  "$SPEC_CHOP_CHOPSTIX_SETUP_FILE"

set -e # Finish right after a non-zero return command
set -u # Finish right after a undefined expression is used
set -a # All following variables are exported

SPEC_CHOP_COMMAND="$*"
shift
SPEC_CHOP_COMMAND_ARGS="$*"
SPEC_CHOP_COMMAND_ARGS=$(echo "$SPEC_CHOP_COMMAND_ARGS" | sed -e "s@[ -./]@_@g")

if [ -z "$SPEC_CHOP_TRACE_PATH" ]; then
    scError "Output trace path not defined. Use SPEC_CHOP_TRACE_PATH environment variable."
fi

SPEC_CHOP_MPT_PATH="$(dirname "$SPEC_CHOP_TRACE_PATH")/mpts/$(basename "$SPEC_CHOP_TRACE_PATH").$SPEC_CHOP_COMMAND_ARGS"
scPrint "Output MPT path: $SPEC_CHOP_MPT_PATH" 

SPEC_CHOP_TRACE_PATH="$SPEC_CHOP_TRACE_PATH/$SPEC_CHOP_COMMAND_ARGS"
scPrint "Output trace: $SPEC_CHOP_TRACE_PATH"

if [ -f "${SPEC_CHOP_MPT_PATH}.OK" ]; then
    scPrint "MPTs already generated found. Exit success."
    exit 0
fi

skip_trace=0
if [ -f "$SPEC_CHOP_TRACE_PATH/${SPEC_CHOP_SCRIPTNAME}.OK" ]; then
    scPrint "Trace already generated found. Skip trace."
    skip_trace=1
fi

#
# Trace execution
#
if [ "$skip_trace" -eq 0 ]; then

    if [ -d "$SPEC_CHOP_TRACE_PATH/" ]; then
        scPrint "Removing previous trace. Not OK"
        rm -fr "${SPEC_CHOP_TRACE_PATH}"
    fi

    TEMP_DATA=$(mktemp --suffix=.trace)
    rm -fr "$TEMP_DATA"

    export CHOPSTIX_OPT_TRACE_DIR="$TEMP_DATA"
    CHOPSTIX_OPT_LOG_PATH=$(mktemp)
    export CHOPSTIX_OPT_LOG_PATH
    rm -f "$CHOPSTIX_OPT_LOG_PATH"
    export CHOPSTIX_OPT_LOG_LEVEL=debug
    export CHOPSTIX_OPT_BEGIN="$SPEC_CHOP_BEGIN"
    export CHOPSTIX_OPT_END="$SPEC_CHOP_END"

    set +e
    # shellcheck disable=SC2086
    chop trace $SPEC_CHOP_OPTIONS_TRACE $SPEC_CHOP_COMMAND 
    error=$?
    set -e

    if [ "$error" -ne 0 ]; then
        touch "$SPEC_CHOP_TRACE_PATH/${SPEC_CHOP_SCRIPTNAME}.FAIL"
        scError "Trace command exited with non-zero status"
    fi

    #
    # Copy results back
    #

    mkdir -p "$SPEC_CHOP_TRACE_PATH"
    cp -fr "$TEMP_DATA"/* "$SPEC_CHOP_TRACE_PATH"
    cp "$CHOPSTIX_OPT_LOG_PATH" "$SPEC_CHOP_TRACE_PATH/log"
    gzip "$SPEC_CHOP_TRACE_PATH/log"

    touch "$SPEC_CHOP_TRACE_PATH/${SPEC_CHOP_SCRIPTNAME}.OK"
    rm -f "$SPEC_CHOP_TRACE_PATH/${SPEC_CHOP_SCRIPTNAME}.FAIL"

fi

#
# Generate MPT files 
#
set +e
rm -f "$SPEC_CHOP_MPT_PATH".*
chop-trace2mpt --trace-dir "$SPEC_CHOP_TRACE_PATH" -o "$SPEC_CHOP_MPT_PATH" --gzip
set -e
error=$?
set -e

if [ "$error" -ne 0 ]; then
    touch "${SPEC_CHOP_MPT_PATH}.FAIL"
    scError "Trace to MPT command exited with non-zero status"
fi

touch "${SPEC_CHOP_MPT_PATH}.OK"
rm -f "${SPEC_CHOP_MPT_PATH}.FAIL"

exit 0
