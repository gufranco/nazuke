#!/usr/bin/env bats
# shellcheck disable=SC2016

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/nz-rename.XXXXXX")"
  WORK="$(cd "${WORK}" && pwd -P)"
  TARGET="${WORK}/target"
  mkdir -p "${TARGET}"
}

teardown() {
  rm -rf "${WORK}"
}

listing() {
  nz_test_tree "${TARGET}"
}

@test "every file gets a short name and keeps its extension" {
  # Arrange
  nz_test_files "${TARGET}" "Grand Theft Auto.txt" "Apple Pie Recipe.txt"
  local expected
  expected="$(printf '%s\n' ./APPLEPR.TXT ./GRANDTA.TXT)"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "${expected}" ]]
  [[ "${lines[${#lines[@]} - 1]}" == "Renamed 2 files." ]]
}

@test "the summary and every rename are printed before the result" {
  # Arrange
  nz_test_files "${TARGET}" "Grand Theft Auto.txt" "README"
  local expected
  expected="$(printf '\nFolder: %s\nPlan:   rename 1 file to a name of up to 8 characters\n        keep 1 file whose name is already short\nWords:  generic\n\nGrand Theft Auto.txt -> GRANDTA.TXT\nRenamed 1 file.' "${TARGET}")"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a dry run lists every rename and changes nothing" {
  # Arrange
  nz_test_files "${TARGET}" "Grand Theft Auto.txt"

  # Act
  run nz_test_run rename --dry-run "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"dry run: list each rename and change nothing"* ]]
  [[ "${output}" == *"Grand Theft Auto.txt -> GRANDTA.TXT"* ]]
  [[ "${lines[${#lines[@]} - 1]}" == "Dry run: 1 file would get a short name. Nothing was renamed." ]]
  [[ -f "${TARGET}/Grand Theft Auto.txt" ]]
}

@test "a second run finds nothing left to rename" {
  # Arrange
  nz_test_files "${TARGET}" "Grand Theft Auto.txt" "Apple Pie Recipe.txt"
  nz_test_run rename "${TARGET}" >/dev/null

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "Nothing to rename: every file in ${TARGET} already has a short name." ]]
}

@test "an empty folder has nothing to rename" {
  # Arrange
  local expected="Nothing to rename in ${TARGET}."

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "titles from different regions get their region letter" {
  # Arrange
  nz_test_files "${TARGET}" "Pokemon Snap (USA).z64" "Pokemon Snap (Europe).z64" "Pokemon Snap (Japan).z64"
  local expected
  expected="$(printf '%s\n' ./POKSNAPE.Z64 ./POKSNAPJ.Z64 ./POKSNAPU.Z64)"

  # Act
  run nz_test_run rename --words games "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "${expected}" ]]
}

@test "a collision without a region tag is numbered" {
  # Arrange
  nz_test_files "${TARGET}" "Report (draft).txt" "Report (final).txt"
  local expected
  expected="$(printf '%s\n' ./REPORT.TXT ./REPORT1.TXT)"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "${expected}" ]]
}

@test "the same name with two extensions needs no number" {
  # Arrange
  nz_test_files "${TARGET}" "Report.txt" "Report.pdf"
  local expected
  expected="$(printf '%s\n' ./REPORT.PDF ./REPORT.TXT)"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "${expected}" ]]
}

@test "a name already taken by a short file is not reused" {
  # Arrange
  nz_test_files "${TARGET}" "GRANDTA.TXT" "Grand Theft Auto.txt"
  local expected
  expected="$(printf '%s\n' ./GRANDTA.TXT ./GRANDTA1.TXT)"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "${expected}" ]]
}

@test "a subfolder's name in another case is not reused" {
  # Arrange
  mkdir "${TARGET}/grandta"
  nz_test_files "${TARGET}" "Grand Theft Auto"
  local expected
  expected="$(printf '%s\n' ./GRANDTA1 ./grandta)"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "${expected}" ]]
}

@test "a device name such as CON is never given" {
  # Arrange
  nz_test_files "${TARGET}" "con.txt"
  local expected
  expected="$(printf '%s\n' ./CON1.TXT)"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "${expected}" ]]
}

@test "a short name in capitals that is a device name is renamed" {
  # Arrange
  nz_test_files "${TARGET}" "LPT1"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ -f "${TARGET}/LPT11" ]]
}

@test "a long extension is shortened, from the table when it knows one" {
  # Arrange
  nz_test_files "${TARGET}" "notes.docx" "photo.JPEG" "page.html"
  local expected
  expected="$(printf '%s\n' ./NOTES.DOC ./PAGE.HTM ./PHOTO.JPG)"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "${expected}" ]]
}

@test "--ext keeps an extension up to its length" {
  # Arrange
  nz_test_files "${TARGET}" "notes.docx"

  # Act
  run nz_test_run rename --ext 4 "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ -f "${TARGET}/NOTES.DOCX" ]]
}

@test "digits after the last dot are part of the name, not an extension" {
  # Arrange
  nz_test_files "${TARGET}" "Colin McRae Rally 2.0"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ -f "${TARGET}/CMR20" ]]
}

