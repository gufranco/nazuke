#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${NZ_LIB:?}/state.sh"

NAZUKE_VERSION="0.0.0"

nz_version() {
  printf '%s %s\n' "${NZ_PROG}" "${NAZUKE_VERSION}"
}

nz_say() {
  printf '%s\n' "$1"
}

nz_error() {
  if nz_ui_err; then
    nz_ui_log ERROR "$*"
    return 0
  fi
  nz_say "${NZ_PROG}: $*" >&2
}

nz_json_string() {
  printf '%s' "$1" | awk '
    BEGIN { for (i = 1; i < 32; i++) code[sprintf("%c", i)] = sprintf("\\u%04x", i) }
    function escape(s,   r, c, i) {
      r = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\\") r = r "\\\\"
        else if (c == "\"") r = r "\\\""
        else if (c in code) r = r code[c]
        else r = r c
      }
      return r
    }
    { out = out (NR > 1 ? "\\n" : "") escape($0) }
    END { printf "\"%s\"", out }'
}

nz_plural() {
  if [ "$1" -eq 1 ]; then
    printf '1 %s\n' "$2"
  else
    printf '%s %ss\n' "$1" "$2"
  fi
}

nz_set() {
  eval "$1=\$2"
}

nz_get() {
  eval "NZ_GOT=\${$1}"
}
