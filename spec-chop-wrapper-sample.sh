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

. "$SPEC_CHOP_CHOPSTIX_SETUP_FILE" >/dev/null 2>/dev/null

set -e # Finish right after a non-zero return command
set -u # Finish right after a undefined expression is used
set -a # All following variables are exported

SPEC_CHOP_COMMAND="$*"
# SPEC_CHOP_BINARY="$1"

SPEC_CHOP_DB_PATH="$SPEC_CHOP_DB_BASEPATH/sample/${SPEC_CHOP_SAMPLE_EVENT}/${SPEC_CHOP_SAMPLE_PERIOD}/$SPEC_CHOP_BENCH_NAME/${SPEC_CHOP_BENCH_NAME}.${SPEC_CHOP_SAMPLE_EVENT}.${SPEC_CHOP_SAMPLE_PERIOD}.db"

if [ ! -d "$(dirname "$SPEC_CHOP_DB_PATH")" ]; then
    mkdir -p "$(dirname "$SPEC_CHOP_DB_PATH")"
fi

#
# Sample execution
#
TEMP_DATA=$(mktemp --suffix=.db)

if [ -f "${SPEC_CHOP_DB_PATH}" ]; then
    # Copy database from previous runs it it exists
    cp "${SPEC_CHOP_DB_PATH}" "$TEMP_DATA"
fi

export CHOPSTIX_OPT_DATA=$TEMP_DATA
export CHOPSTIX_OPT_EVENTS=$SPEC_CHOP_SAMPLE_EVENT
export CHOPSTIX_OPT_PERIOD=$SPEC_CHOP_SAMPLE_PERIOD
export CHOPSTIX_OPT_TIMEOUT=$SPEC_CHOP_TIMEOUT

# shellcheck disable=SC2086
chop sample $SPEC_CHOP_COMMAND >/dev/null 2>/dev/null

cp -f "$TEMP_DATA" "$SPEC_CHOP_DB_PATH"
export CHOPSTIX_OPT_DATA="$SPEC_CHOP_DB_PATH"

#
# Disassemble binary
#
chop disasm >/dev/null 2>/dev/null

#
# Re-count samples
#
chop count >/dev/null 2>/dev/null 
chop annotate >/dev/null 2>/dev/null

if [ "$(chop list functions | head -n 1 | wc -w)" -lt 5 ]; then
    chop list sessions
    scError "Unable to generate function scores. Check DB manually"
fi

exit 0
