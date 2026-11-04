#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/nz-ui.XXXXXX")"
  WORK="$(cd "${WORK}" && pwd -P)"
  TARGET="${WORK}/target"
  nz_test_files "${TARGET}" "Grand Theft Auto.txt" "Apple Pie Recipe.txt" "README"
  export NAZUKE_TEST_GUM=1
  export NAZUKE_TEST_GUM_LOG="${WORK}/gum.log"
  export NAZUKE_TEST_GUM_ANSWERS="${WORK}/answers"
  export NAZUKE_INTERACTIVE=1
  unset KODOUGU_THEME KODOUGU_ACCENT NAZUKE_THEME NO_COLOR
  : >"${NAZUKE_TEST_GUM_LOG}"
}

teardown() {
  chmod -R u+rwx "${WORK}"
  rm -rf "${WORK}"
}

answers() {
  printf '%s\n' "$@" >"${NAZUKE_TEST_GUM_ANSWERS}"
}

called() {
  grep -q -F -- "$1" "${NAZUKE_TEST_GUM_LOG}"
}

from_work() {
  (cd "${WORK}" && "$@")
}

@test "the menu opens under the header and shortens a name" {
  # Arrange
  answers "Shorten a name" "Grand Theft Auto"

  # Act
  NO_COLOR=1 run nz_test_run </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"give long names short, readable, unique ones"* ]]
  [[ "${output}" == *"Grand Theft Auto   GRANDTA"* ]]
  called "choose --header What would you like to do?"
  called "input --header Name to shorten"
}

@test "the menu renames the files of a folder after a yes" {
  # Arrange
  answers "Rename the files of a folder" "${TARGET}" "yes"

  # Act
  run nz_test_run </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ -f "${TARGET}/GRANDTA.TXT" && -f "${TARGET}/APPLEPR.TXT" && -f "${TARGET}/README" ]]
  [[ "${output}" == *"Renamed 2 files."* ]]
  called "input --header Folder whose files get short names"
  called "confirm Rename 2 files?"
}

@test "a cancelled menu stops the run" {
  # Arrange
  answers "<cancel>"

  # Act
  run nz_test_run </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "names are drawn as a table" {
  # Arrange
  local text="Apple Pie Recipe"

  # Act
  NO_COLOR=1 run nz_test_run name "${text}" </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Apple Pie Recipe   APPLEPR"* ]]
}

@test "the summary, the plan and the result are drawn" {
  # Arrange
  answers "yes"

  # Act
  NO_COLOR=1 run nz_test_run rename "${TARGET}" </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Plan:   rename 2 files to a name of up to 8 characters"* ]]
  [[ "${output}" == *"Kept:   1 file already short"* ]]
  [[ "${output}" == *"Words:  generic"* ]]
  [[ "${output}" == *"Grand Theft Auto.txt   GRANDTA.TXT"* ]]
  [[ "${output}" == *"Renamed 2 files."* ]]
}

@test "an empty folder answer renames in the current folder" {
  # Arrange
  answers "" "yes"
  cd "${TARGET}"

  # Act
  run nz_test_run rename </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ -f "${TARGET}/GRANDTA.TXT" ]]
  called "--placeholder ${TARGET}"
}

@test "a no at the confirmation renames nothing" {
  # Arrange
  answers "no"

  # Act
  run nz_test_run rename "${TARGET}" </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"ERROR nazuke: stopped: nothing was renamed."* ]]
  [[ -f "${TARGET}/Grand Theft Auto.txt" ]]
}

@test "a dry run shows the plan and asks nothing" {
  # Arrange
  answers

  # Act
  run nz_test_run rename --dry-run "${TARGET}" </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Mode:   dry run, nothing is renamed"* ]]
  [[ "${output}" == *"Dry run: 2 files would get a short name. Nothing was renamed."* ]]
  [[ "$(grep -c -F -- confirm "${NAZUKE_TEST_GUM_LOG}" || true)" -eq 0 ]]
}

