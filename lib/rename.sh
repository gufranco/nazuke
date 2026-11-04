#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${NZ_LIB:?}/state.sh"

nz_choose_folder() {
  [ -z "${NZ_DIR}" ] || return 0
  if ! nz_interactive; then
    NZ_DIR=.
    return 0
  fi
  nz_cf_here="$(pwd -P)"
  if nz_ui_prompts; then
    nz_ui_header
  fi
  NZ_DIR="$(nz_prompt "Folder whose files get short names" "${nz_cf_here}")" || return 1
}

nz_open_folder() {
  case "${NZ_DIR}" in
  \~) NZ_DIR="${HOME}" ;;
  \~/*) NZ_DIR="${HOME}/${NZ_DIR#\~/}" ;;
  *) ;;
  esac
  if [ ! -e "${NZ_DIR}" ]; then
    nz_error "no such folder: ${NZ_DIR}"
    return 1
  fi
  if [ ! -d "${NZ_DIR}" ]; then
    nz_error "not a folder: ${NZ_DIR}"
    return 1
  fi
  if ! cd -- "${NZ_DIR}" 2>/dev/null; then
    nz_error "cannot open the folder: ${NZ_DIR}"
    return 1
  fi
  NZ_DIR="$(pwd -P)"
}

nz_split_name() {
  NZ_STEM="$1"
  NZ_DOT_EXT=""
  case "$1" in
  ?*.*) ;;
  *) return 0 ;;
  esac
  nz_sn_ext="${1##*.}"
  case "${nz_sn_ext}" in
  '' | *[!A-Za-z0-9]*) return 0 ;;
  *[A-Za-z]*) ;;
  *) return 0 ;;
  esac
  [ "${#nz_sn_ext}" -le 8 ] || return 0
  NZ_STEM="${1%.*}"
  NZ_DOT_EXT="${nz_sn_ext}"
}

nz_short_already() {
  case "${NZ_STEM}" in
  '' | *[!A-Z0-9]* | CON | PRN | AUX | NUL | COM[1-9] | LPT[1-9]) return 1 ;;
  *) ;;
  esac
  case "${NZ_DOT_EXT}" in
  *[!A-Z0-9]*) return 1 ;;
  *) ;;
  esac
  [ "${#NZ_STEM}" -le "${NZ_MAX}" ] && [ "${#NZ_DOT_EXT}" -le "${NZ_EXT}" ]
}

nz_entry() {
  nz_en_name="$1"
  case "${nz_en_name}" in
  .*) nz_en_kind=taken ;;
  *) nz_en_kind='file' ;;
  esac
  if [ ! -L "${nz_en_name}" ] && [ ! -f "${nz_en_name}" ]; then
    nz_en_kind=taken
  fi
  nz_one_line "${nz_en_name}"
  if [ "${nz_en_kind}" = taken ]; then
    printf '0\ttaken\t%s\t\n' "${NZ_ONE_LINE}"
    return 0
  fi
  NZ_FOUND=$((NZ_FOUND + 1))
  nz_split_name "${nz_en_name}"
  if nz_short_already; then
    NZ_KEPT=$((NZ_KEPT + 1))
    printf '0\ttaken\t%s\t\n' "${NZ_ONE_LINE}"
    return 0
  fi
  NZ_ENTRIES=$((NZ_ENTRIES + 1))
  nz_set "nz_src_${NZ_ENTRIES}" "${nz_en_name}"
  nz_one_line "${NZ_STEM}"
  printf '%s\tfree\t%s\t%s\n' "${NZ_ENTRIES}" "${NZ_ONE_LINE}" "${NZ_DOT_EXT}"
}

nz_scan() {
  for nz_sc_name in * .[!.]* ..?*; do
    [ -e "${nz_sc_name}" ] || [ -L "${nz_sc_name}" ] || continue
    nz_entry "${nz_sc_name}"
  done
}

nz_plan() {
  NZ_PLAN=""
  while IFS=/ read -r nz_pl_key nz_pl_base nz_pl_ext; do
    nz_get "nz_src_${nz_pl_key}"
    case "${nz_pl_base}" in
    '' | *[!A-Z0-9]*)
      nz_error "no short name is left for ${NZ_GOT}, so it keeps its name."
      NZ_FAILED=$((NZ_FAILED + 1))
      continue
      ;;
    *) ;;
    esac
    nz_set "nz_dst_${nz_pl_key}" "${nz_pl_base}${nz_pl_ext:+.${nz_pl_ext}}"
    NZ_PLAN="${NZ_PLAN} ${nz_pl_key}"
    NZ_PLANNED=$((NZ_PLANNED + 1))
  done <"$1"
}

nz_pair() {
  nz_get "nz_src_$1"
  NZ_SRC="${NZ_GOT}"
  nz_get "nz_dst_$1"
  NZ_DST="${NZ_GOT}"
}

nz_summary() {
  nz_su_files="$(nz_plural "${NZ_PLANNED}" file)"
  nz_su_kept="$(nz_plural "${NZ_KEPT}" file)"
  nz_su_plan="rename ${nz_su_files} to a name of up to ${NZ_MAX} characters"
  if nz_ui_out; then
    nz_summary_drawn "${nz_su_plan}" "${nz_su_kept} already short" "${nz_su_files}"
    return
  fi
  printf '\n'
  nz_say "Folder: ${NZ_DIR}"
  nz_say "Plan:   ${nz_su_plan}"
  nz_say "        keep ${nz_su_kept} whose name is already short"
  if [ "${NZ_DRY_RUN}" = yes ]; then
    printf '        dry run: list each rename and change nothing\n'
  fi
  nz_say "Words:  ${NZ_WORDS}"
  printf '\n'
  nz_show
}

nz_summary_drawn() {
  nz_sd_mode="files are renamed"
  [ "${NZ_DRY_RUN}" = no ] || nz_sd_mode="dry run, nothing is renamed"
  nz_ui_summary "Folder:" "${NZ_DIR}" "Plan:" "$1" "Kept:" "$2" "Words:" "${NZ_WORDS}" "Mode:" "${nz_sd_mode}"
  nz_show_drawn
  if [ "${NZ_DRY_RUN}" = yes ] || ! nz_ui_prompts; then
    return 0
  fi
  if ! nz_ui_confirm "Rename $3?" "Rename" "Stop"; then
    nz_error "stopped: nothing was renamed."
    return 1
  fi
}

nz_show() {
  for nz_sw_key in ${NZ_PLAN}; do
    nz_pair "${nz_sw_key}"
    nz_say "${NZ_SRC} -> ${NZ_DST}"
  done
}

nz_show_drawn() {
  {
    printf 'Name\tShort name\n'
    for nz_sh_key in ${NZ_PLAN}; do
      nz_pair "${nz_sh_key}"
      nz_one_line "${NZ_SRC}"
      printf '%s\t@acc:%s\n' "${NZ_ONE_LINE}" "${NZ_DST}"
    done
  } | nz_ui_table
}
