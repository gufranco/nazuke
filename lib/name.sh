#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${NZ_LIB:?}/state.sh"

nz_name_ask() {
  [ "${NZ_TEXTS}" -eq 0 ] || return 0
  if ! nz_interactive; then
    nz_cli_hint "no name given"
    return 1
  fi
  nz_na_tries=0
  while [ "${nz_na_tries}" -lt 3 ]; do
    nz_na_tries=$((nz_na_tries + 1))
    nz_na_answer="$(nz_prompt "Name to shorten" "")" || return 1
    if [ -n "${nz_na_answer}" ]; then
      nz_args_positional "${nz_na_answer}"
      return 0
    fi
  done
  nz_error "stopped: no name was given."
  return 1
}

nz_name_input() {
  nz_ni_index=1
  while [ "${nz_ni_index}" -le "${NZ_TEXTS}" ]; do
    nz_get "nz_text_${nz_ni_index}"
    nz_one_line "${NZ_GOT}"
    printf '%s\t%s\n' "${nz_ni_index}" "${NZ_ONE_LINE}"
    nz_ni_index=$((nz_ni_index + 1))
  done
}

nz_name_json() {
  nz_nj_words="$(nz_json_string "${NZ_WORDS}")"
  printf '{"max":%s,"words":%s,"names":[' "${NZ_MAX}" "${nz_nj_words}"
  nz_nj_comma=""
  while IFS='	' read -r nz_nj_key nz_nj_name; do
    nz_get "nz_text_${nz_nj_key}"
    nz_nj_text="$(nz_json_string "${NZ_GOT}")"
    printf '%s{"text":%s,"name":"%s"}' "${nz_nj_comma}" "${nz_nj_text}" "${nz_nj_name}"
    nz_nj_comma=","
  done <"$1"
  printf ']}\n'
}

nz_name_drawn() {
  {
    printf 'Name\tShort name\n'
    while IFS='	' read -r nz_nd_key nz_nd_name; do
      nz_get "nz_text_${nz_nd_key}"
      nz_one_line "${NZ_GOT}"
      printf '%s\t@acc:%s\n' "${NZ_ONE_LINE}" "${nz_nd_name}"
    done <"$1"
  } | nz_ui_table
}

nz_name() {
  NZ_ARGS_WANT=texts
  nz_args_parse "$@" || return 1
  nz_settings || return 1
  nz_name_ask || return 1
  nz_work || return 1
  nz_name_input | nz_engine name >"${NZ_WORK}/names" || return 1
  if [ "${NZ_JSON}" = yes ]; then
    nz_name_json "${NZ_WORK}/names"
  elif nz_ui_out; then
    nz_name_drawn "${NZ_WORK}/names"
  else
    cut -f 2 "${NZ_WORK}/names"
  fi
}
