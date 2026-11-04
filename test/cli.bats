#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/nz-cli.XXXXXX")"
  WORK="$(cd "${WORK}" && pwd -P)"
  TARGET="${WORK}/target"
  nz_test_files "${TARGET}" "Apple Pie Recipe.txt"
}

teardown() {
  chmod -R u+rwx "${WORK}"
  rm -rf "${WORK}"
}

from_folder() {
  local dir="$1"
  shift
  (cd "${dir}" && "$@")
}

@test "help prints the usage page" {
  # Arrange
  local first="nazuke - give long names short, readable, unique ones, 8.3 by default"

  # Act
  run nz_test_run help

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == "${first}" ]]
}

@test "-h and --help print the same page as help" {
  # Arrange
  local page
  page="$(nz_test_run help)"

  # Act
  run nz_test_run -h

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${page}" ]]
  [[ "$(nz_test_run --help || true)" == "${page}" ]]
}

@test "version prints the program, its version and the platform" {
  # Arrange
  local platform version
  platform="$(uname -sr)"
  version="$(sed -n 's/^NAZUKE_VERSION="\(.*\)"$/\1/p' "${REPO_DIR}/lib/core.sh")"

  # Act
  run nz_test_run --version

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == "nazuke ${version}" ]]
  [[ "${lines[1]}" == "platform: ${platform}" ]]
}

@test "version and -V print the same lines" {
  # Arrange
  local expected
  expected="$(nz_test_run --version)"

  # Act
  run nz_test_run version

  # Assert
  [[ "${output}" == "${expected}" ]]
  [[ "$(nz_test_run -V || true)" == "${expected}" ]]
}

@test "version reports an unknown platform when uname fails" {
  # Arrange
  nz_test_shim uname "exit 1"

  # Act
  run nz_test_run --version

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[1]}" == "platform: unknown" ]]
}

@test "doctor lists gum, awk, mktemp and mv with their paths" {
  # Arrange
  local mv_path
  mv_path="$(command -v mv)"

  # Act
  run nz_test_run doctor

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == "gum                ok       "* ]]
  [[ "${lines[1]}" == "awk                ok       "* ]]
  [[ "${lines[2]}" == "mktemp             ok       "* ]]
  [[ "${lines[3]}" == "mv                 ok       ${mv_path}, "* ]]
}

@test "doctor fails and names a missing mv" {
  # Arrange
  local farm
  farm="$(nz_test_farm mv)"

  # Act
  run nz_test_run_path "${farm}" doctor

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"mv                 missing  required, part of every Linux and macOS system"* ]]
}

@test "the tool runs by its bare name from inside its own folder" {
  # Arrange
  local -a shell_words
  read -r -a shell_words <<<"${NAZUKE_TEST_SHELL:-sh}"
  cd "${REPO_DIR}/bin" || return 1

  # Act
  PATH="${REPO_DIR}/bin:${PATH}" run "${shell_words[@]}" nazuke version

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" =~ ^nazuke\ [0-9] ]]
}

@test "an unknown command is named with a hint" {
  # Arrange
  local expected="nazuke: unknown command 'shorten'. run 'nazuke help' for usage."

  # Act
  run nz_test_run shorten "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "an option before the command is refused with a hint" {
  # Arrange
  local expected="nazuke: a command comes first, such as name or rename, got '--max'. run 'nazuke help' for usage."

  # Act
  run nz_test_run --max 6 name "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "without a command and a terminal the usage hint is printed" {
  # Arrange
  local expected="nazuke: no command given. run 'nazuke help' for usage."

  # Act
  run nz_test_run </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "the menu runs the name job for choice 1" {
  # Arrange
  local answers=$'1\nGrand Theft Auto\n'

  # Act
  NAZUKE_INTERACTIVE=1 run nz_test_run <<<"${answers}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "What would you like to do?"* ]]
  [[ "${lines[${#lines[@]} - 1]}" == "Choice: Name to shorten: GRANDTA" ]]
}

@test "the menu runs the rename job for choice 2" {
  # Arrange
  local answers=$'2\n'

  # Act
  NAZUKE_INTERACTIVE=1 run from_folder "${TARGET}" nz_test_run <<<"${answers}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[${#lines[@]} - 1]}" == "Renamed 1 file." ]]
  [[ -e "${TARGET}/APPLEPR.TXT" ]]
}

@test "the menu refuses a choice it did not list" {
  # Arrange
  local answers=$'3\n'

  # Act
  NAZUKE_INTERACTIVE=1 run nz_test_run <<<"${answers}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"nazuke: not a listed choice: 3" ]]
}

@test "end of input at the menu stops the run" {
  # Arrange
  local empty=""

  # Act
  NAZUKE_INTERACTIVE=1 run nz_test_run < <(printf '%s' "${empty}")

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Choice: " ]]
}

