#!/bin/sh

# SipHash - Streaming-capable SipHash-2-4 and SipHash-1-3 for Lean
# Copyright 2026 Soumendra Ganguly

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/common.sh"

SIPHASH_C_REPO_URL="https://github.com/veorq/SipHash.git"
SIPHASH_C_DIR="/tmp/ReferenceSipHash"
SIPHASH_H="${SIPHASH_C_DIR}/siphash.h"
SIPHASH_C="${SIPHASH_C_DIR}/siphash.c"

VECTOR_TEST_DATA_GENERATOR_C="${SCRIPT_DIR}/vectors.c"
VECTOR_BIN_PREFIX="/tmp/sipv"

STREAMING_TEST_DATA_GENERATOR_C="${SCRIPT_DIR}/stream.c"
STREAMING_BIN_PREFIX="/tmp/sips"

gcc_siphash() {
    gcc -DcROUNDS="$3" -DdROUNDS="$4" \
	-o "${2}${3}${4}" -include "$SIPHASH_H" \
	"$1" "$SIPHASH_C"
}

vector_compile() {
    gcc_siphash "$VECTOR_TEST_DATA_GENERATOR_C" \
		"$VECTOR_BIN_PREFIX" "$1" "$2"
}

stream_compile() {
    gcc_siphash "$STREAMING_TEST_DATA_GENERATOR_C" \
		"$STREAMING_BIN_PREFIX" "$1" "$2"
}

padded_echo "Cloning/pulling reference implementation \
of SipHash from ${SIPHASH_C_REPO_URL}..."
if [ ! -d "$SIPHASH_C_DIR" ]
then
    git clone "$SIPHASH_C_REPO_URL" "$SIPHASH_C_DIR"
else
    cd "$SIPHASH_C_DIR"
    git pull
    cd "$SCRIPT_DIR"
fi

padded_echo "Compiling reference implementation of SipHash using gcc..."
vector_compile 2 4
vector_compile 1 3
stream_compile 2 4
stream_compile 1 3

padded_echo "Generating test data in ${VECTOR_TEST_DATA} using \
reference implementation of SipHash..."
: > "${VECTOR_TEST_DATA}"

i=0
while [ $i -lt 64 ]
do
    printf "${i} " >> "${VECTOR_TEST_DATA}"
    printf "$("${VECTOR_BIN_PREFIX}24" $i) " >> "${VECTOR_TEST_DATA}"
    printf "$("${VECTOR_BIN_PREFIX}13" $i)\n" >> "${VECTOR_TEST_DATA}"
    i=$((i + 1))
done

padded_echo "Generating test data in ${STREAMING_TEST_DATA} \
using reference implementation of SipHash..."
: > "${STREAMING_TEST_DATA}"

"${STREAMING_BIN_PREFIX}24" $STREAMING_INPUT_LENGTH \
			    $STREAMING_SEED_BYTES >> "${STREAMING_TEST_DATA}"
"${STREAMING_BIN_PREFIX}13" $STREAMING_INPUT_LENGTH \
			    $STREAMING_SEED_BYTES >> "${STREAMING_TEST_DATA}"
