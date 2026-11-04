#!/usr/bin/env bash

NAZUKE_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${NAZUKE_TESTS_DIR}/.." && pwd)"
export NAZUKE_TESTS_DIR REPO_DIR
PATH="${NAZUKE_TESTS_DIR}/bin:${PATH}"
export PATH

nz_test_path() {
  if [[ -n "${SHIMS:-}" && -d "${SHIMS}" ]]; then
    printf '%s:%s\n' "${SHIMS}" "${PATH}"
  else
    printf '%s\n' "${PATH}"
  fi
}

nz_test_shim() {
  local name="$1"
  local body="$2"
  local real
  SHIMS="${SHIMS:-${WORK:?}/shims}"
  mkdir -p "${SHIMS}"
  real="$(command -v "${name}" || true)"
  printf '#!/bin/sh\n{ set +x; } 2>/dev/null\nREAL=%q\n%s\n' "${real}" "${body}" >"${SHIMS}/${name}"
  chmod +x "${SHIMS}/${name}"
  export SHIMS
}

nz_test_run() {
  local search_path
  local -a shell_words
  search_path="$(nz_test_path)"
  read -r -a shell_words <<<"${NAZUKE_TEST_SHELL:-sh}"
  PATH="${search_path}" "${shell_words[@]}" "${REPO_DIR}/bin/nazuke" "$@"
}

nz_test_run_path() {
  local search_path="$1"
  local -a shell_words
  shift
  read -r -a shell_words <<<"${NAZUKE_TEST_SHELL:-sh}"
  PATH="${search_path}" "${shell_words[@]}" "${REPO_DIR}/bin/nazuke" "$@"
}

nz_test_call() {
  local search_path
  local -a shell_words
  search_path="$(nz_test_path)"
  read -r -a shell_words <<<"${NAZUKE_TEST_SHELL:-sh}"
  PATH="${search_path}" "${shell_words[@]}" "${NAZUKE_TESTS_DIR}/call.sh" "$@"
}

nz_test_farm_wanted() {
  local farm="$1"
  local tool="$2"
  local name="${2##*/}"
  local excluded
  shift 2
  [[ -x "${tool}" && ! -e "${farm}/${name}" ]] || return 1
  for excluded in "$@"; do
    [[ "${name}" == "${excluded}" ]] && return 1
  done
  return 0
}

nz_test_farm() {
  local farm="${WORK:?}/farm"
  local dir tool
  local -a dirs batch
  mkdir -p "${farm}"
  IFS=: read -r -a dirs <<<"${PATH}"
  for dir in "${dirs[@]}"; do
    batch=()
    for tool in "${dir}"/*; do
      nz_test_farm_wanted "${farm}" "${tool}" "$@" && batch+=("${tool}")
    done
    [[ ${#batch[@]} -eq 0 ]] || ln -s "${batch[@]}" "${farm}/"
  done
  printf '%s\n' "${farm}"
}

nz_test_files() {
  local dir="$1"
  local name
  shift
  mkdir -p "${dir}"
  for name in "$@"; do
    printf '%s\n' "${name}" >"${dir}/${name}"
  done
}

nz_test_tree() {
  local listing
  listing="$(cd "$1" && find . -mindepth 1)" || return 1
  LC_ALL=C sort <<<"${listing}"
}

nz_test_matches_golden() {
  local name="$1"
  local actual="$2"
  local os golden normalized
  os="$(uname -s)"
  golden="${NAZUKE_TESTS_DIR}/golden/${name}.${os}.txt"
  normalized="${actual//"${WORK}"/WORK}"
  if [[ "${NAZUKE_TEST_RECORD:-}" == "1" ]]; then
    mkdir -p "${NAZUKE_TESTS_DIR}/golden"
    printf '%s\n' "${normalized}" >"${golden}"
  fi
  diff <(printf '%s\n' "${normalized}") "${golden}"
}