@test "an unknown option is named with a hint" {
  # Arrange
  local expected="nazuke: unknown option '--fast'. run 'nazuke help' for usage."

  # Act
  run nz_test_run rename --fast "${TARGET}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "an unknown short option is named with a hint" {
  # Arrange
  local expected="nazuke: unknown option '-n'. run 'nazuke help' for usage."

  # Act
  run nz_test_run rename -n "${TARGET}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a rename-only option given to name is unknown there" {
  # Arrange
  local expected="nazuke: unknown option '--dry-run'. run 'nazuke help' for usage."

  # Act
  run nz_test_run name --dry-run "x"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a value given to --dry-run is refused" {
  # Arrange
  local expected="nazuke: option '--dry-run' takes no value. run 'nazuke help' for usage."

  # Act
  run nz_test_run rename --dry-run=yes "${TARGET}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "an unknown option written with a value is named without it" {
  # Arrange
  local expected="nazuke: unknown option '--fast'. run 'nazuke help' for usage."

  # Act
  run nz_test_run rename --fast=yes "${TARGET}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a second folder is refused" {
  # Arrange
  local expected="nazuke: unexpected extra argument 'more'. run 'nazuke help' for usage."

  # Act
  run nz_test_run rename "${TARGET}" more

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "an empty folder name is refused" {
  # Arrange
  local expected="nazuke: the folder name is empty. run 'nazuke help' for usage."

  # Act
  run nz_test_run rename ""

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "-- ends the options so a folder may start with a dash" {
  # Arrange
  nz_test_files "${WORK}/-named" "Melon Smoothie.txt"

  # Act
  run nz_test_run rename --dry-run -- "${WORK}/-named"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Melon Smoothie.txt -> MELONS.TXT"* ]]
}

@test "a missing folder is an error" {
  # Arrange
  local missing="${WORK}/nowhere"

  # Act
  run nz_test_run rename "${missing}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "nazuke: no such folder: ${missing}" ]]
}

@test "a file given as the folder is an error" {
  # Arrange
  local file="${TARGET}/Apple Pie Recipe.txt"

  # Act
  run nz_test_run rename "${file}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "nazuke: not a folder: ${file}" ]]
}

@test "a folder that cannot be entered is an error" {
  # Arrange
  [[ "$(id -u || true)" -ne 0 ]] || skip "root enters every folder"
  mkdir "${WORK}/locked"
  chmod 000 "${WORK}/locked"

  # Act
  run nz_test_run rename "${WORK}/locked"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "nazuke: cannot open the folder: ${WORK}/locked" ]]
}

@test "without a folder and a terminal the current folder is renamed" {
  # Arrange
  local expected="Folder: ${TARGET}"

  # Act
  run from_folder "${TARGET}" nz_test_run rename --dry-run </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"${expected}"* ]]
}

@test "in a terminal the folder is asked for" {
  # Arrange
  local answer="${TARGET}"

  # Act
  NAZUKE_INTERACTIVE=1 run nz_test_run rename --dry-run <<<"${answer}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "Folder whose files get short names ["*"]: "* ]]
  [[ "${output}" == *"Apple Pie Recipe.txt -> APPLEPR.TXT"* ]]
}

@test "Enter at the prompt renames in the current folder" {
  # Arrange
  local answer=""

  # Act
  NAZUKE_INTERACTIVE=1 run from_folder "${TARGET}" nz_test_run rename --dry-run <<<"${answer}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "Folder whose files get short names [${TARGET}]: "* ]]
  [[ "${output}" == *"Folder: ${TARGET}"* ]]
}

@test "a folder typed with a tilde starts at home" {
  # Arrange
  # shellcheck disable=SC2088
  local answer="~/target"

  # Act
  NAZUKE_INTERACTIVE=1 HOME="${WORK}" run nz_test_run rename --dry-run <<<"${answer}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Folder: ${TARGET}"* ]]
}

@test "a lone tilde is home itself" {
  # Arrange
  local answer="~"

  # Act
  NAZUKE_INTERACTIVE=1 HOME="${TARGET}" run nz_test_run rename --dry-run <<<"${answer}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Folder: ${TARGET}"* ]]
}

@test "end of input at the folder prompt stops the run" {
  # Arrange
  local empty=""

  # Act
  NAZUKE_INTERACTIVE=1 run nz_test_run rename < <(printf '%s' "${empty}")

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "Folder whose files get short names ["*"]: " ]]
}

help_options() {
  local page
  page="$(nz_test_run help)" || return 1
  awk '/^  --/ { for (i = 1; i <= NF; i++) if (match($i, /^--[a-z0-9][a-z0-9-]*/)) { name = substr($i, RSTART, RLENGTH); if (!seen[name]++) print name } }' <<<"${page}"
}

option_drift() {
  local option name man_form missing="" listed completed
  listed="$(help_options)" || return 1
  completed="$(grep -oE -- "--[a-z0-9][a-z0-9-]*" "${REPO_DIR}/completions/nazuke.bash")" || return 1
  for option in ${listed}; do
    name="${option#--}"
    man_form="\\-\\-${name//-/\\-}"
    grep -qF -- "${man_form}" "${REPO_DIR}/man/nazuke.1" || missing="${missing} man:${option}"
    grep -qE -- "(^|[ \"])${option}( |\"|$)" "${REPO_DIR}/completions/nazuke.bash" || missing="${missing} bash:${option}"
    grep -qE -- "[')]${option}\\[" "${REPO_DIR}/completions/_nazuke" || missing="${missing} zsh:${option}"
    grep -qE -- "-l ${name} " "${REPO_DIR}/completions/nazuke.fish" || missing="${missing} fish:${option}"
  done
  for option in ${completed}; do
    grep -qx -- "${option}" <<<"${listed}" || missing="${missing} help:${option}"
  done
  printf '%s' "${missing}"
}

@test "help, man page and completions list the same options" {
  # Arrange
  local expected=""

  # Act
  run option_drift

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "the man page passes mandoc lint" {
  # Arrange
  local page="${REPO_DIR}/man/nazuke.1"

  # Act
  run mandoc -T lint "${page}"

  # Assert
  [[ "${status}" -eq 0 ]]
}
