#!/bin/sh
set -eu

: "${SCREENS_REPO:?}"
demo=/Users/Shared/demo
rm -rf "${demo}"
mkdir -p "${demo}/bin" "${demo}/roms" "${demo}/Music"
for name in "Legend of Zelda, The - Ocarina of Time (USA) (Rev 2).z64" "Super Mario 64 (USA).z64" \
  "Pokemon Snap (USA).z64" "Pokemon Snap (Europe).z64" "Conker's Bad Fur Day (USA).z64" \
  "GoldenEye 007 (USA).z64" "MARIO64.z64"; do
  printf 'x\n' >"${demo}/roms/${name}"
done
for name in "01 - Bohemian Rhapsody.mp3" "02 - Don't Stop Me Now.mp3" "Cover Art.jpeg" "Live at Wembley 1986.flac"; do
  printf 'x\n' >"${demo}/Music/${name}"
done
