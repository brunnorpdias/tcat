# tcat

Show what is in an Obsidian note: one day's tasks, or one week's.

A single-file Python CLI. **A date names a day, a `w##` names a week, and a week has two
sources — its seven daily notes and its `YYYY-W##` weekly note — that `-D` / `-W` narrow
to one.** Projects are grouped, duplicates are collapsed, and rows are ranked by status
then name.

Sibling to [`tdiff`](https://github.com/brunnorpdias/tdiff). **`tdiff` answers *what
changed*; `tcat` answers *what is there*** — it never compares two sources. The two share
their date resolver, note parser, name normalisation and status table through
[`tnotes`](https://github.com/brunnorpdias/tnotes), so a task has one name and one
spelling whichever tool you ask.

Notes resolve by filename anywhere in the vault, the way a wikilink does, so `tcat`
doesn't care which folder yours live in.

## Requirements

- Python 3.11+ (stdlib `tomllib`)
- the `obsidian` CLI (`obsidian read` is the only subcommand used)
- [`tnotes`](https://github.com/brunnorpdias/tnotes) on `~/.local/lib`, shared with `tdiff`

## Install

```sh
mkdir -p ~/.local/lib
ln -s ~/Projects/tcat/tcat        ~/.local/bin/tcat
ln -s ~/Projects/tnotes/tnotes.py ~/.local/lib/tnotes.py
```

No packaging and no build step. Config is shared as well — see
[Configuration](#configuration). With no config at all `tcat` still runs: unranked,
uncoloured, and saying so once on stderr.

## Usage

```
tcat [date|w##] [options]
```

The positional picks the scope; `-D` / `-W` pick the source.

```sh
tcat                    # today's daily note
tcat yesterday
tcat tuesday            # the most recent Tuesday
tcat tuesday -W         # what the weekly plan allocated to that Tuesday
tcat tomorrow -W        # tomorrow's allocation (no daily note exists yet)

tcat w30                # week 30: its weekly note and its seven dailies, merged
tcat w30 -D             # ...the dailies only — what actually happened
tcat w30 -W             # ...the weekly note only — the plan
tcat w0                 # this week (w-1 last week, w+1 next week)

tcat -S x               # only completed tasks
tcat w30 --dupes        # only what that week wrote more than once
```

### Dates and weeks

| Form | Meaning |
| --- | --- |
| `YYYY-MM-DD` | that date |
| `today`, `0` | today (the default) |
| `yesterday`, `tomorrow` | as they read |
| `-N` / `+N` | N days before / after today |
| `monday`…`sunday`, `mon`…`sun` | **the most recent occurrence at or before today** |
| `w##`, `w2026-W##` | that week |
| `w0`, `w-1`, `w+1` | this week, last week, next week |

Weekday names resolve *backwards* on purpose: a future weekday has no tasks recorded yet.
On a Monday, `tuesday` means last Tuesday and `monday` means today.

Asking for a future **date** without `-W` is an error — the daily note won't exist. A
`w##` or `-W` may look forward freely, since the weekly note is often written before the
week starts.

Weeks run Sunday to Saturday and are **named for the year they end in**: Sun 2026-12-27 →
Sat 2027-01-02 is `w2027-W01`, matching the vault's filenames. A label the calendar can't
produce (`w2026-W53`) is rejected with the correct one rather than read as a note that
doesn't exist.

`tdiff` takes every one of these forms too — the resolver is shared code.

### Options

| Flag | Effect |
| --- | --- |
| `-D`, `--dailies` | read only daily notes: on a `w##`, the week's seven; on a date, the daily note, which is already the default |
| `-W`, `--weekly` | read only the `YYYY-W##` weekly note: on a date, that weekday's allocation; on a `w##`, the whole week's plan |
| `-S SET`, `--status SET` | show only these status chars; prefix `^` to invert. Overrides hidden statuses |
| `-I`, `--ignore` | hide settled tasks — the statuses in `[roles].settled` — leaving only what is still open |
| `--dupes` | show only tasks written more than once in whatever was read, each with `×count` and the status of every occurrence |
| `--all` | ignore the whole `[exclude]` table — sections and tags alike — for one run. Fenced blocks are still skipped |
| `--json` | machine-readable output |
| `--no-color`, `--no-summary` | as in `tdiff` |
| `--config PATH` | additional (merging) config layer, applied last |

`-D` and `-W` are mutually exclusive: naming neither reads both sources, so naming both
would be a second spelling of the default. They are `tdiff`'s letters with `tdiff`'s
polarity — `-W` means *read only the weekly note* in both tools. `--dupes` has no short
letter for the same reason: `-D` is `--dailies` now, and that is the letter `tdiff`'s own
duplicates mode used to take.

`-S -` looks like a flag to argparse; use `-S=-` or fold it into a set (`-S 'x-'`).

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

*(Examples throughout are invented. Substitute your own vault.)*

Tasks start on the first line. Everything contextual sits in one dim footer, always
`contents · mode · file(s)`, and the file field names **what was actually read**:

| invocation | footer |
| --- | --- |
| `tcat 2026-03-04` | `12 tasks, 2 projects  ·  daily  ·  2026-03-04` |
| `tcat 2026-03-04 -W` | `5 tasks  ·  plan  ·  2026-W10` |
| `tcat w10` | `44 tasks  ·  week  ·  2026-W10 (6/7 dailies, weekly)` |
| `tcat w10 -D` | `38 tasks  ·  week dailies  ·  2026-W10 (6/7 dailies)` |
| `tcat w10 -W` | `31 tasks  ·  week plan  ·  2026-W10` |

So `-W` names the weekly note rather than the day you asked about, and a week states its
coverage — `6/7 dailies` means one day had no note, which is usually a day you didn't
write up rather than one you didn't work.

`--no-summary` drops that whole line; use it when piping. `--json` gives the same context
as `mode`, `date`, `weekday`, `week` and `files`, plus flat `rows` where each task names
its `project`.

### What a note becomes

- **Blocks are hidden, projects are merged.** A note that splits work across
  `**block [1]**`…`**block [7]**` loses those markers, and a project appearing under five
  of them becomes one group holding every child.
- **Duplicates collapse.** One row per task, carrying the status `[dedup]` priority ranks
  highest — "done" is the truest thing you can say about a task also written `[/]` earlier
  — with page order as the tie-break. `tdiff` reduces by the same rule.
- **Collapsing is scoped.** Each project's children collapse among themselves and the
  top-level tasks among themselves, never into one another, so a task listed under two
  projects keeps a row under each.
- **Sameness is exact.** Two tasks are one iff their names match after normalisation,
  ignoring case. There is no similarity metric, so a task you reworded is two rows.
- **Links keep their brackets.** `[[folder/note|alias]]` prints as `[alias]` — your own
  words for the target, in a single bracket because what is printed is no longer a link —
  while an unaliased link keeps both. Display only: `--json` and dedup use the full name.
- **Fences and excluded sections are skipped.** A fenced block is how a vault freezes a
  task list, and `[exclude] sections` / `tags` name what isn't live work. `--all` lifts the
  exclude table for one run and does **not** lift the fence.
- **Rows are ranked** by `[order].statuses` then alphabetically, at every level. There is
  no ordering flag.

### Duplicates

`--dupes` keeps only the rows dedup actually collapsed — the tasks written more than once
in whatever was read — and puts the evidence beside each: how many times, and the status
of every occurrence in page order.

```
$ tcat w10 --dupes
  [u] site migration
      [x] audit redirect map  ×3  [ ] [/] [x]
  [o] clean browser tabs  ×2  [o] [o]
  [x] complete the weekly review  ×5  [»] [/] [&] [&] [x]

  3 duplicated tasks, 1 project  ·  week  ·  2026-W10 (6/7 dailies, weekly)
```

The rows are unchanged — same status, same rank, same colour. The dim trail is only why
each is here: `×5` is a task carried across five notes, and reading it left to right says
what became of it. The count includes occurrences whose status is hidden, because hiding
happens after dedup.

It is a filter, not a mode. The positional and `-D`/`-W` still decide what is read, `-S`
and `-I` still filter on the *winning* status, `--json` adds `count` and `statuses` to
each row plus a top-level `dupes`, and the footer only changes its noun.

Duplicated means collapsed, so it inherits dedup's scoping and its exactness: a task under
two projects is two rows and neither is a duplicate, and a task you reworded is not one
either. On one daily note this finds what you wrote out twice; over a week, what you kept
restating.

### The whole week

| | reads | answers |
| --- | --- | --- |
| `tcat w30 -D` | the week's seven **daily notes** | what did I actually do |
| `tcat w30 -W` | the weekly note | what was the week supposed to be |
| `tcat w30` | **both**, merged and deduped | everything this week involved |

Same grouping, dedup and sorting as a single day; only the source widens.

**In the merged form the dailies win.** The weekly note is read first and the seven
dailies after it, so a task in both carries the status the *daily* gave it — the plan says
what was intended, the daily says what became of it.

Day attribution is dropped by design: a week answers *what is in this week*, not *when*.
`weekday` is `null` in a week's `--json` payload, and `files` lists exactly what was read.

## Status order

**There are no built-in ranks.** Order comes from `[order].statuses`, one ordered list
where rank *is* position. The shipped default, and the colour groups it produces:

| # | Chars | | Colour |
| --- | --- | --- | --- |
| 0-1 | `u` `!` | urgent project, urgent | purple |
| 2-3 | `i` `*` | important project, important | gold |
| 4-6 | `>` `=` `o` | current, paused / switch, recurrent | blue |
| 7-8 | `p` `␣` | project, task | *none* |
| 9-14 | `/` `#` `~` `&` `»` `«` | partial, blocked, snoozed, overrun, postponed, advanced | grey |
| 15-16 | `-` `x` | cancelled, done | grey, **whole row** |
| — | *anything else* | | *none*, sorted last |

The sequence keeps colour groups contiguous, with `p` and `␣` the deliberate uncoloured
island between blue and grey. A status that appears in a note but not in the list still
renders — unranked, at the bottom, uncoloured — and is named once on stderr so a gap in
the config never looks like a sort bug.

Only the status marker is coloured, brackets included; done and cancelled take the colour
across the **whole row**. Grey therefore carries two signals: a grey marker means
deprioritised but open, a grey line means settled. Colour follows `$TCAT_THEME`, else
`COLORFGBG`, else dark, and is off when stdout isn't a terminal.

**Three filters decide what is shown, and they compose:** `[roles].hide` (`&` `»` `«` by
default), `-I` for `[roles].settled`, and `-S`. The rule is that **a `-S` naming a status
outright wins** — `-I -S x` shows done tasks rather than nothing. A *negated* `-S` names
only what to drop, so `-I` still applies to the rest. Hiding happens after dedup, so an
earlier `[»]` never suppresses a later `[x]`. `-I` has no built-in set: with no
`[roles].settled` configured it hides nothing and says so.

## Configuration

One folder, shared with `tdiff`, split by concern rather than by tool — it describes your
*vault*, not either tool, which is why neither owns it. Copy the examples from
[`tnotes`](https://github.com/brunnorpdias/tnotes), which is where they ship:

```sh
mkdir -p ~/.config/tconfig
cp ../tnotes/notation.example.toml ~/.config/tconfig/notation.toml
cp ../tnotes/statuses.example.toml ~/.config/tconfig/statuses.toml
```

- **`notation.toml` — how your vault writes things.** `[exclude] sections` / `tags`,
  `[days]` (what a weekday marker looks like, matched literally and alone on its line),
  `[comment] separators`, `[vault]` folder prefixes. Each key is documented in the example
  file; edit it to match your notes.
- **`statuses.toml` — what the statuses mean.** `[order]` display rank, `[dedup]` dedup
  precedence, `[roles]` project/hide/settled/full_row, `[theme.dark]` / `[theme.light]`.
- **`tcat.toml` — an optional `tcat`-only overlay.** See
  [`tcat.example.toml`](tcat.example.toml).

Layers, lowest precedence first; each *merges* over the ones below, so a partial file
never erases what a lower layer set:

1. `~/.config/tconfig/notation.toml`
2. `~/.config/tconfig/statuses.toml`
3. `~/.config/tconfig/tcat.toml`
4. `$TCAT_CONFIG`
5. `--config PATH`

`$TCONFIG_DIR` relocates the folder, and `$XDG_CONFIG_HOME` is honoured. Nothing is ever bootstrapped and there are no
built-in ranks or colours. If `tconfig/` holds none of the first three files, the older
layout (`~/.config/obsidian-tasks/statuses.toml`, `~/.config/tcat/config.toml`) is read
instead with one notice naming the new home.

## Good to know

- **An empty result is never an error.** No note, no matching section, nothing allocated
  to that day, no duplicates under `--dupes` — all of them print one `nothing to show` and
  exit 0. `--no-summary` suppresses even that.
- **Missing daily notes are skipped silently.** The footer's `n/7` is where a thin week
  shows up.
- **`tcat <date> -W` needs `[days]`.** With none configured nothing opens a weekday, so
  that form reads empty — the honest answer for a vault that doesn't allocate tasks to
  days. Every other form reads each note whole.
- **Exit status is 0** for any amount of output, and 2 for a bad argument or a broken
  `obsidian` CLI.
- **Environment:** `$TCAT_THEME`, `$TCAT_CONFIG`, `$TCONFIG_DIR`, and `$TNOTES_WORKERS` /
  `$TNOTES_TIMEOUT` / `$TNOTES_DEBUG` for the shared reader.

## If you used an earlier build

| was | now |
| --- | --- |
| `tcat today -P` | `tcat today -W` |
| `tcat -A`, `tcat -A w30`, `tcat -A -P w30` | `tcat w0`, `tcat w30 -D`, `tcat w30 -W` |
| `tcat -A -w -1` | `tcat w-1 -D` |
| `--flat`, `--order`, `-v`, `--missio` | gone; output is always grouped and ranked |
| `--routines` | `--all`, which lifts the whole `[exclude]` table |
| `TCAT_WORKERS`, `TCAT_TIMEOUT`, `TCAT_DEBUG`, `TCAT_ATTEMPTS` | `TNOTES_*`, minus attempts |
| `~/.config/tcat/config.toml` | `~/.config/tconfig/` |
| nested `--json` `tasks` / `children` | flat `rows`, each naming its `project` |

Also: fenced blocks are now skipped, dedup picks by `[dedup]` priority rather than by last
occurrence, and a missing `obsidian` binary is fatal. `CLAUDE.md` carries the reasoning
behind each of these.

## Development

`tcat` and `tdiff` import their shared half from
[`tnotes`](https://github.com/brunnorpdias/tnotes) — one module, one copy. Everything that
has to be answered identically lives there: which note to open, what counts as a task,
what a task is called, when two tasks are the same one, how statuses rank, and what a
missing config means. What stays `tcat`'s own is project grouping, the theme machinery,
rendering, the footer and the argument parser.

**There is no test suite**; testing is manual via CLI invocation, as in `tdiff`. The check
worth running by hand is cross-tool: `tcat w32 -D` and the A side of `tdiff w32 w33 -D`
should name the same tasks with the same statuses.

## License

MIT
