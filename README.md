# SipHash

A small, dependency-free, streaming-capable SipHash-2-4 and SipHash-1-3 implementation in Lean 4.

The library is self-contained in a single file `SipHash.lean`, so you can simply copy the file into your project while keeping its attribution header. If you prefer a build-system workflow, the essential `lake` files are included too.

The tests need no toolchain or IDE setup either: with the included test data, they run on any system with a POSIX shell and `lean` on `PATH`. Regenerating that data from the reference C implementation also needs `gcc` and `git`.

The file `SipHash.lean` is a Lean 4 translation of part of the streaming-capable C implementation [c-siphash](https://github.com/c-util/c-siphash), which is based on the reference implementation [SipHash](https://github.com/veorq/SipHash).

## Motivation

I originally wrote this as part of a formally verified Rust hash table project, where the verification runs on a faithful translation of the Rust code to Lean 4. I later extracted it into this standalone library for reusability.

In the original Rust code, keys are hashed using `std::collections::hash_map::DefaultHasher`. Writing this library doubled as a fun exercise and as a faithful stand-in for `DefaultHasher`, which is SipHash-1-3 with an all-zero seed.

## API

The following are under the `SipHash` namespace:

### One-shot

- `sipHash24, sipHash13` `(seed : Vector UInt8 16) (bytes : Array UInt8) : UInt64`

### Streaming

- `init` `(seed : Vector UInt8 16) : LeanSipHash`
- `append24, append13` `(state : LeanSipHash) (bytes : Array UInt8) : LeanSipHash`
- `finalize24, finalize13` `(state : LeanSipHash) : UInt64`

## Usage

```lean
import SipHash

def seed : Vector UInt8 16 :=
  ⟨#[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], by decide⟩

-- One-shot.
#eval SipHash.sipHash24 seed #[1, 2, 3, 4, 5]
#eval SipHash.sipHash13 seed #[1, 2, 3, 4, 5]

-- Streaming SipHash-2-4: feed bytes in any number of chunks, then finalize.
-- For SipHash-1-3 instead, replace `append24` with `append13` and `finalize24`
-- with `finalize13`.
#eval
  let h := SipHash.init seed
  let h := SipHash.append24 h #[1, 2, 3]
  let h := SipHash.append24 h #[4, 5]
  SipHash.finalize24 h
```
