#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${NZ_LIB:?}/state.sh"

nz_args_positional() {
  if [ "${NZ_ARGS_WANT}" = texts ]; then
    NZ_TEXTS=$((NZ_TEXTS + 1))
    nz_set "nz_text_${NZ_TEXTS}" "$1"
    return 0
  fi
  if [ -z "$1" ]; then
    nz_cli_hint "the folder name is empty"
    return 1
  fi
  if [ -n "${NZ_DIR}" ]; then
    nz_cli_hint "unexpected extra argument '$1'"
    return 1
  fi
  NZ_DIR="$1"
}

nz_args_kind() {
  case "${NZ_ARGS_WANT}:$1" in
  *:--max | *:--words | folder:--ext) NZ_ARGS_KIND=value ;;
  *:--json | folder:--dry-run) NZ_ARGS_KIND=flag ;;
  *)
    nz_cli_hint "unknown option '$1'"
    return 1
    ;;
  esac
}

nz_args_set() {
  case "$1" in
  --max) NZ_MAX="$2" NZ_MAX_FROM=--max ;;
  --ext) NZ_EXT="$2" NZ_EXT_FROM=--ext ;;
  --words) NZ_WORDS="$2" NZ_WORDS_FROM=--words ;;
  --json) NZ_JSON=yes ;;
  *) NZ_DRY_RUN=yes ;;
  esac
}

nz_args_joined() {
  nz_args_kind "${1%%=*}" || return 1
  if [ "${NZ_ARGS_KIND}" = flag ]; then
    nz_cli_hint "option '${1%%=*}' takes no value"
    return 1
  fi
  nz_args_set "${1%%=*}" "${1#*=}"
}

nz_args_needs() {
  [ "$2" -eq 0 ] || return 0
  nz_cli_hint "option '$1' needs a value"
  return 1
}

nz_args_parse() {
  NZ_ARGS_DONE=no
  while [ "$#" -gt 0 ]; do
    nz_ap_arg="$1"
    shift
    case "${NZ_ARGS_DONE}:${nz_ap_arg}" in
    yes:*) nz_args_positional "${nz_ap_arg}" || return 1 ;;
    no:--) NZ_ARGS_DONE=yes ;;
    no:--*=*) nz_args_joined "${nz_ap_arg}" || return 1 ;;
    no:-?*)
      nz_args_kind "${nz_ap_arg}" || return 1
      if [ "${NZ_ARGS_KIND}" = flag ]; then
        nz_args_set "${nz_ap_arg}"
        continue
      fi
      nz_args_needs "${nz_ap_arg}" "$#" || return 1
      nz_args_set "${nz_ap_arg}" "$1"
      shift
      ;;
    *) nz_args_positional "${nz_ap_arg}" || return 1 ;;
    esac
  done
}