@test "text after the last dot with a space is part of the name" {
  # Arrange
  nz_test_files "${TARGET}" "Mozart Op. 125 final"

  # Act
  run nz_test_run rename --dry-run "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Mozart Op. 125 final -> MOF125"$'\n'* ]]
}

@test "a dot followed by too many letters is not an extension" {
  # Arrange
  nz_test_files "${TARGET}" "Quarterly.Presentation"

  # Act
  run nz_test_run rename --dry-run "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Quarterly.Presentation -> QUARTERP"$'\n'* ]]
}

@test "hidden files and subfolders keep their names" {
  # Arrange
  nz_test_files "${TARGET}" ".Hidden Settings" "Grand Theft Auto"
  mkdir "${TARGET}/Sub Folder"
  local expected
  expected="$(printf '%s\n' "./.Hidden Settings" ./GRANDTA "./Sub Folder")"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "${expected}" ]]
}

@test "a symbolic link is renamed itself, not its target" {
  # Arrange
  mkdir "${WORK}/elsewhere"
  ln -s "${WORK}/elsewhere" "${TARGET}/Grand Theft Auto"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ -L "${TARGET}/GRANDTA" ]]
  [[ -d "${WORK}/elsewhere" ]]
}

@test "a name with a line break is renamed" {
  # Arrange
  local odd=$'Grand\nTheft Auto.txt'
  printf 'x\n' >"${TARGET}/${odd}"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ -f "${TARGET}/GRANDTA.TXT" ]]
}

@test "a name that only changes case is renamed" {
  # Arrange
  nz_test_files "${TARGET}" "grandta.txt"
  local expected
  expected="$(printf '%s\n' ./GRANDTA.TXT)"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "${expected}" ]]
}

@test "a file's content goes with its new name" {
  # Arrange
  printf 'the content\n' >"${TARGET}/Grand Theft Auto.txt"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(cat "${TARGET}/GRANDTA.TXT" || true)" == "the content" ]]
}

@test "a temporary name in the way keeps the file's name" {
  # Arrange
  nz_test_files "${TARGET}" "Grand Theft Auto"
  : >"${TARGET}/.nazuke-1"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"nazuke: .nazuke-1 is in the way, so Grand Theft Auto keeps its name."* ]]
  [[ "${lines[${#lines[@]} - 1]}" == "Nothing was renamed: every file kept its name." ]]
  [[ -f "${TARGET}/Grand Theft Auto" ]]
}

@test "a failed first move names the file and what mv said" {
  # Arrange
  nz_test_files "${TARGET}" "Grand Theft Auto"
  nz_test_shim mv 'echo "mv: permission denied" >&2; exit 1'

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"nazuke: could not rename Grand Theft Auto."* ]]
  [[ "${output}" == *"nazuke: mv said: mv: permission denied"* ]]
  [[ -f "${TARGET}/Grand Theft Auto" ]]
}

@test "a failed second move puts the file back" {
  # Arrange
  nz_test_files "${TARGET}" "Grand Theft Auto"
  nz_test_shim mv 'if [ "$3" = GRANDTA ]; then echo "mv: disk full" >&2; exit 1; fi; exec "${REAL}" "$@"'

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"nazuke: could not rename Grand Theft Auto to GRANDTA."* ]]
  [[ "${output}" == *"nazuke: mv said: mv: disk full"* ]]
  [[ -f "${TARGET}/Grand Theft Auto" ]]
  [[ ! -e "${TARGET}/.nazuke-1" ]]
}

@test "a name that appears during the run is never overwritten" {
  # Arrange
  nz_test_files "${TARGET}" "Grand Theft Auto"
  nz_test_shim mv 'if [ "$3" = .nazuke-1 ]; then echo other >GRANDTA; fi; exec "${REAL}" "$@"'

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"nazuke: GRANDTA appeared while nazuke ran, so Grand Theft Auto keeps its name."* ]]
  [[ "$(cat "${TARGET}/GRANDTA" || true)" == "other" ]]
  [[ -f "${TARGET}/Grand Theft Auto" ]]
}

@test "an interrupt puts back every name the run changed" {
  # Arrange
  nz_test_files "${TARGET}" "Apple Pie Recipe" "Grand Theft Auto"
  local shim
  shim="$(cat "${NAZUKE_TESTS_DIR}/interrupt-mv.sh")"
  nz_test_shim mv "${shim}"
  local expected
  expected="$(printf '%s\n' "./Apple Pie Recipe" "./Grand Theft Auto")"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 130 ]]
  [[ "$(listing || true)" == "${expected}" ]]
}

@test "the counter goes past 999 while the name has room" {
  # Arrange
  local index=1
  : >"${TARGET}/REPORT.TXT"
  while [[ "${index}" -le 999 ]]; do
    if [[ "${index}" -lt 100 ]]; then
      : >"${TARGET}/REPORT${index}.TXT"
    else
      : >"${TARGET}/REPOR${index}.TXT"
    fi
    index=$((index + 1))
  done
  nz_test_files "${TARGET}" "Report (final).txt"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ -f "${TARGET}/REPO1000.TXT" ]]
  [[ ! -e "${TARGET}/Report (final).txt" ]]
}

