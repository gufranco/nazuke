#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${NZ_LIB:?}/state.sh"

# shellcheck disable=SC2034
nz_ui_set() {
  NZ_UI_ACCENT="$1"
  NZ_UI_OK="$2"
  NZ_UI_WARN="$3"
  NZ_UI_ERR="$4"
  NZ_UI_MUTED="$5"
  NZ_UI_TEXT="$6"
  NZ_UI_SURFACE="$7"
  NZ_UI_HELP="$8"
}

nz_ui_palette() {
  case "$1" in
  kodougu) nz_ui_set "#F25D94" "#50FA7B" "#FFB86C" "#FF5555" "#6C7086" "#CDD6F4" "#313244" pink ;;
  catppuccin-mocha) nz_ui_set "#CBA6F7" "#A6E3A1" "#FAB387" "#F38BA8" "#6C7086" "#CDD6F4" "#313244" dark ;;
  catppuccin-latte) nz_ui_set "#8839EF" "#40A02B" "#FE640B" "#D20F39" "#8C8FA1" "#4C4F69" "#CCD0DA" light ;;
  dracula) nz_ui_set "#BD93F9" "#50FA7B" "#FFB86C" "#FF5555" "#6272A4" "#F8F8F2" "#44475A" dracula ;;
  nord) nz_ui_set "#88C0D0" "#A3BE8C" "#EBCB8B" "#BF616A" "#4C566A" "#D8DEE9" "#3B4252" dark ;;
  gruvbox) nz_ui_set "#FE8019" "#B8BB26" "#FABD2F" "#FB4934" "#928374" "#EBDBB2" "#3C3836" dark ;;
  tokyo-night) nz_ui_set "#7AA2F7" "#9ECE6A" "#E0AF68" "#F7768E" "#565F89" "#C0CAF5" "#292E42" tokyo-night ;;
  mono) nz_ui_set "" "" "" "" "" "" "" ascii ;;
  *) return 1 ;;
  esac
}

nz_ui_is_colour() {
  case "$1" in
  \#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) return 0 ;;
  *) return 1 ;;
  esac
}

# shellcheck disable=SC2034
nz_ui_setup() {
  if ! nz_ui_palette "${NZ_THEME}"; then
    nz_ui_palette mono
    NZ_UI_PROBLEM="--theme must be one of ${NZ_UI_THEMES}, got: ${NZ_THEME}"
    return 1
  fi
  if [ -n "${NZ_ACCENT}" ] && ! nz_ui_is_colour "${NZ_ACCENT}"; then
    NZ_UI_PROBLEM="KODOUGU_ACCENT must be a colour such as #CBA6F7, got: ${NZ_ACCENT}"
    return 1
  fi
  if [ -n "${NZ_ACCENT}" ]; then
    NZ_UI_ACCENT="${NZ_ACCENT}"
  fi
  if [ -n "${NO_COLOR:-}" ]; then
    nz_ui_palette mono
  fi
}

nz_ui_forced() {
  [ "${NAZUKE_TEST_GUM:-}" = 1 ]
}

nz_ui_has_gum() {
  command -v gum >/dev/null 2>&1
}

nz_ui_prompts() {
  nz_ui_forced && return 0
  [ -t 0 ] && [ -t 2 ] && nz_ui_has_gum
}

nz_ui_err() {
  nz_ui_forced && return 0
  [ "${NZ_UI_STEP}" = 1 ] && return 0
  [ -t 2 ] && nz_ui_has_gum
}

nz_ui_out() {
  nz_ui_forced && return 0
  [ -t 1 ] && nz_ui_has_gum
}

nz_gum() {
  if [ -n "${NZ_UI_TEXT}" ]; then
    CLICOLOR_FORCE=1 gum "$@"
    return
  fi
  gum "$@"
}

nz_ui_ink() {
  nz_ui_colour="$1"
  shift
  if [ -z "${nz_ui_colour}" ]; then
    nz_gum style "$@"
    return
  fi
  nz_gum style --foreground "${nz_ui_colour}" "$@"
}

