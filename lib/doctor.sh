#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${NZ_LIB:?}/state.sh"

nz_doctor_row() {
  if nz_ui_out; then
    case "$2" in
    ok) nz_dw_state="@ok:ok" ;;
    *) nz_dw_state="@bad:$2" ;;
    esac
    NZ_DOCTOR_ROWS="${NZ_DOCTOR_ROWS}$1	${nz_dw_state}	$3
"
    return 0
  fi
  printf '%-18s %-8s %s\n' "$1" "$2" "$3"
}

nz_doctor_report() {
  if ! nz_ui_out; then
    return 0
  fi
  printf 'Tool\tState\tDetail\n%s' "${NZ_DOCTOR_ROWS}" | nz_ui_table
  if [ "$1" -ne 0 ]; then
    nz_ui_log ERROR "a required tool is missing. install it and run nazuke doctor again."
    return 0
  fi
  nz_ui_done "Ready. Every tool nazuke needs is here."
}

nz_doctor_gum() {
  nz_dg_found="$(command -v gum 2>/dev/null || true)"
  if [ -z "${nz_dg_found}" ]; then
    nz_doctor_row gum missing "install with: brew install gum, or see https://github.com/charmbracelet/gum"
    return 1
  fi
  nz_dg_version="$(nz_flavor_version "$(gum --version 2>/dev/null || true)")"
  nz_doctor_row gum ok "${nz_dg_found}${nz_dg_version:+, ${nz_dg_version}}"
}

nz_flavor_version() {
  printf '%s\n' "$1" | awk '{
    for (i = 1; i <= NF; i++) {
      t = $i
      gsub(/[,;()]/, "", t)
      sub(/^v/, "", t)
      if (t ~ /^[0-9]+(\.[0-9]+)+[a-z0-9]*$/ || t ~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/) { print t; exit }
    }
  }'
}

nz_tool_line() {
  nz_tl_line="$(printf '%s\n' "$1" | awk '/BusyBox|This is not GNU/ { print; exit }')"
  if [ -z "${nz_tl_line}" ]; then
    nz_tl_line="$(printf '%s\n' "$1" | sed -n '1p')"
  fi
  printf '%s\n' "${nz_tl_line}"
}

nz_tool_flavor() {
  nz_tf_raw="$("$1" --version 2>&1 </dev/null)" || true
  nz_tf_text="$(nz_tool_line "${nz_tf_raw}")"
  nz_tf_version="$(nz_flavor_version "${nz_tf_text}")"
  nz_tf_os="${NAZUKE_OS:-}"
  [ -n "${nz_tf_os}" ] || nz_tf_os="$(uname -s)"
  case "${nz_tf_text}" in
  *uutils*) nz_tf_name=uutils ;;
  *BusyBox*) nz_tf_name=busybox ;;
  *"This is not GNU"*)
    nz_tf_name=busybox
    nz_tf_version=""
    ;;
  *GNU* | *"(coreutils)"*) nz_tf_name=gnu ;;
  *)
    nz_tf_version=""
    case "$1:${nz_tf_os}" in
    *uutils*:* | */cargo/*:*) nz_tf_name=uutils ;;
    *:Darwin | *:*BSD) nz_tf_name=bsd ;;
    *) nz_tf_name=unknown ;;
    esac
    ;;
  esac
  printf '%s%s\n' "${nz_tf_name}" "${nz_tf_version:+ ${nz_tf_version}}"
}

nz_doctor_tool() {
  nz_dt_found="$(command -v "$1" 2>/dev/null || true)"
  if [ -z "${nz_dt_found}" ]; then
    nz_doctor_row "$1" missing "required, part of every Linux and macOS system"
    return 1
  fi
  nz_dt_flavor="$(nz_tool_flavor "${nz_dt_found}")"
  nz_doctor_row "$1" ok "${nz_dt_found}, ${nz_dt_flavor}"
}

nz_doctor() {
  nz_dr_status=0
  nz_doctor_gum || nz_dr_status=1
  nz_doctor_tool awk || nz_dr_status=1
  nz_doctor_tool mktemp || nz_dr_status=1
  nz_doctor_tool mv || nz_dr_status=1
  nz_doctor_report "${nz_dr_status}"
  return "${nz_dr_status}"
}
