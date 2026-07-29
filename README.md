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

## Breaking changes

The output and configuration were reworked. If you used an earlier build:

- **Config moved and changed shape.** The status table now lives at
  `~/.config/obsidian-tasks/statuses.toml` and uses grouped `[order]` / `[theme.*]` /
  `[roles]` blocks instead of per-status `[statuses.X]` tables. `~/.config/tdiff/config.toml`
  is **no longer read**. See [Configuration](#configuration).
- **There are no built-in status ranks.** Order comes from config or not at all; with no
  config `tcat` runs unranked and uncoloured and says so once on stderr.
- **`-v` is gone**, along with the per-reason explanations of an empty result. Empty output
  is always `nothing to show`. The `reason` key is gone from `--json` too.
- **The header moved to the bottom.** Output now starts with the first task; context lives
  in a single footer line. `--no-summary` suppresses that whole line, date included.

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

Weeks run Sunday to Saturday, and **a week is named for the year it ends in** — week 1 is
the week containing Jan 1, so Sun 2026-12-27 → Sat 2027-01-02 is `w2027-W01`, matching the
vault's filenames. Naming a week the calendar can't produce (`w2026-W53`, which is really
2027-W01) is rejected with the correct label, rather than silently reading a note that
doesn't exist.

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
| `-I`, `--ignore` | hide settled tasks — the statuses in `[roles].settled` — leaving only what is still open |
| `--routines` | include `#routine` tasks (excluded by default) |
| `--json` | machine-readable output |
| `--no-color`, `--no-summary`, `--config PATH` | as in `tdiff` |

`-S -` looks like a flag to argparse; use `-S=-` or fold it into a set (`-S 'x-'`).

`--no-summary` drops the entire footer — counts *and* context. That is what you want when
piping; use `--json` when you want the context in a parseable form.

## Output

```
$ tcat 2026-03-04
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

  12 tasks, 2 projects  ·  daily  ·  2026-03-04
```

Tasks start on the first line. Everything contextual sits in one dim footer, always
`contents  ·  mode  ·  file(s)`:

| invocation | footer |
| --- | --- |
| `tcat 2026-03-04` | `12 tasks, 2 projects  ·  daily  ·  2026-03-04` |
| `tcat -P` | `5 tasks  ·  plan  ·  2026-W10` |
| `tcat -A` | `38 tasks  ·  all  ·  2026-W10 (6/7 dailies)` |
| `tcat -A -P` | `31 tasks  ·  all plan  ·  2026-W10` |
| `tcat --missio` | `text  ·  missio  ·  2026-W10` |

The file field names **what was actually read**, which is why `-P` shows the weekly note
rather than the day you asked about, and why `-A` — which never opens the weekly note —
names the week and states its coverage.

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

Collapsing is *scoped*: each project's children collapse among themselves, and the
top-level tasks collapse among themselves, but never into one another. A task listed under
two projects therefore keeps a row under each — the project header is context worth
seeing — and a top-level occurrence never swallows a project's copy.

**Links are cleaned.** `[[note|alias]]` → `alias`, `[[folder/note]]` → `note`,
`[text](url)` → `text`.

`--flat` undoes the first two levels of that: no project headers, children promoted,
sorted alphabetically. This is the task set `tdiff` sees for the same date. Having no
projects, it also has no scopes, so it collapses across all of them — which is why `--flat`
can show *fewer* rows than the grouped view of the same day. That is the two views
answering different questions, not a discrepancy.

### Colour

Only the status marker is coloured; task names stay in the terminal's default foreground.
A wall of tinted prose is harder to read than a column of tinted markers. The brackets take
the colour along with the symbol — `[x]` reads as one glyph, and tinting only the char
inside it leaves the marker looking half-lit.

The exception is done and cancelled, which take their colour across the **whole row**. So
grey carries two distinct signals: a grey *marker* means deprioritised but still open, a
grey *line* means settled and done with.

Colours are entirely config-driven, with separate light and dark palettes — see
[Configuration](#configuration). A status with no colour configured renders plain, which
is the right answer for the most common ones.

### The whole week

`-A` widens the lens from a day to a week. It keeps `tcat`'s existing polarity — a bare
date is what actually happened, `-P` is what was planned — so there are two of them:

| | reads | answers |
| --- | --- | --- |
| `tcat -A` | the week's seven **daily notes** | what did I actually do this week |
| `tcat -A -P` | the weekly note's **Actio** | what was this week supposed to be |

Same grouping, same dedup, same sorting as a single day. Only the source widens, and the
footer names the week:

```
$ tcat -A 2026-03-04
  [u] site migration
      [#] confirm dns cutover window
      [x] audit redirect map
  [!] renew domain
  [ ] tidy downloads folder

  4 tasks, 1 project  ·  all  ·  2026-W10 (6/7 dailies)
```

The `6/7 dailies` is the point: days without a note are skipped silently, so a thin week
is usually a week you didn't write up rather than a week you didn't work. A week in
progress shows `2/7`.

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

`--missio` prints the weekly note's `### *Missio*` section and nothing else — no tasks.
The body is reproduced **verbatim**: wikilinks, `==highlights==` and HTML comments are all
left exactly as written, because the section is prose rather than a task list. Only leading
and trailing blank lines are trimmed.

It keeps the same three-field footer as every other mode. Prose isn't countable, so the
`contents` field is the literal word `text`:

```
$ tcat --missio
  the week is for closing the migration.

  nothing else ships until it does.

  text  ·  missio  ·  2026-W10
```

The JSON form is minimal — deliberately not the task envelope:

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

Rows sort by status rank first, then alphabetically. **There are no built-in ranks** — the
order comes from `[order].statuses`, a single ordered list where rank *is* position. Ties
cannot be expressed and reordering means moving a string.

The shipped default, and the colour groups it produces:

| # | Chars | | Colour |
| --- | --- | --- | --- |
| 0-1 | `u` `!` | urgent project, urgent | purple |
| 2-3 | `i` `*` | important project, important | gold |
| 4-6 | `>` `=` `o` | current, paused / switch, recurrent | blue |
| 7-8 | `p` `␣` | project, task | *none* |
| 9-14 | `/` `#` `~` `&` `»` `«` | partial, blocked, snoozed, overrun, postponed, advanced | grey |
| 15-16 | `-` `x` | cancelled, done | grey, **whole row** |
| — | *anything else* | | *none*, sorted last |

The sequence is arranged so colour groups stay contiguous — `p` and `␣` are the deliberate
uncoloured island between the blue and grey blocks.

A status that appears in a note but not in `[order].statuses` still renders: unranked, at
the bottom, uncoloured. `tcat` names it once on stderr, so a gap in the config never looks
like a sort bug.

`&` (overrun), `»` (postponed) and `«` (advanced) are **hidden** via `[roles].hide`. Hiding
happens *after* dedup, so an earlier `[»]` never suppresses a later `[x]` — only a task
whose *final* state is one of these disappears. `-S` overrides.

`-I` hides `[roles].settled` on top of that — `x`, `-`, `&`, `»`, `«` by default — which
leaves only work that is still open. The three filters compose, with one rule: **a `-S` that
names a status outright wins.** So `-I -S x` shows done tasks rather than nothing; asking for
something by name is the strongest statement that you want to see it. A *negated* `-S` names
only what to drop, so `-I` still applies to everything it didn't name (`-I -S '^ '` = open,
non-blank, non-settled).

`-I` has no built-in status set. With no `[roles].settled` in your config it hides nothing
and says so once on stderr — the same contract as `[order].statuses`.

`[roles].settled` is shared with `tdiff`, whose `-I` reads the same key. The flags mean the
same thing in both tools, with one difference that follows from what each tool does: `tdiff`
applies it to the settled (A) side only, so added and changed rows are never hidden by it.

## Configuration

Two files, both optional. Copy the examples from this repo:

```sh
mkdir -p ~/.config/obsidian-tasks && cp statuses.example.toml ~/.config/obsidian-tasks/statuses.toml
mkdir -p ~/.config/tcat          && cp config.example.toml    ~/.config/tcat/config.toml
```

**`~/.config/obsidian-tasks/statuses.toml` — the shared table.** It describes *your vault's
task notation*, not either tool, which is why it lives in a directory neither `tcat` nor
`tdiff` owns. Both read it and each ignores what it has no use for — `tcat` takes `[order]`,
`[theme.*]` and `[roles].full_row`, `tdiff` takes `[dedup]`, and `[roles]` `project` / `hide`
/ `settled` are read by both. So the two cannot drift, and neither has to be installed for
the other to work. Both repos ship a byte-identical copy of this file; installing either
tool gets you the whole table.

**`~/.config/tcat/config.toml` — a `tcat`-only overlay.** Vault folder overrides, plus
anything from the shared table you want `tcat` to see differently.

**Layers**, lowest precedence first. Each *merges* over the ones below it, so a partial
file never erases what a lower layer set:

1. `$XDG_CONFIG_HOME/obsidian-tasks/statuses.toml`
2. `$XDG_CONFIG_HOME/tcat/config.toml`
3. `$TCAT_CONFIG`
4. `--config PATH`

There is no built-in layer beneath these, and nothing is ever bootstrapped. With none of
them present `tcat` still runs — unranked and uncoloured — and says so once on stderr.
Lists replace wholesale rather than merging element-wise: naming a partial
`[order].statuses` in an overlay means exactly that order.

```toml
[order]
# Rank is position. Statuses omitted here sort last, uncoloured.
statuses = ["u", "!", "i", "*", ">", "=", "o", "p", " ", "/", "#", "~", "&", "»", "«", "-", "x"]

[roles]
project  = ["p", "i", "u"]   # opens a project group; dropped entirely by --flat
hide     = ["&", "»", "«"]   # never shown; filtered after dedup
settled  = ["x", "-", "&", "»", "«"]   # hidden by -I; shared with tdiff
full_row = ["x", "-"]        # colour the whole line, not just the [x] marker

[theme.dark]
"!" = "#a20ef1"
"x" = "#b3b3b3"
# statuses omitted here render in the terminal's default foreground

[theme.light]
"!" = "#7a0bb5"
"x" = "#8a8a8a"

[vault]
daily_folder = ""    # optional folder prefix; empty = resolve by name anywhere
weekly_folder = ""
```

Colours are 24-bit hex. Which palette is used: **`$TCAT_THEME=light|dark`**, else the
`COLORFGBG` variable most terminals set, else dark. Terminals don't reliably report their
background, so an env var settles it rather than a query that would need raw-tty mode.

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

An empty result is never an error. Whatever the cause — no note, no `### *Actio*` section,
nothing allocated to that day, or a weekly note predating the day ladder — the output is
one line, `nothing to show`, and the exit status is 0. `--no-summary` suppresses even that.

An earlier build explained *which* of those it was, behind `-v`. Both are gone.

## Known gaps

Three things are deliberately unfinished. None affect day-to-day use today.

**0. `-A` over a week before `2026-W20` over-counts.** Weekly notes only start at W20;
before that the whole weekly structure — including the coming week's day-by-day plan —
lived inside the Sunday daily note, wrapped in a fence. `tcat` ignores fences on purpose
(see *How the weekly note is read*), so aggregating such a week folds that Sunday's plan
in alongside six days of actual work. Dropping the `**future**` bucket removes the largest
part of it; the rest stands. Fixing it properly would mean re-introducing fence tracking,
which is the one thing that section says not to do.

**1. One behaviour is unverified because the vault has no data for it.** The vault used for
testing spans a single quarter, which contains no `### *Mensis*` section — so the claim that
the ladder whitelist keeps Mensis's prospect checkboxes out of a day is reasoned, not tested.
Re-run that check once such a note exists.

**2. No test suite.** Testing is manual via CLI invocation, matching `tdiff`. The checks
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
(`123b5b1`) and exits non-zero on any difference. `materialize` is deliberately excluded:
`tcat` reduces a cluster by page position, `tdiff` by `priority`.

## License

MIT
