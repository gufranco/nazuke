#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${NZ_LIB:?}/state.sh"

nz_usage() {
  if nz_ui_out; then
    nz_usage_text | nz_ui_markdown | nz_gum format --theme "${NZ_UI_HELP}"
    return 0
  fi
  nz_usage_text
}

nz_usage_text() {
  cat <<'USAGE'
nazuke - give long names short, readable, unique ones, 8.3 by default

usage:
  nazuke                          ask what to do, on a terminal
  nazuke name [options] TEXT...   print a short name for each text
  nazuke rename [options] [folder]
                                  give every file of the folder, the current
                                  one when none is given, a short unique name
  nazuke doctor                   check the tools nazuke needs
  nazuke version                  print the version
  nazuke help                     print this page

options:
  --max N                         longest name, 4 to 255, default 8
  --ext N                         rename: longest extension, 1 to 255,
                                  default 3
  --words PACK                    generic, games or the path of a word pack,
                                  default generic
  --dry-run                       rename: list every rename and change nothing
  --json                          print the result as one JSON object
  --theme NAME                    colours of the terminal interface, see notes

environment:
  NAZUKE_MAX, NAZUKE_EXT and NAZUKE_WORDS set the options above; an option
  on the command line wins.

notes:
  A name keeps its words whole where it can, keeps its digits, and drops
  bracketed tags, articles and small words such as of and the. Accented and
  other Latin letters become plain ones. The games pack also drops generic
  title words such as Legend and Super, and turns a region tag such as (USA)
  into one letter when two names collide; any other collision gets a number.

  rename looks at the top of the folder only. A file whose name is already
  short, in capitals and digits, keeps it, so a second run changes nothing.
  The extension after the last dot is kept in capitals, shortened to --ext
  characters, so each name is a valid 8.3 name on FAT12 and FAT16. No new
  name repeats another entry of the folder in any case or names a device
  such as CON or LPT1. Subfolders, hidden files and special files
  keep their names. An interrupt puts back every name it changed.

  On a terminal with gum installed, nazuke draws its prompts, plan and
  results with gum. --theme, else NAZUKE_THEME, else KODOUGU_THEME picks the
  colours: kodougu, catppuccin-mocha, catppuccin-latte, dracula, nord,
  gruvbox, tokyo-night or mono. KODOUGU_ACCENT=#RRGGBB replaces only the
  accent, and NO_COLOR turns colour off.

examples:
  nazuke name "Legend of Zelda, The - Ocarina of Time (USA)"
  nazuke rename --words games --dry-run ~/roms
  nazuke rename --max 12 --ext 4 .
USAGE
}

nz_cli_hint() {
  nz_error "$1. run '${NZ_PROG} help' for usage."
}

nz_cli_version() {
  nz_cv_platform="$(uname -sr)" || nz_cv_platform="unknown"
  if nz_ui_out; then
    nz_cv_text="$(nz_version)"
    nz_cv_badge="$(nz_ui_badge "${NZ_UI_ACCENT}" "${nz_cv_text}")"
    nz_cv_chip="$(nz_ui_chip "platform ${nz_cv_platform}")"
    nz_gum join --horizontal "${nz_cv_badge}" " " "${nz_cv_chip}"
    return 0
  fi
  nz_version
  printf 'platform: %s\n' "${nz_cv_platform}"
}

nz_interactive() {
  [ "${NAZUKE_INTERACTIVE:-}" = 1 ] && return 0
  [ -t 0 ]
}

nz_prompt() {
  if nz_ui_prompts; then
    nz_pd_answer="$(nz_ui_input "$1" "$2")" || return 1
    printf '%s\n' "${nz_pd_answer:-$2}"
    return 0
  fi
  nz_pr_label="$1: "
  [ -z "$2" ] || nz_pr_label="$1 [$2]: "
  printf '%s' "${nz_pr_label}" >&2
  nz_pr_answer=""
  IFS= read -r nz_pr_answer || [ -n "${nz_pr_answer}" ] || return 1
  printf '%s\n' "${nz_pr_answer:-$2}"
}

nz_menu() {
  if ! nz_interactive; then
    nz_cli_hint "no command given"
    return 1
  fi
  if nz_ui_prompts; then
    nz_ui_header
    nz_mn_choice="$(nz_ui_choose "What would you like to do?" "Shorten a name" "Rename the files of a folder")" || return 1
  else
    printf 'What would you like to do?\n  1) shorten a name\n  2) rename the files of a folder\nChoice: ' >&2
    nz_mn_choice=""
    IFS= read -r nz_mn_choice || [ -n "${nz_mn_choice}" ] || return 1
  fi
  case "${nz_mn_choice}" in
  1 | "Shorten a name") nz_name ;;
  2 | "Rename the files of a folder") nz_rename ;;
  *)
    nz_error "not a listed choice: ${nz_mn_choice}"
    return 1
    ;;
  esac
}
