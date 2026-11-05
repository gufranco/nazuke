#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/nz-name.XXXXXX")"
  WORK="$(cd "${WORK}" && pwd -P)"
}

teardown() {
  rm -rf "${WORK}"
}

names_differ() {
  local pack="$1"
  local -a texts=()
  local text expected
  while IFS=$'\t' read -r text expected; do
    texts+=("${text}")
  done <"${NAZUKE_TESTS_DIR}/names/${pack}.tsv"
  nz_test_run name --words "${pack}" -- "${texts[@]}" >"${WORK}/got" || return 1
  cut -f 2 "${NAZUKE_TESTS_DIR}/names/${pack}.tsv" >"${WORK}/want" || return 1
  diff "${WORK}/want" "${WORK}/got"
}

@test "every name of the games corpus matches the reference" {
  # Arrange
  local expected=""

  # Act
  run names_differ games

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "every name of the generic corpus matches the reference" {
  # Arrange
  local expected=""

  # Act
  run names_differ generic

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "one name is printed per text, in order" {
  # Arrange
  local -a texts=("Grand Theft Auto" "Apple Pie Recipe")

  # Act
  run nz_test_run name "${texts[@]}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == $'GRANDTA\nAPPLEPR' ]]
}

@test "a text with nothing to keep gets the pack's fallback" {
  # Arrange
  local text="!!! ???"

  # Act
  run nz_test_run name "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "FILE" ]]
}

@test "a disc number in a tag survives the tag removal" {
  # Arrange
  local -a texts=("Final Fantasy VII (USA) (Disc 1)" "Final Fantasy VII (USA) (Disc 2)")

  # Act
  run nz_test_run name --words games "${texts[@]}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == *1 ]]
  [[ "${lines[1]}" == *2 ]]
  [[ "${lines[0]%1}" == "${lines[1]%2}" ]]
}

@test "a disk, side, tape or part number in a tag survives as well" {
  # Arrange
  local -a texts=("Harry & Harry (1986)(Disk 2 of 2)" "Tape Game [Tape 3]" "Song (Side B)" "Story (Part 4)")

  # Act
  run nz_test_run name "${texts[@]}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == *2 ]]
  [[ "${lines[1]}" == *3 ]]
  [[ "${lines[2]}" == *B ]]
  [[ "${lines[3]}" == *4 ]]
}

@test "a title too long only for a long digit run drops that run" {
  # Arrange
  local text="Pyramid_9820_Brochure_198611"

  # Act
  run nz_test_run name "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ ^PYR[A-Z]*9820[A-Z]+$ ]]
}

@test "a title too long for its short digit runs is named from its words" {
  # Arrange
  local text="IMG 2024 03 11 Beach Sunset"

  # Act
  run nz_test_run name "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ ^IMG[A-Z]+$ ]]
}

@test "a title of digits only keeps its leading digits" {
  # Arrange
  local text="92067-18534_2040"

  # Act
  run nz_test_run name "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "92067185" ]]
}

@test "letters outside A to Z become their plain form" {
  # Arrange
  local text
  text="$(printf 'Stra\303\237e \303\206ther \305\201\303\263d\305\272')"

  # Act
  run nz_test_run name --max 16 "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "STRASSAETHERLODZ" ]]
}

@test "an accent written as a separate mark is dropped" {
  # Arrange
  local text
  text="$(printf 'Cafe\314\201 Racer')"

  # Act
  run nz_test_run name "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "CAFERACE" ]]
}

@test "an en dash separates a subtitle like a hyphen" {
  # Arrange
  local text
  text="$(printf 'Mario Golf \342\200\223 Toadstool Tour')"

  # Act
  run nz_test_run name "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "MARGOLTT" ]]
}

@test "a curly apostrophe is a possessive like a straight one" {
  # Arrange
  local text
  text="$(printf 'Conker\342\200\231s Bad Fur Day')"

  # Act
  run nz_test_run name "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "CBFD" ]]
}

@test "a text written over several lines is read as one" {
  # Arrange
  local text=$'Grand\nTheft\tAuto'

  # Act
  run nz_test_run name "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "GRANDTA" ]]
}

@test "a text starting with a dash follows --" {
  # Arrange
  local text="-Grand Theft Auto"

  # Act
  run nz_test_run name -- "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "GRANDTA" ]]
}

@test "--json prints every text with its name" {
  # Arrange
  local expected='{"max":8,"words":"generic","names":[{"text":"Grand \"Theft\" Auto","name":"GRANDTA"}]}'

  # Act
  run nz_test_run name --json 'Grand "Theft" Auto'

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "without a text and a terminal the usage hint is printed" {
  # Arrange
  local expected="nazuke: no name given. run 'nazuke help' for usage."

  # Act
  run nz_test_run name </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "in a terminal the text is asked for" {
  # Arrange
  local answer="Grand Theft Auto"

  # Act
  NAZUKE_INTERACTIVE=1 run nz_test_run name <<<"${answer}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "Name to shorten: GRANDTA" ]]
}

@test "an empty answer is asked again" {
  # Arrange
  local answers=$'\nGrand Theft Auto\n'

  # Act
  NAZUKE_INTERACTIVE=1 run nz_test_run name <<<"${answers}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "Name to shorten: Name to shorten: GRANDTA" ]]
}

@test "three empty answers stop the run" {
  # Arrange
  local answers=$'\n\n\n'

  # Act
  NAZUKE_INTERACTIVE=1 run nz_test_run name <<<"${answers}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"nazuke: stopped: no name was given." ]]
}

@test "end of input at the prompt stops the run" {
  # Arrange
  local empty=""

  # Act
  NAZUKE_INTERACTIVE=1 run nz_test_run name < <(printf '%s' "${empty}")

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "Name to shorten: " ]]
}

@test "a missing temporary folder stops the run" {
  # Arrange
  local text="Grand Theft Auto"

  # Act
  TMPDIR="${WORK}/missing" run nz_test_run name "${text}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"mktemp"* ]]
}
