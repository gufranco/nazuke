from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections.abc import Iterable, Iterator, Sequence
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(os.environ.get("NAZUKE_ROOT", Path(__file__).resolve().parent.parent))
EXTENSION = re.compile(r"(?=[A-Za-z0-9]*[A-Za-z])[A-Za-z0-9]{1,8}")
SHORT_PART = re.compile(r"[A-Z0-9]*")
RESERVED = frozenset([
    "CON",
    "PRN",
    "AUX",
    "NUL",
    *(f"COM{i}" for i in range(1, 10)),
    *(f"LPT{i}" for i in range(1, 10)),
])
WORKERS = 8
TEXT = {"encoding": "utf-8", "errors": "surrogateescape"}
Rename = tuple[str, str, str]


@dataclass(frozen=True)
class Settings:
    pack: Path
    max_len: int
    ext_len: int
    fallback: str


@dataclass(frozen=True)
class Folder:
    name: str
    renames: tuple[Rename, ...]
    stems: tuple[str, ...]
    problems: tuple[str, ...]


@dataclass(frozen=True)
class Totals:
    files: int
    renamed: int
    alone: int
    fallback: int
    problems: tuple[str, ...]


def split_name(name: str) -> tuple[str, str]:
    stem, dot, ext = name.rpartition(".")
    if dot and stem and EXTENSION.fullmatch(ext):
        return stem, ext
    return name, ""


def short_already(stem: str, ext: str, settings: Settings) -> bool:
    if (
        not stem
        or stem in RESERVED
        or not SHORT_PART.fullmatch(stem)
        or not SHORT_PART.fullmatch(ext)
    ):
        return False
    return len(stem) <= settings.max_len and len(ext) <= settings.ext_len


def one_line(text: str) -> str:
    return text.replace("\n", " ").replace("\t", " ")


def engine(mode: str, lines: Iterable[str], settings: Settings) -> list[str]:
    command = [
        "awk",
        "-v",
        f"mode={mode}",
        "-v",
        f"max={settings.max_len}",
        "-v",
        f"extmax={settings.ext_len}",
        "-v",
        f"pack={settings.pack}",
        "-v",
        f"translit={ROOT / 'share/translit'}",
        "-v",
        f"extensions={ROOT / 'share/extensions'}",
        "-f",
        str(ROOT / "lib/words.awk"),
        "-f",
        str(ROOT / "lib/shorten.awk"),
    ]
    data = "".join(lines).encode(**TEXT)
    done = subprocess.run(
        command,
        input=data,
        capture_output=True,
        check=True,
        env={**os.environ, "LC_ALL": "C"},
    )
    return done.stdout.decode(**TEXT).splitlines()


def full(name: str, ext: str) -> str:
    return f"{name}.{ext}".upper() if ext else name.upper()


def entries(
    names: Sequence[str], settings: Settings
) -> tuple[tuple[str, ...], tuple[Rename, ...]]:
    taken: list[str] = []
    free: list[Rename] = []
    for name in names:
        stem, ext = split_name(name)
        if name.startswith(".") or short_already(stem, ext, settings):
            taken.append(name)
        else:
            free.append((name, stem, ext))
    return tuple(taken), tuple(free)


def engine_input(taken: Sequence[str], free: Sequence[Rename]) -> Iterator[str]:
    for name in taken:
        yield f"0\ttaken\t{one_line(name)}\t\n"
    for index, (_name, stem, ext) in enumerate(free, start=1):
        yield f"{index}\tfree\t{one_line(stem)}\t{ext}\n"


def problem(new: str, base: str, owner: str | None, pattern: re.Pattern[str]) -> str:
    if not base:
        return "gets no name"
    if not pattern.fullmatch(new) or base.upper() in RESERVED:
        return f"gets an invalid name {new}"
    if owner is not None:
        return f"and {owner} both get {new}"
    return ""


def problems_of(
    folder: str, taken: Sequence[str], renames: Sequence[Rename], settings: Settings
) -> tuple[str, ...]:
    pattern = re.compile(
        rf"[A-Z0-9]{{1,{settings.max_len}}}(\.[A-Z0-9]{{1,{settings.ext_len}}})?"
    )
    seen = {name.upper(): name for name in taken}
    found: list[str] = []
    for name, base, ext in renames:
        new = full(base, ext)
        reason = problem(new, base, seen.get(new) if base else None, pattern)
        if reason:
            found.append(f"{folder}: {name} {reason}")
        seen[new] = name
    return tuple(found)


def check_folder(folder: str, names: Sequence[str], settings: Settings) -> Folder:
    taken, free = entries(names, settings)
    if not free:
        return Folder(folder, (), (), ())
    rows = tuple(
        row.split("/", 2)
        for row in engine("assign", engine_input(taken, free), settings)
    )
    renames = tuple((free[int(key) - 1][0], base, ext) for key, base, ext in rows)
    stems = tuple(free[int(key) - 1][1] for key, _base, _ext in rows)
    return Folder(folder, renames, stems, problems_of(folder, taken, renames, settings))


