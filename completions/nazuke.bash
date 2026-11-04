# shellcheck shell=bash
# shellcheck disable=SC2207

_nazuke() {
  local cur prev words command
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"
  command="${COMP_WORDS[1]:-}"
  case "${prev}" in
  --theme)
    COMPREPLY=($(compgen -W "kodougu catppuccin-mocha catppuccin-latte dracula nord gruvbox tokyo-night mono" -- "${cur}"))
    return
    ;;
  --words)
    words="generic games $(compgen -f -- "${cur}" || true)"
    COMPREPLY=($(compgen -W "${words}" -- "${cur}"))
    return
    ;;
  --max | --ext) return ;;
  *) ;;
  esac
  if [[ "${COMP_CWORD}" -eq 1 ]]; then
    COMPREPLY=($(compgen -W "name rename doctor version help" -- "${cur}"))
    return
  fi
  if [[ "${cur}" == -* && "${command}" == rename ]]; then
    COMPREPLY=($(compgen -W "--max --ext --words --dry-run --json --theme" -- "${cur}"))
    return
  fi
  if [[ "${cur}" == -* ]]; then
    COMPREPLY=($(compgen -W "--max --words --json --theme" -- "${cur}"))
    return
  fi
  if [[ "${command}" == rename ]]; then
    words="$(compgen -d -- "${cur}" || true)"
    COMPREPLY=($(compgen -W "${words}" -- "${cur}"))
  fi
}

complete -o filenames -F _nazuke nazuke
