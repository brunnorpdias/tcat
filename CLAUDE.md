# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Vault findings — read this first

These were established empirically against the live vault and are the foundation of the
whole design. Re-verify before changing the reader; don't re-derive from scratch.

1. **`obsidian tasks` carries no section context.** The trailing `– …` strings in its
   output are inline notes written into the task text (of the form `some task –
   superseded by another task`), not day markers. Day attribution is impossible
   from the `tasks` subcommand. This is why `tcat` doesn't use it.

2. **`obsidian read file='<name>'` exists** and resolves wikilink-style, folder-agnostic —
   same semantics as `tasks file=`. No vault-root path is ever needed.

3. **`obsidian tasks` silently skips fenced code blocks.** On a representative weekly
   note it returned exactly 51 tasks, because the whole `### *Fixa*` section and every
   `**future**` bucket are fenced; 51 is precisely Actio's unfenced task lines.

4. **The reader is fence-agnostic on purpose.** ``` lines are ignored, never toggled.
   Fence tracking is actively *harmful*: the Fixa section is itself wrapped in a fence, so
   naive toggling desynchronises (in testing it silently dropped two Fixa days). Ignoring fences is
   safe because every `base`/`dataviewjs` block lives under `## *Recensio*`, ahead of
   `### *Actio*`. Verified: exact count parity with `obsidian tasks` on all ten ladder
   weeks in the vault, zero unattributed tasks.

5. **`obsidian` exits 0 on a missing file** and prints `Error: File "..." not found.` to
   **stdout** when not attached to a TTY (to stderr when it is). `read_note()` matches
   that string explicitly — checking the exit code is not enough.

6. **Older weekly notes predate the day ladder.** Their `### *Actio*` is one flat week
   list with no `**day**` markers (two such notes in testing held 36 and 46 tasks). `-P`
   correctly returns nothing for a specific day; `-v` says so distinctly.

7. **A `future` block can contain its own ladder markers.** One note's future fence
   carried `**sunday**` and `**other**` inside it. Once inside `**future**`, the parser stays there — it
   never re-enters the day ladder.

## What this project does

`tcat` is a single-file Python CLI that shows **one day's tasks** — from that day's daily
note (`<YYYY-MM-DD>`) or, with `-P`, from the weekly note's (`YYYY-W##`) Actio allocation
for that weekday.

Sibling to `tdiff`. **`tdiff` answers *what changed*; `tcat` answers *what is there*.**
`tcat` never compares two sources — every comparison stays with `tdiff`. Resist requests
to add plan-vs-daily columns, drift markers, or diffing of any kind; that is `tdiff`'s job
and the separation is deliberate.

External dependencies: `obsidian` CLI (`read` subcommand only). Requires Python 3.11+
(stdlib `tomllib`). No `rg` — unlike `tdiff`, `tcat` parses note source directly.

## Running

```bash
tcat [date] [flags]                # no build step

python3 tcat 2026-03-04 --no-color
python3 tcat -P tuesday --no-color
python3 tcat 2026-03-04 --flat --no-color
python3 tcat -P 2026-01-07 -v --no-color   # pre-ladder week, distinct -v reason
python3 tcat 2026-03-04 --json
```

No test suite — testing is manual via CLI invocation, as in `tdiff`.

## Architecture

One executable file: `tcat`. Pipeline:

1. **Read** — `read_note()` shells out to `obsidian read file=<name>`, returns lines or
   `None`. See finding 5 about the missing-file detection.

2. **Parse** — `parse_note()` yields `(indent, status_char, name, seq)`. Fence-agnostic
   (finding 4). In weekly mode it filters to `region='actio'` and a ladder day; in daily
   mode it yields everything. `clean_text()` un-escapes `\[`/`\]` (the vault writes both
   `\[\[a]]` and `[[a]]`), reduces links to display text, and strips the ` – …` suffix.
   The ladder is a **whitelist** — `promissum`, `sunday`…`saturday`, `future` — never a
   blacklist, because the weekly template gains sections over time. This is what keeps
   Ratio's `**rationes**` lines and Mensis's prospect checkboxes out.

