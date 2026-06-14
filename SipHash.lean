/-
SipHash - Streaming-capable SipHash-2-4 and SipHash-1-3 for Lean
Copyright 2026 Soumendra Ganguly

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

This file is a Lean 4 translation of parts of siphash.h and siphash.c
from the c-siphash project:
    https://github.com/c-util/c-siphash

The c-siphash project is itself based on the public-domain SipHash
reference implementation by Jean-Philippe Aumasson and Daniel J. Bernstein:
    https://github.com/veorq/SipHash

Original c-siphash work Copyright (C) 2015-2022 Red Hat, Inc.
Authors of c-siphash: Daniele Nicolodi, David Rheinsberg, Tom Gundersen.

The c-siphash project is dual-licensed under Apache-2.0 and
LGPL-2.1-or-later. This translation is distributed under Apache-2.0.

Changes: ported from C to Lean 4.
-/

namespace SipHash

/-- Reads 8 bytes starting at `offset` as a little-endian `UInt64`. -/
def readLE64 (data : Array UInt8) (offset : Nat) : UInt64 :=
  data[offset + 0]!.toUInt64 |||
  (data[offset + 1]!.toUInt64 <<< (8 : UInt64)) |||
  (data[offset + 2]!.toUInt64 <<< (16 : UInt64)) |||
  (data[offset + 3]!.toUInt64 <<< (24 : UInt64)) |||
  (data[offset + 4]!.toUInt64 <<< (32 : UInt64)) |||
  (data[offset + 5]!.toUInt64 <<< (40 : UInt64)) |||
  (data[offset + 6]!.toUInt64 <<< (48 : UInt64)) |||
  (data[offset + 7]!.toUInt64 <<< (56 : UInt64))

/--
SipHash state for an in-flight hash. Initialize it from a seed with `init`,
append data with `append24`/`append13`, then read out the hash with
`finalize24`/`finalize13`.

`v0`, `v1`, `v2`, `v3` are the internal state; `padding` holds pending bytes
that did not fill a multiple of 8; `nBytes` is the number of bytes hashed so
far.
-/
structure LeanSipHash where
  v0 : UInt64
  v1 : UInt64
  v2 : UInt64
  v3 : UInt64
  padding : UInt64
  nBytes : Nat

/--
Initializes the SipHash state from a 128-bit `seed`. Once initialized, the
state can hash arbitrary input: feed data with `append24`/`append13`, then get
the final hash with `finalize24`/`finalize13`.

The hashes depend on the seed. Every user is highly encouraged to provide
their own unique seed. If no stable hashes are needed, a random seed will do.
-/
def init (seed : Vector UInt8 16) : LeanSipHash :=
  let k0 : UInt64 := readLE64 seed.toArray 0
  let k1 : UInt64 := readLE64 seed.toArray 8

  {
    -- Magic constants from the SipHash reference implementation
    -- ("somepseudorandomlygeneratedbytes").
    v0 := (0x736f6d6570736575 : UInt64) ^^^ k0,
    v1 := (0x646f72616e646f6d : UInt64) ^^^ k1,
    v2 := (0x6c7967656e657261 : UInt64) ^^^ k0,
    v3 := (0x7465646279746573 : UInt64) ^^^ k1,
    padding := (0 : UInt64),
    nBytes := 0
  }

/-- Circular left rotation of the 64-bit word `x` by `b` bits. -/
def rotateLeft (x : UInt64) (b : Nat) : UInt64 :=
  (x <<< (b.toUInt64)) ||| (x >>> ((64 : UInt64) - (b.toUInt64)))

/-- One SipHash round: mixes the four state words `v0`, `v1`, `v2`, `v3`
    using additions, rotations, and xors. -/
def sipRound (state : LeanSipHash) : LeanSipHash :=
  let v0 : UInt64 := state.v0
  let v1 : UInt64 := state.v1
  let v2 : UInt64 := state.v2
  let v3 : UInt64 := state.v3

  let v0 := v0 + v1
  let v1 := rotateLeft v1 13
  let v1 := v1 ^^^ v0
  let v0 := rotateLeft v0 32
  let v2 := v2 + v3
  let v3 := rotateLeft v3 16
  let v3 := v3 ^^^ v2
  let v0 := v0 + v3
  let v3 := rotateLeft v3 21
  let v3 := v3 ^^^ v0
  let v2 := v2 + v1
  let v1 := rotateLeft v1 17
  let v1 := v1 ^^^ v2
  let v2 := rotateLeft v2 32

  { state with v0, v1, v2, v3 }

/-- Applies `sipRound` to the state `n` times. -/
def sipRoundN (state : LeanSipHash) (n : Nat) : LeanSipHash :=
  -- (List.range n).foldl (fun s _ => sipRound s) state
  match n with
  | 0 => state
  | k + 1 => sipRoundN (sipRound state) k

def getPadding (stateTuple : UInt64 × Nat × Nat) (bytes : Array UInt8) :
    UInt64 × Nat × Nat :=
  let (padding, i, left) : UInt64 × Nat × Nat := stateTuple

  if hI : i < bytes.size then
    if hLeft : left < 8 then
      let updatedPadding : UInt64 :=
        padding ||| (bytes[i]!.toUInt64 <<< (left * 8).toUInt64)

      getPadding (updatedPadding, i + 1, left + 1) bytes
    else
      (padding, i, left)
  else
    (padding, i, left)
