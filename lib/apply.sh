#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${NZ_LIB:?}/state.sh"

nz_said() {
  printf '%s\n' "$2" | while IFS= read -r nz_sd_line; do
    [ -z "${nz_sd_line}" ] || nz_error "$1 said: ${nz_sd_line}"
  done
}

nz_aside() {
  nz_as_tmp=".nazuke-$1"
  if [ -e "${nz_as_tmp}" ] || [ -L "${nz_as_tmp}" ]; then
    nz_error "${nz_as_tmp} is in the way, so ${NZ_SRC} keeps its name."
    return 1
  fi
  NZ_ASIDE="${NZ_ASIDE} $1"
  nz_as_said="$(mv -- "${NZ_SRC}" "${nz_as_tmp}" 2>&1)" && return 0
  NZ_ASIDE="${NZ_ASIDE% "$1"}"
  nz_error "could not rename ${NZ_SRC}."
  nz_said mv "${nz_as_said}"
  return 1
}

nz_land() {
  nz_ld_tmp=".nazuke-$1"
  if [ -e "${NZ_DST}" ] || [ -L "${NZ_DST}" ]; then
    nz_error "${NZ_DST} appeared while nazuke ran, so ${NZ_SRC} keeps its name."
  elif nz_ld_said="$(mv -- "${nz_ld_tmp}" "${NZ_DST}" 2>&1)"; then
    NZ_RENAMED=$((NZ_RENAMED + 1))
    return 0
  else
    nz_error "could not rename ${NZ_SRC} to ${NZ_DST}."
    nz_said mv "${nz_ld_said}"
  fi
  mv -- "${nz_ld_tmp}" "${NZ_SRC}"
  return 1
}

nz_restore() {
  for nz_rs_key in ${NZ_ASIDE}; do
    nz_pair "${nz_rs_key}"
    if nz_present ".nazuke-${nz_rs_key}"; then
      mv -- ".nazuke-${nz_rs_key}" "${NZ_SRC}"
    elif nz_present "${NZ_DST}" && ! nz_present "${NZ_SRC}"; then
      mv -- "${NZ_DST}" "${NZ_SRC}"
    fi
  done
}

nz_present() {
  [ -e "$1" ] || [ -L "$1" ]
}

nz_apply() {
  NZ_ASIDE=""
  NZ_APPLYING=yes
  for nz_ap_key in ${NZ_PLAN}; do
    nz_pair "${nz_ap_key}"
    nz_aside "${nz_ap_key}" || NZ_FAILED=$((NZ_FAILED + 1))
  done
  for nz_ap_key in ${NZ_ASIDE}; do
    nz_pair "${nz_ap_key}"
    nz_land "${nz_ap_key}" || NZ_FAILED=$((NZ_FAILED + 1))
  done
  NZ_APPLYING=no
}

nz_report_json() {
  nz_rj_dry=false
  [ "${NZ_DRY_RUN}" = no ] || nz_rj_dry=true
  nz_rj_folder="$(nz_json_string "${NZ_DIR}")"
  nz_rj_words="$(nz_json_string "${NZ_WORDS}")"
  printf '{"folder":%s,"dry_run":%s,"max":%s,"ext":%s,"words":%s,"files":%s,"renamed":%s,"kept":%s,"failed":%s,"renames":[' \
    "${nz_rj_folder}" "${nz_rj_dry}" "${NZ_MAX}" "${NZ_EXT}" "${nz_rj_words}" \
    "${NZ_FOUND}" "${NZ_RENAMED}" "${NZ_KEPT}" "${NZ_FAILED}"
  nz_rj_comma=""
  for nz_rj_key in ${NZ_PLAN}; do
    nz_pair "${nz_rj_key}"
    nz_rj_from="$(nz_json_string "${NZ_SRC}")"
    nz_rj_to="$(nz_json_string "${NZ_DST}")"
    printf '%s{"from":%s,"to":%s}' "${nz_rj_comma}" "${nz_rj_from}" "${nz_rj_to}"
    nz_rj_comma=","
  done
  printf ']}\n'
}

nz_report_line() {
  nz_rl_files="$(nz_plural "${NZ_PLANNED}" file)"
  nz_rl_count="${nz_rl_files}"
  [ "${NZ_RENAMED}" -eq "${NZ_PLANNED}" ] || nz_rl_count="${NZ_RENAMED} of ${nz_rl_files}"
  if [ "${NZ_DRY_RUN}" = yes ]; then
    printf 'Dry run: %s would get a short name. Nothing was renamed.\n' "${nz_rl_files}"
  elif [ "${NZ_RENAMED}" -eq 0 ]; then
    printf 'Nothing was renamed: every file kept its name.\n'
  else
    printf 'Renamed %s.\n' "${nz_rl_count}"
  fi
}

nz_report() {
  if [ "${NZ_JSON}" = yes ]; then
    nz_report_json
  elif nz_ui_out; then
    nz_re_line="$(nz_report_line)"
    nz_ui_done "${nz_re_line}"
  else
    nz_report_line
  fi
  [ "${NZ_FAILED}" -eq 0 ]
}

nz_nothing() {
  if [ "${NZ_JSON}" = yes ]; then
    nz_report_json
  elif [ "${NZ_FOUND}" -eq 0 ]; then
    nz_say "Nothing to rename in ${NZ_DIR}."
  else
    nz_say "Nothing to rename: every file in ${NZ_DIR} already has a short name."
  fi
  [ "${NZ_FAILED}" -eq 0 ]
}

nz_rename() {
  NZ_ARGS_WANT=folder
  nz_args_parse "$@" || return 1
  nz_settings || return 1
  nz_choose_folder || return 1
  nz_open_folder || return 1
  nz_work || return 1
  nz_scan >"${NZ_WORK}/entries"
  nz_engine assign <"${NZ_WORK}/entries" >"${NZ_WORK}/plan" || return 1
  nz_plan "${NZ_WORK}/plan"
  [ "${NZ_PLANNED}" -gt 0 ] || nz_nothing || return 1
  [ "${NZ_PLANNED}" -gt 0 ] || return 0
  [ "${NZ_JSON}" = yes ] || nz_summary || return 1
  if [ "${NZ_DRY_RUN}" = yes ]; then
    NZ_RENAMED="${NZ_PLANNED}"
  else
    nz_apply
  fi
  nz_report
}
