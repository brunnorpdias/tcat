# tcat

Show one day's tasks from an Obsidian vault.

A single-file Python CLI that prints the tasks for a single day — either from that day's
daily note (`<YYYY-MM-DD>`) or from the weekly planning note's (`YYYY-W##`) allocation
for that weekday. Projects are grouped, duplicates are collapsed, and rows are sorted by
status.

Sibling to [`tdiff`](../tdiff). **`tdiff` answers *what changed*; `tcat` answers *what is
there*.** `tcat` never compares two things — every comparison stays with `tdiff`.

File lookups are folder-agnostic: notes resolve by filename anywhere in the vault (like
an Obsidian wikilink), so `tcat` doesn't care which folder your notes live in. See
[Configuration](#configuration) to pin explicit folders.

## Requirements

- Python 3.11+ (stdlib `tomllib` for config parsing)
- The `obsidian` CLI (`obsidian read` is the only subcommand used)

No `rg` dependency — unlike `tdiff`, `tcat` reads note source directly.

## Install

Drop `tcat` somewhere on your `$PATH`. It's executable (`#!/usr/bin/env python3`).

```sh
ln -s ~/Projects/tcat/tcat ~/.local/bin/tcat
```

## Usage

```
tcat [date] [options]
```

```sh
tcat                    # today's daily note
tcat yesterday          # yesterday's daily note
tcat tuesday            # the most recent Tuesday
tcat -P tuesday         # what the weekly plan allocated to that Tuesday
tcat -P tomorrow        # tomorrow's allocation (no daily note exists yet)
tcat 2026-03-04 --flat  # flat alphabetical list, no project grouping
tcat -S x               # only completed tasks
```

### Dates

| Form | Meaning |
| --- | --- |
| `YYYY-MM-DD` | that date |
| `today`, `0` | today (the default) |
| `yesterday` | yesterday |
| `tomorrow` | tomorrow (needs `-P`) |
| `-N` / `+N` | N days before / after today |
| `monday`…`sunday`, `mon`…`sun` | **the most recent occurrence at or before today** |

Weekday names resolve *backwards* on purpose. A future weekday has no tasks recorded
yet, so resolving forwards would always come back empty. On a Monday, `tuesday` means
last Tuesday and `monday` means today.

Asking for a future date without `-P` is an error: the daily note won't exist. Use `-P`
to read the plan's allocation for a day that hasn't happened.

### Options

| Flag | Effect |
| --- | --- |
| `-P`, `--plan` | read the weekly note's Actio allocation for that day (the plan) instead of the daily note |
| `-f`, `--flat` | drop project grouping, promote children to top level, sort alphabetically |
| `-S SET` | show only these status chars; prefix `^` to invert. Overrides hidden statuses |
| `--routines` | include `#routine` tasks (excluded by default) |
| `--json` | machine-readable output |
| `-v` | explain *why* the output was empty |
| `--no-color`, `--no-summary`, `--config PATH` | as in `tdiff` |

`-S -` looks like a flag to argparse; use `-S=-` or fold it into a set (`-S 'x-'`).

## Output

```
$ tcat 2026-03-04

2026-03-04  ·  wed  ·  daily

  [u] site migration
      [/] draft rollback plan
      [#] confirm dns cutover window
      [x] audit redirect map
      [x] stage the new build
  [i] q1 report
      [#] chase figures from finance
      [x] outline sections 2-3
  [!] renew domain
  [*] reply to the archive request
  [ ] tidy downloads folder
  [x] cancel the old subscription

  12 tasks  ·  2 projects
```

That note wrote `site migration` under four different blocks; the four children above
are all of them, collapsed into one group.

*(Examples throughout this README are invented. Substitute your own vault.)*

Three things are happening:

**Blocks are hidden, projects are merged.** A daily note splits work across
`**block [1]**`…`**block [7]**` and `**admin**`. `tcat` drops those markers; a project
appearing under five different blocks becomes one group holding every child.

**Duplicates collapse, last occurrence wins.** A task written in block 1 and again in
block 7 produces one row carrying its *last* status — the most recent statement of where
it stands. (`tdiff` instead picks by `priority`, because it is comparing across days.)

**Links are cleaned.** `[[note|alias]]` → `alias`, `[[folder/note]]` → `note`,
`[text](url)` → `text`.

`--flat` undoes the first two levels of that: no project headers, children promoted,
sorted alphabetically. This is the task set `tdiff` sees for the same date.

## Status order

Rows sort by status rank first, then alphabetically. Equal ranks are allowed.

| Rank | Chars | |
| --- | --- | --- |
| 0 | `u` | urgent project |
| 1 | `i` | important project |
| 2 | `!` | urgent |
| 3 | `*` | important |
| 4 | `o` | recurrent |
| 5 | `␣` `/` | task, partial |
| 6 | `#` `~` | blocked / waiting, snoozed |
| 7 | `>` `=` | current, paused / switch |
| 8 | `-` | cancelled |
| 9 | `x` | done |
| 10 | `p` | project |

`&` (overrun), `»` (postponed) and `«` (advanced) are **hidden**. Hiding happens *after*
dedup, so an earlier `[»]` never suppresses a later `[x]` — only a task whose *final*
state is one of these disappears. `-S` overrides.

## Configuration

Status display order, hidden statuses, project markers, and vault folder overrides live
in a TOML file.

**Location** (first match wins):

1. `--config PATH`
2. `$TCAT_CONFIG`
3. `$XDG_CONFIG_HOME/tcat/config.toml`
4. **`$XDG_CONFIG_HOME/tdiff/config.toml`** — read-only fallback
5. otherwise bootstrap `$XDG_CONFIG_HOME/tcat/config.toml` from the built-in defaults

Step 4 is the point: with no `tcat` config present, both tools read one status table and
cannot drift. Creating `~/.config/tcat/config.toml` is an explicit opt-out.

Unlike `tdiff`, the config is **merged over** the built-in defaults rather than replacing
them. A shared `tdiff` config has no `order` or `hide` keys, so a status missing `order`
falls back to `tcat`'s built-in rank, not to `0`. `tdiff` ignores unknown keys, so adding
`order`/`hide` to the shared file is safe for both.

```toml
[statuses.x]
name = "done"
order = 9        # display rank; lower sorts first. Ties break alphabetically

[statuses."»"]
name = "postponed"
hide = true      # never shown; filtered after dedup

[statuses.u]
name = "urgent project"
order = 0
project = true   # opens a project group; dropped entirely by --flat

[vault]
daily_folder = ""    # optional folder prefix; empty = resolve by name anywhere
weekly_folder = ""
```

`tdiff`'s `priority` and `ignore` keys are read but unused: `tcat` dedups by page
position, and `ignore` is a diff-side concept with no meaning in a viewer.

## How the weekly note is read

`obsidian tasks` cannot drive `-P`, for two reasons found while building this:

- It carries **no section context**, so a task can't be attributed to a weekday.
- It **silently skips fenced code blocks** — and the weekly note's entire `### *Fixa*`
  section and every `**future**` bucket are fenced.

So `tcat` reads note source via `obsidian read` and parses it directly, **ignoring code
fences entirely** rather than tracking them. Fence tracking is actively harmful here: the
Fixa section is itself wrapped in a fence, so naive toggling desynchronises. Ignoring them
is safe because every `base`/`dataviewjs` block lives under `## *Recensio*`, ahead of
`### *Actio*`.

Day markers come from a whitelist — `promissum`, `sunday`…`saturday`, `future` — never a
blacklist, because the weekly template gains sections over time. Everything after
`**future**` stays `future` regardless of inner markers.

Verified against `obsidian tasks` on every weekly note in the author's vault: exact count
parity on every week that uses the day ladder, and zero unattributed tasks.

Fixa, `future` and `promissum` are parsed but **not exposed** — v1 reads the live Actio
day allocation only.

## Empty results

An empty result is never an error, but `-v` distinguishes the reasons:

```
no note found for '2026-W09'
2026-W09 has no ### *Actio* section
2026-W09's Actio is empty
2026-W09 predates the day ladder: its Actio holds 36 tasks as one flat week list, not split by day
nothing allocated to sunday in 2026-W09's Actio
```

The last two are opposite signals and worth telling apart. Older weekly notes may use an
earlier template with no `**day**` markers at all.

## Known gaps

Three things are deliberately unfinished. None affect day-to-day use today.

**1. `week_span()` disagrees with the templates across a New Year.** The weekly templates
name files with moment's `gggg[-W]ww`; `week_span()` computes the label itself. Both start
weeks on Sunday and put week 1 on the week containing Jan 1, but the week-*year* diverges
when a week straddles the boundary. The week of Sun 2026-12-27 contains Jan 1 2027, so
moment names it `2027-W01` while `week_span()` yields `2026-W53` — a file that won't
exist. This is inherited from `tdiff` and affects both tools, so it needs a **joint fix**;
correcting it in `tcat` alone would make the two disagree about which note to read. Due
before December 2026.

**2. Two behaviours are unverified because the vault has no data for them.** The vault used for testing spans a
single quarter, which contains no New Year–straddling week and no `### *Mensis*` section. So gap 1 has never been reproduced against a real file, and the
claim that the ladder whitelist keeps Mensis's prospect checkboxes out of a day is
reasoned, not tested. Re-run both checks once such notes exist.

**3. No test suite.** Testing is manual via CLI invocation, matching `tdiff`. The checks
worth automating first are the ones that actually caught bugs during the build: parse
counts against `obsidian tasks` for every weekly note, and `--flat` against `tdiff`'s task
set for the same date.

Separately, **Fixa, `future` and `promissum` are parsed but not exposed.** That is a
scope decision rather than a gap — v1 reads the live Actio day allocation only — but the
parser already attributes them, so surfacing them is a flag, not a feature.

## Development

`tcat` vendors a block of `tdiff`'s task core rather than importing it — two files on
`$PATH` with no install step is the deployment model. Drift is caught loudly:

```sh
tools/check-core-sync.sh [path-to-tdiff-repo]
```

It diffs each vendored function and constant against `tdiff` at the pinned commit
(`1e7f11c`) and exits non-zero on any difference. `materialize` is deliberately excluded:
`tcat` reduces a cluster by page position, `tdiff` by `priority`.

## License

MIT
