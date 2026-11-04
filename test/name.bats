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