nz_ui_header() {
  nz_uh_name=$(nz_ui_ink "${NZ_UI_ACCENT}" --bold -- "nazuke")
  nz_uh_number=$(nz_version | sed -n '1p')
  nz_uh_number="${nz_uh_number#nazuke }"
  nz_uh_version=$(nz_ui_ink "${NZ_UI_MUTED}" -- "${nz_uh_number}")
  nz_uh_tagline=$(nz_ui_ink "${NZ_UI_TEXT}" -- "${NZ_TAGLINE}")
  nz_uh_top=$(nz_gum join --horizontal "${nz_uh_name}" "  " "${nz_uh_version}")
  nz_uh_body=$(nz_gum join --vertical "${nz_uh_top}" "${nz_uh_tagline}")
  printf '\n' >&2
  nz_gum style --border rounded --border-foreground "${NZ_UI_ACCENT}" --padding "0 2" -- "${nz_uh_body}" >&2
  printf '\n' >&2
}

nz_ui_title() {
  printf '\n' >&2
  nz_ui_ink "${NZ_UI_ACCENT}" --bold -- "$1" >&2
  printf '\n' >&2
}

nz_ui_titled() {
  if nz_ui_prompts; then
    nz_ui_title "$1"
  fi
}

nz_ui_lower_first() {
  printf '%s\n' "$1" | awk 'NR == 1 { a = substr($0, 1, 1); b = substr($0, 2, 1); if (a != tolower(a) && b != toupper(b)) { $0 = tolower(a) substr($0, 2) } } { print }'
}

nz_ui_log() {
  nz_ul_level="$1"
  nz_ul_text=$(nz_ui_lower_first "$2")
  case "${nz_ul_level}" in
  ERROR) nz_ul_colour="${NZ_UI_ERR}" ;;
  WARN) nz_ul_colour="${NZ_UI_WARN}" ;;
  *) nz_ul_colour="${NZ_UI_OK}" ;;
  esac
  nz_ul_label=$(nz_ui_ink "${nz_ul_colour}" --bold -- "${nz_ul_level}")
  printf '%s nazuke: %s\n' "${nz_ul_label}" "${nz_ul_text}" >&2
}

nz_ui_choose() {
  nz_uc_header="$1"
  shift
  nz_gum choose --header "${nz_uc_header}" --cursor "> " --height 14 \
    --cursor.foreground "${NZ_UI_ACCENT}" --selected.foreground "${NZ_UI_ACCENT}" \
    --header.foreground "${NZ_UI_TEXT}" "$@"
}

nz_ui_input() {
  nz_ui_header_text="$1"
  nz_ui_placeholder="$2"
  shift 2
  nz_gum input --header "${nz_ui_header_text}" --placeholder "${nz_ui_placeholder}" --prompt "> " \
    --prompt.foreground "${NZ_UI_ACCENT}" --cursor.foreground "${NZ_UI_ACCENT}" \
    --header.foreground "${NZ_UI_TEXT}" --placeholder.foreground "${NZ_UI_MUTED}" "$@"
}

nz_ui_write() {
  nz_gum write --header "$1" --placeholder "$2" --width 72 --height 8 --show-line-numbers \
    --cursor.foreground "${NZ_UI_ACCENT}" --header.foreground "${NZ_UI_TEXT}" \
    --placeholder.foreground "${NZ_UI_MUTED}"
}

nz_ui_confirm() {
  nz_ucf_prompt="$1"
  nz_ucf_yes="$2"
  nz_ucf_no="$3"
  shift 3
  nz_gum confirm "${nz_ucf_prompt}" --affirmative "${nz_ucf_yes}" --negative "${nz_ucf_no}" \
    --prompt.foreground "${NZ_UI_TEXT}" --selected.background "${NZ_UI_ACCENT}" \
    --unselected.background "${NZ_UI_SURFACE}" "$@"
}

