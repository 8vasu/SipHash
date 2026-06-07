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
-/

/-
Checks that the streaming SipHash API (`new` → `write` → `finish`) produces the
same hash as the C reference, regardless of how the input is split into chunks.
-/

import SipHash
open SipHash

-- Configuration.
def SEED_LENGTH       : Nat    := 16
def MAX_INPUT_LENGTH  : Nat    := 64
def REFERENCE_FILE    : String := "streaming_test_data"

-- Variant names, as printed.
def NAME_SIP13 : String := "siphash-1-3"
def NAME_SIP24 : String := "siphash-2-4"

-- Chunking labels, as printed.
def CHUNK_LABEL_1 : String := "1 chunk"
def CHUNK_LABEL_2 : String := "2 chunks"
def CHUNK_LABEL_3 : String := "3 chunks"

-- Result markers.
def PASS_MARKER : String := "PASS"
def FAIL_MARKER : String := "FAIL"

-- Separators.
def COLUMN_SEPARATOR : String := " | "
def RANGE_SEPARATOR  : String := ", "
def LINE_SEPARATOR   : String := "\n"
def BLOCK_SEPARATOR  : String := "\n\n"

-- Header and title labels.
def SEED_LABEL      : String := "seed  := "
def INPUT_LABEL     : String := "input := "
def REFERENCE_LABEL : String := "value from reference C implementation:"

-- Error messages.
def USAGE_MESSAGE : String :=
  s!"Args: INPUT_LENGTH SEED[0] ... SEED[{SEED_LENGTH - 1}]"
def PARSE_ERROR : String :=
  s!"Could not parse {REFERENCE_FILE}"

abbrev Seed          := Vector UInt8 SEED_LENGTH
abbrev StreamingHash := Seed → List (Array UInt8) → UInt64

/-- A SipHash variant (1-3 or 2-4): its name and streaming hash. -/
structure SipHashVariant where
  name   : String
  stream : StreamingHash

/-- Builds a streaming hash: write every chunk into a fresh hasher,
    then finish. -/
def streamWith (write : DefaultHasher → Array UInt8 → DefaultHasher)
               (finish : DefaultHasher → UInt64) : StreamingHash :=
  fun seed chunks => finish (chunks.foldl write (new seed))

/-- The two variants under test, each wrapping its `write`/`finish` pair. -/
def sip13 : SipHashVariant := ⟨NAME_SIP13, streamWith write13 finish13⟩
def sip24 : SipHashVariant := ⟨NAME_SIP24, streamWith write24 finish24⟩

/-- The bytes `[0, 1, ..., length - 1]`, matching the C reference's input. -/
def makeInput (length : Nat) : Array UInt8 :=
  (List.range length).map Nat.toUInt8 |>.toArray

/-- Consecutive `[low, high)` ranges from splitting `[0, length)`
    at the interior `bounds`. -/
def segments (length : Nat) (bounds : List Nat) : List (Nat × Nat) :=
  let edges := 0 :: (bounds ++ [length])
  edges.zip edges.tail

/-- Named chunkings of an input of the given `length`,
    by their interior split points. -/
def chunkings (length : Nat) : List (String × List Nat) :=
  [ (CHUNK_LABEL_1, []),
    (CHUNK_LABEL_2, [length / 2]),
    (CHUNK_LABEL_2, [length / 3]),
    (CHUNK_LABEL_3, [length / 3, 2 * length / 3]) ]

/-- Width of the widest chunking name, for column alignment. -/
def NAME_WIDTH : Nat :=
  (chunkings 0).map (·.1.length) |>.foldl Nat.max 0

/-- Pads `text` with trailing spaces up to `width`.
    Wider `text` is left unchanged. -/
def padRight (text : String) (width : Nat) : String :=
  text ++ String.ofList (List.replicate (width - text.length) ' ')

/-- `PASS_MARKER` when the computed hash matches the reference,
    `FAIL_MARKER` otherwise. -/
