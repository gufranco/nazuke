#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/nz-settings.XXXXXX")"
  WORK="$(cd "${WORK}" && pwd -P)"
}

teardown() {
  rm -rf "${WORK}"
}

@test "--max sets the longest name" {
  # Arrange
  local text="Super Mario 64"

  # Act
  run nz_test_run name --max 12 "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "SUPERMARIO64" ]]
}

@test "--max= with the value joined works the same" {
  # Arrange
  local text="Super Mario 64"

  # Act
  run nz_test_run name --max=12 "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "SUPERMARIO64" ]]
}

@test "NAZUKE_MAX sets the longest name" {
  # Arrange
  local text="Super Mario 64"

  # Act
  NAZUKE_MAX=12 run nz_test_run name "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "SUPERMARIO64" ]]
}

@test "--max on the command line wins over NAZUKE_MAX" {
  # Arrange
  local text="Super Mario 64"

  # Act
  NAZUKE_MAX=4 run nz_test_run name --max 12 "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "SUPERMARIO64" ]]
}

@test "--max below 4 is refused" {
  # Arrange
  local expected="nazuke: --max must be a whole number from 4 to 255, got: 3"

  # Act
  run nz_test_run name --max 3 "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "--max above 255 is refused" {
  # Arrange
  local expected="nazuke: --max must be a whole number from 4 to 255, got: 256"

  # Act
  run nz_test_run name --max 256 "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "--max with a leading zero is refused" {
  # Arrange
  local expected="nazuke: --max must be a whole number from 4 to 255, got: 08"

  # Act
  run nz_test_run name --max 08 "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a long number for --max is refused without overflowing" {
  # Arrange
  local expected="nazuke: --max must be a whole number from 4 to 255, got: 99999999999999999999"

  # Act
  run nz_test_run name --max 99999999999999999999 "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a bad NAZUKE_MAX is named as the environment variable" {
  # Arrange
  local expected="nazuke: NAZUKE_MAX must be a whole number from 4 to 255, got: eight"

  # Act
  NAZUKE_MAX=eight run nz_test_run name "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "--max without its value is refused" {
  # Arrange
  local expected="nazuke: option '--max' needs a value. run 'nazuke help' for usage."

  # Act
  run nz_test_run name --max

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "--ext out of range is refused" {
  # Arrange
  local expected="nazuke: --ext must be a whole number from 1 to 255, got: 0"

  # Act
  run nz_test_run rename --ext 0 "${WORK}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a bad NAZUKE_EXT is named as the environment variable" {
  # Arrange
  local expected="nazuke: NAZUKE_EXT must be a whole number from 1 to 255, got: -1"

  # Act
  NAZUKE_EXT=-1 run nz_test_run rename "${WORK}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "--words games drops generic title words" {
  # Arrange
  local text="Super Mario 64 (USA)"

  # Act
  run nz_test_run name --words games "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "MARIO64" ]]
}

@test "NAZUKE_WORDS picks the pack" {
  # Arrange
  local text="Super Mario 64 (USA)"

  # Act
  NAZUKE_WORDS=games run nz_test_run name "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "MARIO64" ]]
}

@test "an unknown pack name is refused" {
  # Arrange
  local expected="nazuke: --words must be generic, games or the path of a word pack, got: films"

  # Act
  run nz_test_run name --words films "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a bad NAZUKE_WORDS is named as the environment variable" {
  # Arrange
  local expected="nazuke: NAZUKE_WORDS must be generic, games or the path of a word pack, got: films"

  # Act
  NAZUKE_WORDS=films run nz_test_run name "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a pack file of your own is read from its path" {
  # Arrange
  printf '%s\n' "fallback DOC" "stopwords OF THE" "droppable DRAFT" >"${WORK}/office"

  # Act
  run nz_test_run name --words "${WORK}/office" "Draft Budget Plan" "???"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == "BUDGPLAN" ]]
  [[ "${lines[1]}" == "DOC" ]]
}

@test "a pack path that does not exist is refused" {
  # Arrange
  local missing="${WORK}/missing-pack"

  # Act
  run nz_test_run name --words "${missing}" "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "nazuke: cannot read the word pack: ${missing}" ]]
}

@test "a pack with an unknown key names the line" {
  # Arrange
  printf '%s\n' "fallback DOC" "colour BLUE" >"${WORK}/bad"

  # Act
  run nz_test_run name --words "${WORK}/bad" "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "nazuke: the word pack ${WORK}/bad has a problem on line 2: unknown key: colour." ]]
}

@test "a pack fallback in lower case is refused" {
  # Arrange
  printf '%s\n' "fallback doc" >"${WORK}/bad"

  # Act
  run nz_test_run name --words "${WORK}/bad" "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"line 1: fallback needs one word of A to Z and 0 to 9." ]]
}

@test "a pack region needs a word and one letter" {
  # Arrange
  printf '%s\n' "" "region USA" >"${WORK}/bad"

  # Act
  run nz_test_run name --words "${WORK}/bad" "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"line 2: region needs a word and one letter or digit." ]]
}

@test "a pack list needs at least one word" {
  # Arrange
  printf '%s\n' "stopwords" >"${WORK}/bad"

  # Act
  run nz_test_run name --words "${WORK}/bad" "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"line 1: stopwords needs at least one word." ]]
}

@test "a pack word in lower case is refused" {
  # Arrange
  printf '%s\n' "articles THE a" >"${WORK}/bad"

  # Act
  run nz_test_run name --words "${WORK}/bad" "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"line 1: articles holds an invalid word: a." ]]
}