nz_ui_summary() {
  nz_us2_pairs=$(($# / 2))
  while [ "${nz_us2_pairs}" -gt 0 ]; do
    nz_us2_label=$(printf '%-7s' "$1")
    nz_us2_label=$(nz_ui_ink "${NZ_UI_MUTED}" -- "${nz_us2_label}")
    nz_us2_value=$(nz_ui_ink "${NZ_UI_TEXT}" --bold -- "$2")
    shift 2
    set -- "$@" "${nz_us2_label} ${nz_us2_value}"
    nz_us2_pairs=$((nz_us2_pairs - 1))
  done
  printf '\n'
  nz_gum style --border rounded --border-foreground "${NZ_UI_MUTED}" --padding "0 1" -- "$@"
  printf '\n'
}

nz_ui_spin() {
  nz_us_title="$1"
  nz_us_log="$2"
  shift 2
  (NZ_UI_STEP=1 && "$@") 2>"${nz_us_log}" &
  nz_us_pid=$!
  if ! nz_ui_spin_wait "${nz_us_title}" "${nz_us_pid}"; then
    kill "${nz_us_pid}" 2>/dev/null
    exit 130
  fi
  nz_us_status=0
  wait "${nz_us_pid}" || nz_us_status=$?
  cat "${nz_us_log}" >&2
  return "${nz_us_status}"
}

nz_ui_spin_wait() {
  # shellcheck disable=SC2016
  nz_uw_loop='while kill -0 "$1" 2>/dev/null; do sleep 0.1; done'
  nz_gum spin --spinner dot --spinner.foreground "${NZ_UI_ACCENT}" --title.foreground "${NZ_UI_TEXT}" --title "$1" -- sh -c "${nz_uw_loop}" _ "$2" >&2
}

nz_ui_table() {
  nz_ut_line="-"
  if [ -n "${NZ_UI_TEXT}" ]; then
    nz_ut_line=$(printf '\342\224\200')
  fi
  nz_ut_body=$(nz_ui_table_body "${nz_ut_line}")
  nz_gum style --border rounded --border-foreground "${NZ_UI_MUTED}" --padding "0 1" -- "${nz_ut_body}"
}

nz_ui_table_body() {
  LC_ALL=C awk -F '\t' -v acc="${NZ_UI_ACCENT}" -v ok="${NZ_UI_OK}" -v warn="${NZ_UI_WARN}" \
    -v bad="${NZ_UI_ERR}" -v txt="${NZ_UI_TEXT}" -v mut="${NZ_UI_MUTED}" -v dash="$1" \
    -f "${NZ_LIB}/table.awk"
}

nz_ui_done() {
  printf '\n'
  nz_ui_ink "${NZ_UI_OK}" --bold -- "$1"
}

nz_ui_badge() {
  nz_ub_colour="$1"
  shift
  if [ -z "${nz_ub_colour}" ]; then
    nz_gum style --bold --underline --padding "0 1" -- "$*"
    return
  fi
  nz_gum style --background "${nz_ub_colour}" --foreground "#1E1E2E" --bold --padding "0 1" -- "$*"
}

nz_ui_chip() {
  if [ -z "${NZ_UI_SURFACE}" ]; then
    nz_gum style --padding "0 1" -- "$1"
    return
  fi
  nz_gum style --background "${NZ_UI_SURFACE}" --foreground "${NZ_UI_TEXT}" --padding "0 1" -- "$1"
}

nz_ui_danger() {
  nz_ud_title=$(nz_ui_ink "${NZ_UI_ERR}" --bold -- "$1")
  shift
  nz_gum style --border thick --border-foreground "${NZ_UI_ERR}" --padding "0 1" -- "${nz_ud_title}" "$@" >&2
}

nz_ui_markdown() {
  awk '
    NR == 1 {
      split($0, head, " - ")
      printf "# %s\n\n%s\n", head[1], head[2]
      next
    }
    /^[a-z][a-z ]*:$/ {
      if (open) { print "```" }
      printf "\n## %s\n\n```text\n", toupper(substr($0, 1, 1)) substr($0, 2, length($0) - 2)
      open = 1
      next
    }
    { print }
    END { if (open) { print "```" } }
  '
}