@test "a name that no counter can free is reported" {
  # Arrange
  local index=1
  : >"${TARGET}/REPO.TXT"
  : >"${TARGET}/REP.TXT"
  while [[ "${index}" -le 999 ]]; do
    if [[ "${index}" -lt 10 ]]; then
      : >"${TARGET}/REP${index}.TXT"
    elif [[ "${index}" -lt 100 ]]; then
      : >"${TARGET}/RE${index}.TXT"
    else
      : >"${TARGET}/R${index}.TXT"
    fi
    index=$((index + 1))
  done
  nz_test_files "${TARGET}" "Report (final).txt"

  # Act
  run nz_test_run rename --max 4 "${TARGET}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"nazuke: no short name is left for Report (final).txt, so it keeps its name."* ]]
  [[ -f "${TARGET}/Report (final).txt" ]]
}

@test "discs of one game get their own numbers instead of a counter" {
  # Arrange
  nz_test_files "${TARGET}" "Final Fantasy VII (USA) (Disc 1).cue" "Final Fantasy VII (USA) (Disc 2).cue"
  local first second

  # Act
  run nz_test_run rename --words games "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  first="$(cd "${TARGET}" && ls -- *1.CUE)"
  second="$(cd "${TARGET}" && ls -- *2.CUE)"
  [[ "${first%1.CUE}" == "${second%2.CUE}" ]]
}

@test "a head shared by three or more files of the folder is dropped" {
  # Arrange
  nz_test_files "${TARGET}" "HBMAME (v0.209) - mslughp08.zip" "HBMAME (v0.209) - mslughp02.zip" "HBMAME (v0.245) - kof96ryu.zip"
  local expected
  expected="$(printf '%s\n' ./KOF96RYU.ZIP ./MSLUGH02.ZIP ./MSLUGH08.ZIP)"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "${expected}" ]]
}

@test "a head shared by only two files of the folder is kept" {
  # Arrange
  nz_test_files "${TARGET}" "Mario Kart - Double Dash.txt" "Mario Kart - Super Circuit.txt"
  local expected
  expected="$(printf '%s\n' ./MARKARDD.TXT ./MARKARSC.TXT)"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "${expected}" ]]
}

@test "--json prints the counts and every rename" {
  # Arrange
  nz_test_files "${TARGET}" "Grand Theft Auto.txt" "README"
  local expected
  expected="$(printf '{"folder":"%s","dry_run":false,"max":8,"ext":3,"words":"generic","files":2,"renamed":1,"kept":1,"failed":0,"renames":[{"from":"Grand Theft Auto.txt","to":"GRANDTA.TXT"}]}' "${TARGET}")"

  # Act
  run nz_test_run rename --json "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${expected}" ]]
  [[ -f "${TARGET}/GRANDTA.TXT" ]]
}

@test "--json with nothing to rename prints an empty list" {
  # Arrange
  nz_test_files "${TARGET}" "README"
  local expected
  expected="$(printf '{"folder":"%s","dry_run":true,"max":8,"ext":3,"words":"generic","files":1,"renamed":0,"kept":1,"failed":0,"renames":[]}' "${TARGET}")"

  # Act
  run nz_test_run rename --json --dry-run "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "an extension is written in capitals, so the name is a valid 8.3 name" {
  # Arrange
  nz_test_files "${TARGET}" "Super Mario 64 (USA).z64"

  # Act
  run nz_test_run rename --words games "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "./MARIO64.Z64" ]]
}

@test "a short name with a lower case extension gets it in capitals" {
  # Arrange
  nz_test_files "${TARGET}" "MARIO64.z64"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "./MARIO64.Z64" ]]
}

@test "a NES unif extension becomes UNF" {
  # Arrange
  nz_test_files "${TARGET}" "Some Cart (USA).unif"

  # Act
  run nz_test_run rename --words games "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "./SOMECART.UNF" ]]
}

@test "a file already named after its short name keeps it ahead of a newcomer" {
  # Arrange
  nz_test_files "${TARGET}" "Mario 64 (USA).z64" "MARIO64.z64"
  local expected
  expected="$(printf '%s\n' ./MARIO64.Z64 ./MARIO64U.Z64)"

  # Act
  run nz_test_run rename --words games "${TARGET}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(listing || true)" == "${expected}" ]]
  [[ "${output}" == *"Mario 64 (USA).z64 -> MARIO64U.Z64"* ]]
}

@test "an interrupt while files are set aside puts them back" {
  # Arrange
  nz_test_files "${TARGET}" "Apple Pie Recipe" "Grand Theft Auto"
  local shim
  shim="$(sed 's/"\$3" = GRANDTA/"$3" = .nazuke-2/' "${NAZUKE_TESTS_DIR}/interrupt-mv.sh")"
  nz_test_shim mv "${shim}"
  local expected
  expected="$(printf '%s\n' "./Apple Pie Recipe" "./Grand Theft Auto")"

  # Act
  run nz_test_run rename "${TARGET}"

  # Assert
  [[ "${status}" -eq 130 ]]
  [[ "$(listing || true)" == "${expected}" ]]
}
