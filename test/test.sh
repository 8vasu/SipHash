#!/bin/sh -e

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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/common.sh"

LEAN_CMD="lean"
OLEAN_DIR="/tmp"

SIPHASH_LIB="${SCRIPT_DIR}/../SipHash.lean"
SIPHASH_LIB_COMPILED="${OLEAN_DIR}/SipHash.olean"

VECTOR_TEST="${SCRIPT_DIR}/Vectors.lean"
STREAMING_TEST="${SCRIPT_DIR}/Stream.lean"

padded_echo "Compiling SipHash library..."
$LEAN_CMD --root=.. -o "$SIPHASH_LIB_COMPILED" "$SIPHASH_LIB"

if [ ! -f "$VECTOR_TEST_DATA" ]
then
    padded_echo "Error: missing ${VECTOR_TEST_DATA}." >&2
    exit 1
fi

padded_echo "Running Vector test..."
LEAN_PATH="$OLEAN_DIR" $LEAN_CMD "$VECTOR_TEST"

if [ ! -f "$STREAMING_TEST_DATA" ]
then
    padded_echo "Error: missing ${STREAMING_TEST_DATA}." >&2
    exit 1
fi

padded_echo "Running Streaming test..."
LEAN_PATH="$OLEAN_DIR" $LEAN_CMD --run "$STREAMING_TEST" \
	 $STREAMING_INPUT_LENGTH $STREAMING_SEED_BYTES