3. **Group** — `build_groups()` folds flat records into project groups. A top-level
   `[p]`/`[i]`/`[u]` opens a group; indented tasks are its children. Groups **merge**
   across the note case-insensitively (a note may write both `[[Project Alpha]]` and
   `[[project alpha]]`), because block markers are hidden and five identical headers
   would be noise.

4. **Dedup** — `cluster_records()` (vendored from `tdiff`) plus a **divergent**
   `materialize()`: `tcat` reduces a cluster to its **last occurrence in page order**, not
   by `STATUS_PRIORITY`. Within one note the last statement is the current one. This is
   the single most important difference from `tdiff` and is marked in the source.

5. **Sort & render** — `(STATUS_ORDER rank, name.lower())` at every level. `--flat` drops
   project parents and sorts alphabetically only.

## Vendored core

The block between `# ── Vendored task core` and `# ── End vendored core` is copied
verbatim from `tdiff` at pinned commit **`1e7f11c`**: `strip_section_suffix`,
`WIKILINK_RE`/`_strip_wiki_path`/`normalize_wikilinks`, `_PUNCT`/`_tokens`/`is_same_task`,
`cluster_records`, `week_span`, `_SEP_RE`.

Vendoring beats a shared module: two files on `$PATH` with no install step is the
deployment model. Keep it honest with:

```bash
tools/check-core-sync.sh [path-to-tdiff-repo]   # exit 1 on any drift
```

`materialize` is deliberately **not** checked — see pipeline step 4. If you change
anything inside the vendored block, either revert it or move it out of the block and
document why.

## Config

Resolution (first match wins): `--config` → `$TCAT_CONFIG` → `~/.config/tcat/config.toml`
→ **`~/.config/tdiff/config.toml`** (read-only fallback; never bootstrapped, never warned
about) → bootstrap `~/.config/tcat/config.toml`.

The shared fallback is the point: with no `tcat` config, both tools read one status table
and cannot drift.

Unlike `tdiff`, the file is **merged over** built-in defaults rather than replacing them —
a shared `tdiff` config has no `order`/`hide` keys, and a missing rank must not collapse to
`0`. Keys: `order` (display rank, lower first, ties allowed), `hide` (never shown),
`project` (opens a group). `tdiff`'s `priority` and `ignore` are read but unused.

## Key behaviours

| Behaviour | Note |
|---|---|
| Weekday names resolve **backwards** | `tuesday` = most recent Tuesday at or before today. A future weekday has no tasks yet. |
| Future date without `-P` | Hard error — the daily note won't exist. |
| `&` `»` `«` hidden | Filtered **after** dedup, so an earlier `[»]` never suppresses a later `[x]`. `-S` overrides. |
| Empty is never an error | Exit 0. `-v` distinguishes five reasons (missing note / no Actio / empty Actio / pre-ladder week / nothing that day). |
| Fixa, `future`, `promissum` | Parsed as ladder markers so they can't leak into a day, but **not exposed**. v1 is Actio days only. |

### The plan flag is `-P`, not `-w`

Deliberate, and not an oversight to be "corrected" toward `tdiff`. In `tdiff`,
`-W/--no-weekly` means *exclude* the weekly file; in `tcat` the same letter would mean
*use* it — the same object with opposite polarity, across two tools run side by side.
`-P/--plan` collides with neither and matches how the weekly Actio allocation is actually
described. Don't rename it to `-w` or `-W`.

## Known gaps

See the **Known gaps** section of `README.md`. In short: `week_span()` disagrees with the
templates' moment `gggg[-W]ww` across a New Year and needs a **joint** fix with `tdiff`
(due before December 2026); that divergence and the Mensis exclusion are both unverified
because the vault holds no note from either situation; and there is no test suite.

## Style

Match `tdiff`: `# ── Section ─…` banner comments, argparse with a `__NEG__` interception
for bare negative numbers, colour gated on `sys.stdout.isatty()`, summary line suppressed
by `--no-summary`.
