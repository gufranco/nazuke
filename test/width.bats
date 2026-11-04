#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup() {
  WORK="$(mktemp -d /tmp/nz-width.XXXXXX)"
  WORK="$(cd "${WORK}" && pwd -P)"
  TARGET="${WORK}/target"
  mkdir -p "${TARGET}"
}

teardown() {
  rm -rf "${WORK}"
}

widest_line() {
  awk '{ if (length($0) > widest) { widest = length($0) } } END { print widest + 0 }'
}

@test "help never prints a line wider than 80 columns" {
  # Arrange
  local page widest

  # Act
  page="$(nz_test_run help)"

  # Assert
  widest="$(printf '%s\n' "${page}" | widest_line)"
  [[ "${widest}" -le 80 ]]
}

@test "version never prints a line wider than 80 columns" {
  # Arrange
  local page widest

  # Act
  page="$(nz_test_run version)"

  # Assert
  widest="$(printf '%s\n' "${page}" | widest_line)"
  [[ "${widest}" -le 80 ]]
}

@test "an error stays on one line, however long" {
  # Arrange
  local message="a file named like the short name it would get is in the way, so it keeps its own name and the folder is left alone"

  # Act
  run nz_test_call nz_error "${message}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "nazuke: ${message}" ]]
}

@test "a doctor row stays on one line, however long" {
  # Arrange
  local expected="mkdir              ok       /opt/homebrew/opt/uutils-coreutils/libexec/uubin/mkdir, uutils 0.12.0"

  # Act
  run nz_test_call nz_doctor_row "mkdir" ok "/opt/homebrew/opt/uutils-coreutils/libexec/uubin/mkdir, uutils 0.12.0"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "internal NZ_ variables from the environment change nothing" {
  # Arrange
  nz_test_files "${TARGET}" "Apple Pie Recipe.txt" "Melon Smoothie.txt"

  # Act
  NZ_DRY_RUN=yes NZ_MAX=4 NZ_PACK=/nowhere run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Renamed 2 files."* ]]
  [[ -f "${TARGET}/APPLEPR.TXT" ]]
  [[ -f "${TARGET}/MELONS.TXT" ]]
}
