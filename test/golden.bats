#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/nz-golden.XXXXXX")"
  WORK="$(cd "${WORK}" && pwd -P)"
  TARGET="${WORK}/target"
  nz_test_files "${TARGET}" "Pokemon Snap (USA).z64" "Pokemon Snap (Europe).z64" "Super Mario 64 (USA).z64" \
    "Legend of Zelda, The - Ocarina of Time (USA) (Rev 2).z64" "MARIO64.Z64" "notes.docx"
}

teardown() {
  rm -rf "${WORK}"
}

@test "a dry run prints the same transcript" {
  # Arrange
  local transcript

  # Act
  transcript="$(nz_test_run rename --words games --dry-run "${TARGET}")"

  # Assert
  nz_test_matches_golden dry-run "${transcript}"
}

@test "a rename prints the same transcript" {
  # Arrange
  local transcript

  # Act
  transcript="$(nz_test_run rename --words games "${TARGET}")"

  # Assert
  nz_test_matches_golden rename "${transcript}"
}
