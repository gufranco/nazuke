#!/bin/sh
set -eu

version=${1:?version required}
root=$(cd "$(dirname "$0")/../.." && pwd)
core="${root}/lib/core.sh"

if ! grep -q '^NAZUKE_VERSION=' "${core}"; then
  printf 'no NAZUKE_VERSION assignment found in %s\n' "${core}" >&2
  exit 1
fi

tmp=$(mktemp "${TMPDIR:-/tmp}/nazuke-version-XXXXXX")
sed "s/^NAZUKE_VERSION=\".*\"$/NAZUKE_VERSION=\"${version}\"/" "${core}" >"${tmp}"
cat "${tmp}" >"${core}"
rm -f "${tmp}"

reported=$("${root}/bin/nazuke" --version)
printf 'version set to %s\n' "${reported}"
