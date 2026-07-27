# tcat

Show one day's tasks from an Obsidian vault.

A single-file Python CLI that prints the tasks for a single day — either from that day's
daily note (`<YYYY-MM-DD>`) or from the weekly planning note's (`YYYY-W##`) allocation
for that weekday. Projects are grouped, duplicates are collapsed, and rows are sorted by
status.

Two flags widen the lens to the week: `-A` merges the whole week's allocation into one
list, and `--missio` prints the week's stated mission.

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
tcat -A                 # everything actually done across this whole week
tcat -A -P              # everything the plan allocated for it
tcat -A w30             # week 30, by number
tcat -A -w -1           # last week
tcat --missio           # this week's mission, verbatim
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
| `w##`, `w2026-W##` | a whole week, not a day — needs `-A` or `--missio` |

Weekday names resolve *backwards* on purpose. A future weekday has no tasks recorded
yet, so resolving forwards would always come back empty. On a Monday, `tuesday` means
last Tuesday and `monday` means today.

Asking for a future date without `-P` is an error: the daily note won't exist. Use `-P`
to read the plan's allocation for a day that hasn't happened.

`w30` names week 30 of the current year; `w2026-W30` is explicit. Both come from `tdiff`,
verbatim, so the two tools take the same week arguments. A week isn't a day, so a bare
`tcat w30` is an error — say what you want for it (`-A`, `-A -P` or `--missio`). The
relative form is `-w N`: `-w -1` is last week, `-w 0` the date's own week.

### Options

| Flag | Effect |
| --- | --- |
| `-P`, `--plan` | read the weekly note's Actio allocation for that day (the plan) instead of the daily note |
| `-A`, `--all-week` | the whole week as one deduplicated list: the week's seven daily notes, or with `-P` the weekly note's Actio plan. The date picks the week; its weekday is ignored |
| `-w N`, `--week-offset N` | select the week N weeks away (`-1` = last week). Only applies to `-A` and `--missio` |
| `--missio` | print the weekly note's `### *Missio*` section verbatim instead of any tasks |
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

### The whole week

`-A` widens the lens from a day to a week. It keeps `tcat`'s existing polarity — a bare
date is what actually happened, `-P` is what was planned — so there are two of them:

| | reads | answers |
| --- | --- | --- |
| `tcat -A` | the week's seven **daily notes** | what did I actually do this week |
| `tcat -A -P` | the weekly note's **Actio** | what was this week supposed to be |

Same grouping, same dedup, same sorting as a single day. Only the source widens, and the
header shows the week:

```
$ tcat -A 2026-03-04

2026-W10  ·  actual  ·  6/7 notes

  [u] site migration
      [#] confirm dns cutover window
      [x] audit redirect map
  [!] renew domain
  [ ] tidy downloads folder

  4 tasks  ·  1 project
```

The `6/7 notes` is the point of the header: days without a note are skipped silently, so
a thin week is usually a week you didn't write up rather than a week you didn't work. A
week in progress shows `2/7`.

Day attribution is dropped by design — this answers *what happened this week*, not *when*.
Dedup therefore spans the week: a task written on Monday and restated on Friday appears
once, carrying **Friday's** status. Under `-A -P`, `promissum` and `future` stay hidden as
elsewhere; under plain `-A`, tasks in a daily note's `**future**` bucket are dropped too —
they are explicitly deferred work, and folding seven days' worth of them into the list
would drown it. Single-day output still shows them.

The date argument selects the *week*; its weekday is ignored, so `tcat -A tuesday` and
`tcat -A` are identical whenever both land in the same week, and `tcat -A w30` names one
outright. In `--json`, `weekday` is `null` for a week payload and `notes` lists exactly
which notes were read.

### The week's mission

`--missio` prints the weekly note's `### *Missio*` section and nothing else — no tasks, no
summary line. The body is reproduced **verbatim**: wikilinks, `==highlights==` and HTML
comments are all left exactly as written, because the section is prose rather than a task
list. Only leading and trailing blank lines are trimmed.

```
$ tcat --missio --json
{
  "week": "2026-W10",
  "missio": "the week is for closing the migration.\n\nnothing else ships until it does."
}
```

`missio` is `null` when the note is missing, has no `### *Missio*` heading, or has one with
an empty body. Exit status is 0 in every case.

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
nothing allocated to any day in 2026-W09's Actio
no daily notes found for 2026-W09
2026-W09's 3 daily notes hold no tasks
```

The pre-ladder and nothing-allocated lines are opposite signals and worth telling apart.
Older weekly notes may use an earlier template with no `**day**` markers at all — for `-A`
that is the difference between a week nobody planned and a week planned in a shape this
tool can't split.

`--missio` has three of its own:

```
no note found for '2026-W09'
2026-W09 has no ### *Missio* section
2026-W09's Missio is empty
```

## Known gaps

Four things are deliberately unfinished. None affect day-to-day use today.

**0. `-A` over a week before `2026-W20` over-counts.** Weekly notes only start at W20;
before that the whole weekly structure — including the coming week's day-by-day plan —
lived inside the Sunday daily note, wrapped in a fence. `tcat` ignores fences on purpose
(see *How the weekly note is read*), so aggregating such a week folds that Sunday's plan
in alongside six days of actual work. Dropping the `**future**` bucket removes the largest
part of it; the rest stands. Fixing it properly would mean re-introducing fence tracking,
which is the one thing that section says not to do.

**1. `week_span()` disagrees with the templates across a New Year — NOT YET FIXED.** The
weekly templates name files with moment's `gggg[-W]ww`; `week_span()` computes the label
itself. Both start weeks on Sunday and put week 1 on the week containing Jan 1, but the
week-*year* diverges when a week straddles the boundary. The week of Sun 2026-12-27 runs
to Sat 2027-01-02, so moment names it `2027-W01` while `week_span()` yields `2026-W53` — a
file that won't exist.

Only the straddling week is affected; the rest of each year agrees. But week *selection*
has made the failure quieter, so this now matters more than it did:

| | across the boundary |
| --- | --- |
| `tcat -A` | **fine** — the seven dates are correct regardless of label; only the header reads `2026-W53` |
| `tcat -A -P`, `tcat --missio` | **broken** — they look for `2026-W53`, which doesn't exist, and report "no note found" |
| `tcat w2027-W01 …` | **silently wrong** — resolves to Sun 2026-12-27, then relabels itself `2026-W53` and reads that. The vault's real `2027-W01` is unreachable by name |

The last row is the bad one: it fails without saying so. This is inherited from `tdiff`
and affects both tools, so it needs a **joint fix** — `resolve_week_label` and
`_week_label_to_sunday` are vendored from `tdiff` too, and correcting it in `tcat` alone
would make the two disagree about which note to read. **Due before December 2026.**

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
