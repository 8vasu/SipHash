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

VECTOR_TEST_DATA="${SCRIPT_DIR}/vector_test_data"
STREAMING_TEST_DATA="${SCRIPT_DIR}/streaming_test_data"

STREAMING_INPUT_LENGTH=28
STREAMING_SEED_BYTES="42 17 99 3 200 55 128 7 91 44 13 250 37 180 66 5"

padded_echo() {
    echo
    echo "$1"
    echo
}
