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

set +u
if [ -z "$SPEC_CHOP_MPT2TST_BENCH" ]; then
    # shellcheck disable=SC2061,SC2035
    find "$SPEC_CHOP_DB_BASEPATH" -type f -name *.mpt.gz -print0 | xargs --null -n 1 basename | sort -n
    # shellcheck disable=SC2061,SC2035
    find "$SPEC_CHOP_DB_BASEPATH" -type f -name *.mpt.gz -print0 | xargs --null -n 1 -P "$(grep -c "processor" /proc/cpuinfo)" spec-chop-mpt2tst-helper.sh
else
    # shellcheck disable=SC2061,SC2035
    find "$SPEC_CHOP_DB_BASEPATH" -type f -name *.mpt.gz | grep "$SPEC_CHOP_MPT2TST_BENCH" | xargs -n 1 basename | sort -n
    # shellcheck disable=SC2061,SC2035
    find "$SPEC_CHOP_DB_BASEPATH" -type f -name *.mpt.gz | grep "$SPEC_CHOP_MPT2TST_BENCH" | xargs -n 1 -P "$(grep -c "processor" /proc/cpuinfo)" spec-chop-mpt2tst-helper.sh
fi
set -u
exit 0
