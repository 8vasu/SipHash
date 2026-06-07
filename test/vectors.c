/*
 * SipHash - Streaming-capable SipHash-2-4 and SipHash-1-3 for Lean
 * Copyright 2026 Soumendra Ganguly
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* Generate data for Vectors.lean. */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define SEED_LEN   16
#define IN_LEN_MAX 64
#define OUT_LEN    sizeof(uint64_t)

int main(int argc, char *argv[]) {
  uint8_t seed[SEED_LEN], in[IN_LEN_MAX], out[OUT_LEN];
  int in_len = 0;
  uint64_t hash = 0;
  int i = 0;

  if (argc != 2) {
    fprintf(stderr, "Usage: %s INPUT_LENGTH\n", argv[0]);
    return 1;
  }

  in_len = atoi(argv[1]);
  if (in_len < 0 || in_len > IN_LEN_MAX) {
    fprintf(stderr, "INPUT_LENGTH must be between 0 and %d\n", IN_LEN_MAX);
    return 1;
  }

  /* in = {0, 1, 2, ..., IN_LEN_MAX - 1} */
  for (i = 0; i < IN_LEN_MAX; ++i) {
    in[i]  = i;
  }

  /* seed = {0, 1, 2, ..., SEED_LEN - 1} */
  for (i = 0; i < SEED_LEN; ++i) {
    seed[i] = i;
  }

  /*
   * Calculate the hash as an array of bytes `out`.
   *
   * With input length in_len, we are actually hashing
   * `in` truncated to {0, 1, 2, ..., in_len - 1}.
   *
   * If in_len == 0, we are hashing {}.
   */
  siphash(in, in_len, seed, out, OUT_LEN);

  /* Convert the output bytes to a 64-bit unsigned integer hash value. */
  for (i = 0; i < OUT_LEN; ++i) {
    hash |= (uint64_t) out[i] << (8 * i);
  }

  printf("%llu\n", (unsigned long long) hash);
}