def passOrFail (computed expected : UInt64) : String :=
  if computed == expected then PASS_MARKER else FAIL_MARKER

/-- A single comparison row, before column widths are known. -/
structure Row where
  name  : String
  label : String
  hash  : UInt64

/-- One result block for a variant: a title line plus a row per chunking. -/
def reportVariant (variant : SipHashVariant) (seed : Seed)
    (input : Array UInt8) (reference : UInt64) : String :=
  let rows : List Row := (chunkings input.size).map fun (name, bounds) =>
    let ranges := segments input.size bounds
    let chunks := ranges.map fun (low, high) => input.extract low high
    let label  := RANGE_SEPARATOR.intercalate <|
                    ranges.map fun (low, high) => s!"[{low}, ..., {high - 1}]"

    { name, label, hash := variant.stream seed chunks }

  let labelWidth := rows.map (·.label.length) |>.foldl Nat.max 0
  let title := s!"{variant.name} {REFERENCE_LABEL} {reference}"
  let body  := rows.map fun row =>
    let name  := padRight row.name NAME_WIDTH
    let label := padRight row.label labelWidth
    -- Hash calculated in Lean4: `row.hash`.
    -- Hash calculated using reference C implementation: `reference`.
    let mark  := passOrFail row.hash reference

    s!"{name}{COLUMN_SEPARATOR}{label}{COLUMN_SEPARATOR}{row.hash} ({mark})"

  title ++ LINE_SEPARATOR ++ LINE_SEPARATOR.intercalate body

/-- The full report: a header for seed and input, then a block per variant. -/
def report (seed : Seed) (input : Array UInt8)
    (reference24 reference13 : UInt64) : String :=
  let header := s!"{SEED_LABEL}{seed.toArray.toList}"
             ++ LINE_SEPARATOR
             ++ s!"{INPUT_LABEL}[0, 1, ..., {input.size - 1}]"

  let blocks := [ reportVariant sip24 seed input reference24,
                  reportVariant sip13 seed input reference13 ]

  header
    ++ BLOCK_SEPARATOR
    ++ BLOCK_SEPARATOR.intercalate blocks
    ++ LINE_SEPARATOR

/-- Parses `INPUT_LENGTH SEED[0] ... SEED[15]` into an input length and seed. -/
def parseArgs (arguments : Array String) : Option (Nat × Seed) := do
  guard (arguments.size = SEED_LENGTH + 1)

  let inputLength ← arguments[0]!.toNat?
  guard (inputLength ≤ MAX_INPUT_LENGTH)

  let seedBytes ← (List.range SEED_LENGTH).mapM
    fun i => arguments[i + 1]!.toNat?
  let bytes := seedBytes.map Nat.toUInt8 |>.toArray

  if h : bytes.size = SEED_LENGTH then return (inputLength, ⟨bytes, h⟩)
  else none

/-- Parses the reference file: siphash-2-4 hash on line 1,
    siphash-1-3 on line 2. -/
def parseReferenceFile (content : String) : Option (UInt64 × UInt64) := do
  match content.splitOn LINE_SEPARATOR |>.filter (· ≠ "") with
  | [line24, line13] =>
    let reference24 ← line24.toNat?
    let reference13 ← line13.toNat?
    return (reference24.toUInt64, reference13.toUInt64)
  | _ => none

/-- Parses CLI args and the reference file, then prints the report. -/
def main (args : List String) : IO Unit := do
  let (inputLength, seed) ← match parseArgs args.toArray with
    | some parsed => pure parsed
    | none        => IO.eprintln USAGE_MESSAGE; return

  let content ← IO.FS.readFile REFERENCE_FILE
  let (reference24, reference13) ← match parseReferenceFile content with
    | some references => pure references
    | none            => IO.eprintln PARSE_ERROR; return

  IO.print (report seed (makeInput inputLength) reference24 reference13)
