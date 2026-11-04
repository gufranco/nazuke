#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
duplicates=$(cat "${root}"/bin/nazuke "${root}"/lib/*.sh |
  sed -n 's/^\([a-z_][a-z0-9_]*\)() {$/\1/p' | sort | uniq -d)
if [ -n "${duplicates}" ]; then
  printf 'function defined more than once:\n%s\n' "${duplicates}" >&2
  exit 1
fi

unprefixed=$(cat "${root}"/bin/nazuke "${root}"/lib/*.sh |
  grep -oE '[$][{]?[A-Z][A-Z0-9_]*' | sed 's/^[$][{]*//' | sort -u |
  grep -vE '^(NZ|NAZUKE)_' | grep -vxE 'HOME|PATH|TMPDIR|ZSH_VERSION|KODOUGU_THEME|KODOUGU_ACCENT|NO_COLOR' || true)
if [ -n "${unprefixed}" ]; then
  printf 'environment variable without the NAZUKE_ prefix:\n%s\n' "${unprefixed}" >&2
  exit 1
fi

scrub="for nz_inherited in \$(env | sed -n 's/^\\(NZ_[A-Za-z0-9_]*\\)=.*/\\1/p'); do"
if ! grep -qF "${scrub}" "${root}/bin/nazuke"; then
  printf 'bin/nazuke must clear every inherited NZ_ variable before it starts\n' >&2
  exit 1
fi
