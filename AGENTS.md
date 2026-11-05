# nazuke

Guidance for anyone, human or agent, changing nazuke. What nazuke is and how to use it lives in [README.md](README.md).

[FAMILY.md](FAMILY.md) holds everything nazuke shares with the rest of the kodougu family, and it is the same in every member. This file holds only what is exclusive to nazuke, under the same headings as the agent guide of every member. Read both before changing anything; a rule that would serve the other members goes into `FAMILY.md` instead of here.

## Layout

| Path | Holds |
|:-----|:------|
| [`bin/nazuke`](bin/nazuke) | The entry point: it clears inherited `NZ_` variables, sources the modules and dispatches the command |
| [`lib/`](lib) | The modules. [`lib/state.sh`](lib/state.sh) declares every global. [`lib/words.awk`](lib/words.awk) cleans a name and reads the word pack; [`lib/shorten.awk`](lib/shorten.awk) scores the candidate names and settles collisions |
| [`share/`](share) | Data only: the word packs under `words/`, the transliteration table `translit` and the extension table `extensions` |
| [`man/nazuke.1`](man/nazuke.1) | The man page |
| [`completions/`](completions) | bash, zsh and fish completions |
| [`test/`](test) | The `bats` suite, its helpers, the golden transcripts, the naming corpus under `names/`, the shell matrix runner and the Linux container script |
| [`scripts/`](scripts) | Coverage, the coverage gate, the Linux coverage run and the name check, which `make` runs |
| [`.github/scripts/`](.github/scripts) | The toolset helper and the release version stamp, which only CI and the release run |

## Names

- Globals carry `NZ_`; function-scoped variables carry a per-function `nz_` prefix.
- Settings come from `NAZUKE_MAX`, `NAZUKE_EXT` and `NAZUKE_WORDS`; test switches are `NAZUKE_INTERACTIVE`, `NAZUKE_TEST_SHELLS`, `NAZUKE_TEST_RECORD`, `NAZUKE_TEST_IMAGE`, `NAZUKE_TEST_GUM`, `NAZUKE_TEST_GUM_LOG`, `NAZUKE_TEST_GUM_ANSWERS` and `NAZUKE_TEST_GUM_SPIN`.
- Output goes through `nz_say` and `nz_error`, which hand over to the `nz_ui_` helpers in [`lib/ui.sh`](lib/ui.sh) where gum draws.
- Per-item values live in numbered variables such as `nz_src_3`, read and written only through `nz_get` and `nz_set`.

## Behaviour

- nazuke has two jobs, `name` and `rename`, so a bare `nazuke` on a terminal offers the menu.
- `name` prints one name per line and nothing else, so a script can read it; where gum draws, it prints a table instead.
- Renaming is not destructive, so `rename` shows its summary and plan without a typed confirmation; where gum draws, it asks to confirm. A dry run and a run without a terminal never ask.

## Domain rules

- The naming engine reproduces `src/z64kit/naming.py` of gufranco/n64-mr-backup-z64-python at 6675f5a. `test/names/*.tsv` holds that reference's output for 391 names, with `DROPPABLE` emptied and the fallback `FILE` for the generic pack. A change to the engine keeps both corpora passing, or replaces a row only with a reason in the commit body.
- Deliberate differences from naming.py: a collision without a region tag gets a number, never naming.py's `X`; a disc, disk, CD, side, tape or part number inside a tag stays in the title; when no form fits, a run of five or more digits is dropped, then every digit, before the fallback word, and a title of digits only keeps its first digits; in `rename`, a head before ` - ` shared by three or more files of the folder is dropped from each, in up to two passes; the counter runs while the suffix fits, not to 999. The two corpus rows these change, `IMG 2024 03 11 Beach Sunset` and `Screenshot 2026-11-04 at 10.33.49`, hold nazuke's own names.
- The engine runs under `LC_ALL=C`, so every awk compares and measures bytes alike.
- A file is never renamed over another entry, in any case, and no name is a device name. Every change to the rename path keeps the tests that prove it.
- A rename moves the file to `.nazuke-<n>` first and to its name second, so a case-only rename works on a case-insensitive disk and an interrupt can put every name back.
- A file whose name is already short in capitals and digits is never renamed, so a second run changes nothing.
- Every name produced is capitals and digits, the extension included, so it is a valid 8.3 short name on FAT12 and FAT16 with no long-name entry. A file whose name already equals its short name apart from case keeps that name ahead of any other file that wants it.

## Release

- `NAZUKE_VERSION` lives in [`lib/core.sh`](lib/core.sh).
- The tap's `Formula/nazuke.rb` depends on `gum` and installs `share/` next to `lib/`.

## Gaps against FAMILY.md

- `mv` renames one file per call, so `rename` runs two `mv` calls per file, where FAMILY.md asks for one call per batch (as of 2026-11-04).
