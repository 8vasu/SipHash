# SipHash

A small, dependency-free, streaming-capable SipHash-2-4 and SipHash-1-3 implementation in Lean 4.

The library is self-contained in a single file `SipHash.lean`, so you can `require` it or simply copy the file into your project.

## Motivation

I originally wrote this as part of a formally verified Rust hash table project. The verification runs on Lean 4 code that [Aeneas](https://github.com/AeneasVerif/aeneas) generates from the Rust.

In the original Rust code, keys are hashed using `DefaultHasher`. Writing this library doubled as a fun exercise and as a faithful stand-in for `DefaultHasher`, which is SipHash-1-3 with an all-zero seed.

## API

The following are under the `SipHash` namespace:

### One-shot

- `sipHash24, sipHash13` `(seed : Vector UInt8 16) (bytes : Array UInt8) : UInt64`

### Streaming

- `new` `(seed : Vector UInt8 16) : DefaultHasher`
- `write24, write13` `(state : DefaultHasher) (bytes : Array UInt8) : DefaultHasher`
- `finish24, finish13` `(state : DefaultHasher) : UInt64`

## Usage

```lean
import SipHash

def seed : Vector UInt8 16 :=
  ⟨#[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], by decide⟩

-- One-shot.
#eval SipHash.sipHash24 seed #[1, 2, 3, 4, 5]
#eval SipHash.sipHash13 seed #[1, 2, 3, 4, 5]

-- Streaming SipHash-2-4: feed bytes in any number of chunks, then finish.
--
-- Replace `write24` with `write13` and `finish24` with `finish13`
-- for SipHash-1-3:
#eval
  let h := SipHash.new seed
  let h := SipHash.write24 h #[1, 2, 3]
  let h := SipHash.write24 h #[4, 5]
  SipHash.finish24 h
```