termination_by bytes.size - stateTuple.2.1
decreasing_by omega

/--
Once at a 64-bit boundary, we can operate on the input in 64-bit chunks from
`i` up to `boundary`. This is much faster than processing one byte at a time.
-/
def compressChunks (state : LeanSipHash) (bytes : Array UInt8)
    (i : Nat) (boundary : Nat) (n : Nat) : LeanSipHash :=
  if i < boundary then
    let m : UInt64 := readLE64 bytes i

    let state : LeanSipHash := { state with v3 := state.v3 ^^^ m }

    let state : LeanSipHash := sipRoundN state n

    let state : LeanSipHash := { state with v0 := state.v0 ^^^ m }

    compressChunks state bytes (i + 8) boundary n
  else
    state
termination_by boundary - i

def appendAligned (state : LeanSipHash) (bytes : Array UInt8)
    (i : Nat) (n : Nat) : LeanSipHash :=
  -- We want to % (mod) state.nBytes by sizeof(UInt64), which is 8.
  -- But `&&& 7` is same as `% 8` in output but faster.
  let boundary : Nat := bytes.size - (state.nBytes &&& 7)
  let state : LeanSipHash := compressChunks state bytes i boundary n

  -- Now that we have hashed as many 64-bit chunks as possible, remember the
  -- remaining trailing bytes in `padding`, so the next append (or the
  -- finalizer) can access them.
  let (padding, _, _): UInt64 × Nat × Nat :=
    getPadding (state.padding, boundary, 0) bytes

  { state with padding := padding }

def compressWord (state : LeanSipHash) (padding : UInt64)
    (n : Nat) : LeanSipHash :=
  let state : LeanSipHash := { state with v3 := state.v3 ^^^ padding }

  let state : LeanSipHash := sipRoundN state n

  { state with v0 := state.v0 ^^^ padding, padding := 0 }

def appendN (state : LeanSipHash) (bytes : Array UInt8)
    (n : Nat) : LeanSipHash :=
  let left : Nat := state.nBytes &&& 7
  let state : LeanSipHash :=
    { state with nBytes := state.nBytes + bytes.size }

  -- SipHash operates on 64-bit chunks. If the previous append was not a
  -- multiple of 64 bits, we must first operate on single bytes.
  let (state, i): LeanSipHash × Nat := if left > 0 then
    let (padding, i, left): UInt64 × Nat × Nat :=
      getPadding (state.padding, 0, left) bytes

    let state : LeanSipHash := { state with padding := padding }

    if i == bytes.size && left < 8 then
      (state, bytes.size)
    else
      (compressWord state padding n, i)
  else
    (state, 0)

  if i == bytes.size then state else appendAligned state bytes i n

/--
Feeds `bytes` into the SipHash state machine using the SipHash-2-4 variant.
This is streaming-capable: the resulting hash is the same regardless of how you
chunk the input. It does not produce a final hash; call it many times to append
more data, then call `finalize24` to retrieve the hash.
-/
def append24 (state : LeanSipHash) (bytes : Array UInt8) : LeanSipHash :=
  appendN state bytes 2

/-- Like `append24`, but the SipHash-1-3 variant; finalize with `finalize13`. -/
def append13 (state : LeanSipHash) (bytes : Array UInt8) : LeanSipHash :=
  appendN state bytes 1

def finalizeNM (state : LeanSipHash) (n : Nat) (m : Nat) : UInt64 :=
  let b : UInt64 := state.padding ||| (state.nBytes.toUInt64 <<< (56 : UInt64))

  let state : LeanSipHash := { state with v3 := state.v3 ^^^ b }

  let state : LeanSipHash := sipRoundN state n

  let state : LeanSipHash := {
    state with
      v0 := state.v0 ^^^ b
      v2 := state.v2 ^^^ (0xff : UInt64)
  }

  let state : LeanSipHash := sipRoundN state m

  state.v0 ^^^ state.v1 ^^^ state.v2 ^^^ state.v3

/--
Produces the final SipHash-2-4 hash for the given state: the hash of the
concatenated bytes fed in via `append24`. Returns a 64-bit hash value.
-/
def finalize24 (state : LeanSipHash) : UInt64 :=
  finalizeNM state 2 4

/-- Like `finalize24`, but produces the final SipHash-1-3 hash. -/
def finalize13 (state : LeanSipHash) : UInt64 :=
  finalizeNM state 1 3

/--
One-shot SipHash-2-4 of `bytes` under `seed`. Unlike the streaming API, this is
a single call suitable for data that is all available at once. Returns a 64-bit
hash value.
-/
def sipHash24 (seed : Vector UInt8 16) (bytes : Array UInt8) : UInt64 :=
  finalize24 (append24 (init seed) bytes)

/-- Like `sipHash24`, but the one-shot SipHash-1-3 of `bytes` under `seed`. -/
def sipHash13 (seed : Vector UInt8 16) (bytes : Array UInt8) : UInt64 :=
  finalize13 (append13 (init seed) bytes)

end SipHash