def folders_of(corpus: Path) -> dict[str, tuple[str, ...]]:
    grouped: dict[str, list[str]] = {}
    for line in corpus.read_text(**TEXT).splitlines():
        if line:
            folder, _slash, name = line.rpartition("/")
            grouped.setdefault(folder, []).append(name)
    return {folder: tuple(sorted(names)) for folder, names in grouped.items()}


def alone_names(folders: Sequence[Folder], settings: Settings) -> dict[str, str]:
    stems = sorted({stem for folder in folders for stem in folder.stems})
    rows = engine(
        "name",
        (f"{index}\t{one_line(stem)}\n" for index, stem in enumerate(stems)),
        settings,
    )
    return {
        stems[int(key)]: name
        for key, _tab, name in (row.partition("\t") for row in rows)
    }


def is_fallback(base: str, stem: str, word: str) -> bool:
    return re.fullmatch(rf"{word}[0-9]*", base) is not None and word not in stem.upper()


def totals_of(folders: Sequence[Folder], file_count: int, settings: Settings) -> Totals:
    alone = alone_names(folders, settings)
    pairs = [
        (stem, rename[1])
        for folder in folders
        for stem, rename in zip(folder.stems, folder.renames)
    ]
    return Totals(
        files=file_count,
        renamed=len(pairs),
        alone=sum(1 for stem, base in pairs if base and alone.get(stem) == base),
        fallback=sum(
            1 for stem, base in pairs if is_fallback(base, stem, settings.fallback)
        ),
        problems=tuple(line for folder in folders for line in folder.problems),
    )


def share(part: int, whole: int) -> float:
    return round(100 * part / whole, 2) if whole else 100.0


def regressions(totals: Totals, baseline: dict[str, int]) -> tuple[str, ...]:
    found: list[str] = []
    if totals.fallback > baseline["fallback"]:
        found.append(
            f"fallback names rose from {baseline['fallback']} to {totals.fallback}"
        )
    before, now = (
        share(baseline["alone"], baseline["renamed"]),
        share(totals.alone, totals.renamed),
    )
    if now < before:
        found.append(
            f"names kept as they stand alone fell from {before:.2f}% to {now:.2f}%"
        )
    return tuple(found)


def report(path: Path, folders: Sequence[Folder]) -> None:
    lines = (
        f"{one_line(f.name)}\t{one_line(name)}\t{full(base, ext)}\n"
        for f in folders
        for name, base, ext in f.renames
    )
    path.write_text("".join(lines), **TEXT)


def settings_of(words: str, max_len: int, ext_len: int) -> Settings:
    pack = (
        ROOT / "share/words" / words if words in ("generic", "games") else Path(words)
    )
    found = re.search(r"^fallback ([A-Z0-9]+)$", pack.read_text(**TEXT), re.MULTILINE)
    return Settings(pack, max_len, ext_len, found.group(1) if found else "FILE")


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="corpus-check",
        description="Rename every folder of a corpus with the real engine and check the names.",
    )
    parser.add_argument(
        "corpus",
        type=Path,
        help="a file of paths, one per line, grouped into folders by their last slash",
    )
    parser.add_argument(
        "--words", default="games", help="generic, games or the path of a word pack"
    )
    parser.add_argument("--max", type=int, default=8, dest="max_len")
    parser.add_argument("--ext", type=int, default=3, dest="ext_len")
    parser.add_argument(
        "--report",
        type=Path,
        help="write folder, name and short name of every renamed file",
    )
    parser.add_argument(
        "--record",
        action="store_true",
        help="save these counts as the baseline next to the corpus",
    )
    return parser.parse_args()


def summary(totals: Totals) -> str:
    return (
        f"files: {totals.files}\nrenamed: {totals.renamed}\n"
        f"kept as they stand alone: {totals.alone} ({share(totals.alone, totals.renamed):.2f}%)\n"
        f"fallback names: {totals.fallback}\nproblems: {len(totals.problems)}"
    )


def run(args: argparse.Namespace) -> int:
    settings = settings_of(args.words, args.max_len, args.ext_len)
    grouped = folders_of(args.corpus)
    with ThreadPoolExecutor(WORKERS) as pool:
        folders = tuple(
            pool.map(
                lambda item: check_folder(item[0], item[1], settings), grouped.items()
            )
        )
    totals = totals_of(folders, sum(len(names) for names in grouped.values()), settings)
    if args.report:
        report(args.report, folders)
    baseline_path = args.corpus.with_name(args.corpus.name + ".baseline.json")
    failures = (
        *totals.problems,
        *(
            regressions(totals, json.loads(baseline_path.read_text(**TEXT)))
            if baseline_path.is_file() and not args.record
            else ()
        ),
    )
    print(summary(totals))
    for line in failures[:50]:
        print(line, file=sys.stderr)
    if args.record and not totals.problems:
        baseline_path.write_text(
            json.dumps({
                "renamed": totals.renamed,
                "alone": totals.alone,
                "fallback": totals.fallback,
            })
            + "\n",
            **TEXT,
        )
    return 1 if failures else 0


def main() -> int:
    args = arguments()
    if not args.corpus.is_file():
        print(f"corpus-check: cannot read the corpus: {args.corpus}", file=sys.stderr)
        return 2
    return run(args)


sys.exit(main())
