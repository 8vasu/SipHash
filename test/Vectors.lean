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
Checks the one-shot SipHash functions (`sipHash24`, `sipHash13`) against the
standard reference test vectors. A "vector" is an expected 8-byte output hash:
for row `i` the input is `[0, 1, ..., i - 1]` under the fixed seed `[0, ..., 15]`,
and the vector is the hash the C reference publishes for it.
-/

import SipHash
open SipHash

-- Reference data file.
def REFERENCE_FILE : String := "vector_test_data"

-- Result markers.
def PASS_MARKER : String := "PASS"
def FAIL_MARKER : String := "FAIL"

-- Separator between fields on a data line.
def FIELD_SEPARATOR : String := " "

-- Column headings.
def INDEX_HEADING : String := "i"
def SIP24_HEADING : String := "sipHash24"
def SIP13_HEADING : String := "sipHash13"

-- Column widths, derived from the headings.
def INDEX_WIDTH : Nat := Nat.max INDEX_HEADING.length 2
def SIP24_WIDTH : Nat := SIP24_HEADING.length
def SIP13_WIDTH : Nat := SIP13_HEADING.length

-- Dashed underlines sized to each column.
def INDEX_DASHES : String := String.ofList (List.replicate INDEX_WIDTH '-')
def SIP24_DASHES : String := String.ofList (List.replicate SIP24_WIDTH '-')
def SIP13_DASHES : String := String.ofList (List.replicate SIP13_WIDTH '-')

/-- The fixed seed `[0, 1, ..., 15]` shared by every test vector. -/
def SEED : Vector UInt8 16 :=
  ⟨(List.range 16).map Nat.toUInt8 |>.toArray, by decide⟩

/-- The bytes `[0, 1, ..., index - 1]`,
    matching the C reference's input for that index. -/
def makeInput (index : Nat) : Array UInt8 :=
  (List.range index).map Nat.toUInt8 |>.toArray

/-- Pads `text` with trailing spaces up to `width`.
    Wider `text` is left unchanged. -/
def padRight (text : String) (width : Nat) : String :=
  text ++ String.ofList (List.replicate (width - min width text.length) ' ')

/-- `PASS_MARKER` when the computed hash matches the reference,
    `FAIL_MARKER` otherwise. -/
def passOrFail (computed expected : UInt64) : String :=
  if computed == expected then PASS_MARKER else FAIL_MARKER

/-- Parses one `index hash24 hash13` data line and renders its table row.
    Returns `none` if malformed. -/
def checkLine (line : String) : Option String :=
  match line.splitOn FIELD_SEPARATOR with
  | [indexField, hash24Field, hash13Field] =>
    indexField.toNat?  >>= fun index      =>
    hash24Field.toNat? >>= fun expected24 =>
    hash13Field.toNat? >>= fun expected13 =>

    let input    := makeInput index
    let result24 := passOrFail (sipHash24 SEED input) expected24.toUInt64
    let result13 := passOrFail (sipHash13 SEED input) expected13.toUInt64

    let indexCell := padRight s!"{index}" INDEX_WIDTH
    let cell24    := padRight result24 SIP24_WIDTH
    let cell13    := padRight result13 SIP13_WIDTH

    some s!"| {indexCell} | {cell24} | {cell13} |"
  | _ => none

-- Padded headings and the full table header block.
def INDEX_HEADING_PADDED : String := padRight INDEX_HEADING INDEX_WIDTH
def SIP24_HEADING_PADDED : String := padRight SIP24_HEADING SIP24_WIDTH
def SIP13_HEADING_PADDED : String := padRight SIP13_HEADING SIP13_WIDTH

def TABLE_HEADER : String :=
  s!"seed := [0, 1, 2, ..., 14, 15]

input := match i with
| 0 => []
| j + 1 => [0, 1, 2, ..., j - 1, j]

| {INDEX_HEADING_PADDED} | {SIP24_HEADING_PADDED} | {SIP13_HEADING_PADDED} |
|-{INDEX_DASHES}-|-{SIP24_DASHES}-|-{SIP13_DASHES}-|
"

/-- Prints the table header, then a checked row per line
    of the reference file. -/
def runTests : IO Unit := do
  IO.print TABLE_HEADER

  let lines := (← IO.FS.readFile REFERENCE_FILE).splitOn "\n" |>.filter (· ≠ "")
  (lines.filterMap checkLine).forM IO.println

#eval runTests
