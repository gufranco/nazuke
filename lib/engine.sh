#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${NZ_LIB:?}/state.sh"

nz_number_in() {
  case "$1" in
  '' | *[!0-9]* | 0*) return 1 ;;
  *) ;;
  esac
  [ "${#1}" -le 3 ] && [ "$1" -ge "$2" ] && [ "$1" -le "$3" ]
}

nz_setting_number() {
  nz_number_in "$2" "$3" "$4" && return 0
  nz_error "$1 must be a whole number from $3 to $4, got: $2"
  return 1
}

nz_settings_defaults() {
  if [ -z "${NZ_MAX_FROM}" ]; then
    NZ_MAX="${NAZUKE_MAX:-8}"
    NZ_MAX_FROM=NAZUKE_MAX
  fi
  if [ -z "${NZ_EXT_FROM}" ]; then
    NZ_EXT="${NAZUKE_EXT:-3}"
    NZ_EXT_FROM=NAZUKE_EXT
  fi
  if [ -z "${NZ_WORDS_FROM}" ]; then
    NZ_WORDS="${NAZUKE_WORDS:-generic}"
    NZ_WORDS_FROM=NAZUKE_WORDS
  fi
}

nz_settings() {
  nz_settings_defaults
  nz_setting_number "${NZ_MAX_FROM}" "${NZ_MAX}" 4 255 || return 1
  nz_setting_number "${NZ_EXT_FROM}" "${NZ_EXT}" 1 255 || return 1
  nz_pack_resolve || return 1
  nz_pack_check
}

nz_pack_resolve() {
  case "${NZ_WORDS}" in
  generic | games) NZ_PACK="${NZ_SHARE}/words/${NZ_WORDS}" ;;
  */*) NZ_PACK="${NZ_WORDS}" ;;
  *)
    nz_error "${NZ_WORDS_FROM} must be generic, games or the path of a word pack, got: ${NZ_WORDS}"
    return 1
    ;;
  esac
  [ -f "${NZ_PACK}" ] && [ -r "${NZ_PACK}" ] && return 0
  nz_error "cannot read the word pack: ${NZ_PACK}"
  return 1
}

nz_pack_check() {
  nz_pc_problem="$(nz_engine check </dev/null)" && return 0
  nz_pc_line="${nz_pc_problem%%"	"*}"
  nz_pc_reason="$(printf '%s\n' "${nz_pc_problem#*"	"}" | sed -n '1p')"
  nz_error "the word pack ${NZ_PACK} has a problem on line ${nz_pc_line}: ${nz_pc_reason}."
  return 1
}

nz_engine() {
  awk -v mode="$1" -v max="${NZ_MAX}" -v extmax="${NZ_EXT}" -v pack="${NZ_PACK}" \
    -v translit="${NZ_SHARE}/translit" -v extensions="${NZ_SHARE}/extensions" \
    -f "${NZ_LIB}/words.awk" -f "${NZ_LIB}/shorten.awk"
}

nz_one_line() {
  NZ_ONE_LINE="$1"
  nz_ol_newline='
'
  while :; do
    case "${NZ_ONE_LINE}" in
    *"${nz_ol_newline}"*) NZ_ONE_LINE="${NZ_ONE_LINE%%"${nz_ol_newline}"*} ${NZ_ONE_LINE#*"${nz_ol_newline}"}" ;;
    *"	"*) NZ_ONE_LINE="${NZ_ONE_LINE%%"	"*} ${NZ_ONE_LINE#*"	"}" ;;
    *) return 0 ;;
    esac
  done
}

nz_work() {
  [ -z "${NZ_WORK}" ] || return 0
  NZ_WORK="$(mktemp -d "${TMPDIR:-/tmp}/nazuke.XXXXXX")" || return 1
  trap 'nz_finish' EXIT
  trap 'nz_interrupted' INT TERM
}

nz_finish() {
  [ -z "${NZ_WORK}" ] || rm -rf "${NZ_WORK}"
}

nz_interrupted() {
  [ "${NZ_APPLYING}" = no ] || nz_restore
  nz_finish
  NZ_WORK=""
  exit 130
}