@test "a failure is drawn as an error" {
  # Arrange
  answers "yes"
  : >"${TARGET}/.nazuke-1"

  # Act
  run nz_test_run rename "${TARGET}" </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"ERROR nazuke: .nazuke-1 is in the way"* ]]
}

@test "a cancelled folder prompt stops the run" {
  # Arrange
  answers "<cancel>"

  # Act
  run nz_test_run rename </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ -f "${TARGET}/Grand Theft Auto.txt" ]]
}

@test "a cancelled name prompt stops the run" {
  # Arrange
  answers "<cancel>"

  # Act
  run nz_test_run name </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "doctor draws its rows in a table" {
  # Arrange
  local expected="Ready. Every tool nazuke needs is here."

  # Act
  run nz_test_run doctor </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"${expected}"* ]]
  [[ "${output}" == *"gum"* ]]
}

@test "doctor reports a missing mv below the table" {
  # Arrange
  local farm
  farm="$(nz_test_farm mv)"

  # Act
  run nz_test_run_path "${farm}" doctor </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"ERROR nazuke: a required tool is missing."* ]]
}

@test "doctor fails without gum" {
  # Arrange
  local farm
  farm="$(nz_test_farm gum)"

  # Act
  NAZUKE_TEST_GUM=0 run nz_test_run_path "${farm}" doctor </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"gum                missing  install with: brew install gum"* ]]
}

@test "version shows the version and platform as badges" {
  # Arrange
  local version
  version="$(sed -n 's/^NAZUKE_VERSION="\(.*\)"$/\1/p' "${REPO_DIR}/lib/core.sh")"

  # Act
  run nz_test_run version </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "nazuke ${version} platform "* ]]
}

@test "help is formatted with gum" {
  # Arrange
  local expected="## Usage"

  # Act
  run nz_test_run help </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"${expected}"* ]]
  called "format --theme pink"
}

@test "an unknown option is drawn as an error" {
  # Arrange
  local option="--nope"

  # Act
  run nz_test_run name "${option}" </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "ERROR nazuke: unknown option '--nope'. run 'nazuke help' for usage." ]]
}

@test "--theme picks the palette over the environment" {
  # Arrange
  local theme="nord"

  # Act
  KODOUGU_THEME=dracula NAZUKE_THEME=gruvbox run nz_test_run --theme "${theme}" version </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  called "--background #88C0D0"
}

@test "--theme= with a value picks the palette" {
  # Arrange
  local option="--theme=tokyo-night"

  # Act
  run nz_test_run "${option}" version </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  called "--background #7AA2F7"
}

@test "NAZUKE_THEME overrides KODOUGU_THEME" {
  # Arrange
  local theme="catppuccin-latte"

  # Act
  KODOUGU_THEME=dracula NAZUKE_THEME="${theme}" run nz_test_run version </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  called "--background #8839EF"
}

@test "an unknown theme stops before anything runs" {
  # Arrange
  local theme="solarized"

  # Act
  KODOUGU_THEME="${theme}" run nz_test_run rename "${TARGET}" </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"got: solarized"* ]]
  [[ -f "${TARGET}/Grand Theft Auto.txt" ]]
}

@test "--theme without a value stops with the usage hint" {
  # Arrange
  local option="--theme"

  # Act
  run nz_test_run version "${option}" </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"option '--theme' needs a value. run 'nazuke help' for usage."* ]]
}

@test "--theme after -- is a text to shorten" {
  # Arrange
  local text="--theme"

  # Act
  NAZUKE_TEST_GUM=0 run from_work nz_test_run name -- "${text}" </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "THEME" ]]
}

@test "a table lines up names with letters outside ASCII" {
  # Arrange
  local -a texts
  texts=("$(printf 'Stra\303\237e der Sterne')" "Apple Pie Recipe")

  # Act
  NO_COLOR=1 run nz_test_run name "${texts[@]}" </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"$(printf 'Stra\303\237e der Sterne   STDERSTE')"* ]]
  [[ "${output}" == *"Apple Pie Recipe    APPLEPR"* ]]
}
