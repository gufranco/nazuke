#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/nz-corpus.XXXXXX")"
  WORK="$(cd "${WORK}" && pwd -P)"
  CORPUS="${WORK}/corpus.txt"
}

teardown() {
  rm -rf "${WORK}"
}

corpus() {
  printf '%s\n' "$@" >"${CORPUS}"
}

corpus_check() {
  python3 "${REPO_DIR}/scripts/corpus-check.py" "$@"
}

sabotaged_engine() {
  local replacement="$1"
  mkdir -p "${WORK}/root"
  cp -R "${REPO_DIR}/lib" "${REPO_DIR}/share" "${WORK}/root/"
  python3 - "${WORK}/root/lib/shorten.awk" "${replacement}" <<'SWAP'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
line = 'printf "%s/%s/%s\\n", key, result[key], ext_of[key]'
if text.count(line) != 1:
    sys.exit(1)
path.write_text(text.replace(line, sys.argv[2]), encoding="utf-8")
SWAP
}

@test "every file of a corpus gets a unique valid name" {
  # Arrange
  corpus "roms/Legend of Zelda, The - Ocarina of Time (USA).z64" \
    "roms/Legend of Zelda, The - Ocarina of Time (USA) (Rev 2).z64" \
    "roms/Legend of Zelda, The - Ocarina of Time (USA) (Beta).z64" \
    "docs/Report (draft).txt" "docs/Report (final).txt" "docs/REPORT.TXT"

  # Act
  run corpus_check --words games "${CORPUS}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"files: 6"* ]]
  [[ "${output}" == *"renamed: 5"* ]]
  [[ "${output}" == *"problems: 0"* ]]
}

@test "the corpus check names each file as rename does" {
  # Arrange
  local -a names=("Legend of Zelda, The - Ocarina of Time (USA).z64" "Legend of Zelda, The - Ocarina of Time (USA) (Beta).z64"
    "Final Fantasy VII (USA) (Disc 1).cue" "Final Fantasy VII (USA) (Disc 2).cue" "GRANDTA.TXT" "Grand Theft Auto.txt")
  local name
  for name in "${names[@]}"; do
    printf 'target/%s\n' "${name}" >>"${CORPUS}"
  done
  nz_test_files "${WORK}/target" "${names[@]}"
  nz_test_run rename --words games --dry-run "${WORK}/target" >"${WORK}/dry-run.txt"
  sed -n 's/ -> /\t/p' "${WORK}/dry-run.txt" >"${WORK}/want.raw"
  LC_ALL=C sort -o "${WORK}/want.tsv" "${WORK}/want.raw"

  # Act
  corpus_check --words games --report "${WORK}/report.tsv" "${CORPUS}" >/dev/null

  # Assert
  cut -f 2,3 "${WORK}/report.tsv" >"${WORK}/got.raw"
  LC_ALL=C sort -o "${WORK}/got.tsv" "${WORK}/got.raw"
  diff "${WORK}/want.tsv" "${WORK}/got.tsv"
}

@test "a name given twice in a folder fails the check" {
  # Arrange
  corpus "docs/Apple Pie Recipe.txt" "docs/Grand Theft Auto.txt"
  sabotaged_engine 'printf "%s/SAME/TXT\n", key'

  # Act
  NAZUKE_ROOT="${WORK}/root" run corpus_check "${CORPUS}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"both get SAME.TXT"* ]]
}

@test "a file left with no name fails the check" {
  # Arrange
  corpus "docs/Apple Pie Recipe.txt"
  sabotaged_engine 'printf "%s//TXT\n", key'

  # Act
  NAZUKE_ROOT="${WORK}/root" run corpus_check "${CORPUS}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"docs: Apple Pie Recipe.txt gets no name"* ]]
}

@test "an invalid or device name fails the check" {
  # Arrange
  corpus "docs/Apple Pie Recipe.txt" "docs/Grand Theft Auto.txt"
  sabotaged_engine 'printf "%s/%s/TXT\n", key, (key == 1) ? "CON" : "a-b"'

  # Act
  NAZUKE_ROOT="${WORK}/root" run corpus_check "${CORPUS}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"gets an invalid name CON.TXT"* ]]
  [[ "${output}" == *"gets an invalid name A-B.TXT"* ]]
}

@test "more fallback names than the recorded baseline fail the check" {
  # Arrange
  corpus "docs/Apple Pie Recipe.txt"
  corpus_check --record "${CORPUS}" >/dev/null
  corpus "docs/Apple Pie Recipe.txt" "docs/!!! ???.txt"

  # Act
  run corpus_check "${CORPUS}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"fallback names rose from 0 to 1"* ]]
}

@test "fewer names kept as they stand alone than the baseline fail the check" {
  # Arrange
  corpus "docs/Report (draft).txt" "docs/Apple Pie Recipe.txt"
  corpus_check --record "${CORPUS}" >/dev/null
  corpus "docs/Report (draft).txt" "docs/Report (final).txt"

  # Act
  run corpus_check "${CORPUS}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"names kept as they stand alone fell from 100.00% to 50.00%"* ]]
}

@test "a run as good as the baseline passes and leaves it alone" {
  # Arrange
  corpus "docs/Apple Pie Recipe.txt"
  corpus_check --record "${CORPUS}" >/dev/null
  cp -f "${CORPUS}.baseline.json" "${WORK}/before.json"

  # Act
  run corpus_check "${CORPUS}"

  # Assert
  [[ "${status}" -eq 0 ]]
  cmp -s "${WORK}/before.json" "${CORPUS}.baseline.json"
}

@test "a missing corpus file stops with its path" {
  # Arrange
  local missing="${WORK}/missing.txt"

  # Act
  run corpus_check "${missing}"

  # Assert
  [[ "${status}" -eq 2 ]]
  [[ "${output}" == *"cannot read the corpus: ${missing}"* ]]
}
