# tcat

Show what is in an Obsidian note: one day's tasks, or one week's.

A single-file Python CLI. **A date names a day, a `w##` names a week, and a week has two
sources — its seven daily notes and its `YYYY-W##` weekly note — that `-D` / `-W` narrow
to one.** Projects are grouped, duplicates are collapsed, and rows are ranked by status
then name.

Sibling to [`tdiff`](../tdiff). **`tdiff` answers *what changed*; `tcat` answers *what is
there*.** `tcat` never compares two things — every comparison stays with `tdiff`. The two
share their date resolver, their note parser, their task-name normalisation and their
status table, so a task has one name and one spelling whichever tool you ask.

File lookups are folder-agnostic: notes resolve by filename anywhere in the vault (like
an Obsidian wikilink), so `tcat` doesn't care which folder your notes live in. See
[Configuration](#configuration) to pin explicit folders.

## Breaking changes

The flag surface was rebuilt around `tdiff`'s model, and the two tools now spell shared
concepts the same way. If you used an earlier build:

1. **`-P` is now `-W`.** `tdiff`'s `-W` used to mean *exclude* the weekly note, so `tcat`
   avoided the letter; `tdiff` reversed that polarity, and `-W` now means *read only the
   weekly note* in both tools. `tcat today -P` is `tcat today -W`.
2. **`-A` is gone; name the week.** `tcat -A` is `tcat w0`, `tcat -A w30` is `tcat w30 -D`,
   and `tcat -A -P w30` is `tcat w30 -W`. A bare `tcat w30` is new: both sources merged,
   with the dailies winning any status conflict.
3. **`-w N` is gone; weeks can be named relative.** `tcat -A -w -1` is `tcat w-1 -D`.
   `w0`, `w-1` and `w+1` work in `tdiff` too.
4. **`--flat` and `--order` are gone.** Output is always grouped and always ranked by
   `[order].statuses` then name. `--flat`'s purpose — "the task set `tdiff` sees" — ended
   when `tdiff` started grouping by project as well.
5. **Task names keep their wikilink brackets.** `[[note|alias]]` now renders as
   `[[note|alias]]`, not `alias`, matching `tdiff`. More importantly the ` – section`
   suffix is stripped *before* links are touched, so a linked title containing a dash is
   no longer truncated — that was losing text from 22 of 435 names in one test vault.
6. **`--json` is flat.** `tasks` with nested `children` became `rows`, each naming its
   `project`; `source` and `notes` became `mode` and `files`. Nothing consumed the old
   shape — `tdiff -E`, its only reader, was deleted.
7. **A missing `obsidian` binary is now fatal**, with a message and exit 2, instead of an
   empty result and exit 2. `TCAT_ATTEMPTS` is gone and the timeout is whole seconds,
   defaulting to 1.
8. **`--missio` is gone.** It printed one named section of one vault's weekly note as
   prose — a flag, a parser, a JSON shape and a footer branch, all of them spelling a
   section name into the source. Use `obsidian read` for prose.
9. **`--routines` is now `--all`**, and what it lifts comes from `[exclude] tags` rather
   than from a `#routine` fallback in the code. `--all` lifts `[exclude] sections` too.
10. **The reader now skips fenced blocks**, reversing a deliberate old rule — see
   [How the weekly note is read](#how-the-weekly-note-is-read).
11. **Dedup picks the winner by `[dedup]` priority**, not by last occurrence in page
   order, matching `tdiff`. Page order is the tie-break within a tier.
12. **Config moved to `~/.config/tconfig/`** and the shared half of the code moved to
   [`tnotes`](https://github.com/brunnorpdias/tnotes). The env vars are `TNOTES_WORKERS`,
   `TNOTES_TIMEOUT` and `TNOTES_DEBUG`.

Older, still true:

- **The status table uses grouped `[order]` / `[theme.*]` / `[roles]` blocks** instead of
  per-status `[statuses.X]` tables. See [Configuration](#configuration).
- **There are no built-in status ranks.** Order comes from config or not at all; with no
  config `tcat` runs unranked and uncoloured and says so once on stderr.
- **`-v` is gone**, along with the per-reason explanations of an empty result. Empty output
  is always `nothing to show`.
- **The header moved to the bottom.** Output starts with the first task; context lives in a
  single footer line. `--no-summary` suppresses that whole line, date included.

## Requirements

- Python 3.11+ (stdlib `tomllib` for config parsing)
- The `obsidian` CLI (`obsidian read` is the only subcommand used)

- [`tnotes`](https://github.com/brunnorpdias/tnotes) on `~/.local/lib`, shared with `tdiff`

## Install

Drop `tcat` somewhere on your `$PATH`. It's executable (`#!/usr/bin/env python3`). It
reads the vault through [`tnotes`](https://github.com/brunnorpdias/tnotes), a module it
shares with `tdiff`, which goes in `~/.local/lib`:

```sh
mkdir -p ~/.local/lib
ln -s ~/Projects/tcat/tcat        ~/.local/bin/tcat
ln -s ~/Projects/tnotes/tnotes.py ~/.local/lib/tnotes.py
```

There is no packaging and no install step. See [Configuration](#configuration) for the
config folder, which is also shared.

## Usage

```
tcat [date|w##] [options]
```

**A date names a day, a `w##` names a week, and a week has two sources you can narrow to.**
The positional picks the scope; `-D`/`-W` pick the source.

```sh
tcat                    # today's daily note
tcat yesterday          # yesterday's daily note
tcat tuesday            # the most recent Tuesday
tcat tuesday -W         # what the weekly plan allocated to that Tuesday
tcat tomorrow -W        # tomorrow's allocation (no daily note exists yet)
tcat -S x               # only completed tasks

tcat w30                # week 30: its weekly note and its seven dailies, merged
tcat w30 -D             # ...the dailies only — what actually happened
tcat w30 -W             # ...the weekly note only — the plan
tcat w0                 # this week
tcat w-1 -D             # last week, dailies only
```

### Dates and weeks

| Form | Meaning |
| --- | --- |
| `YYYY-MM-DD` | that date |
| `today`, `0` | today (the default) |
| `yesterday` | yesterday |
| `tomorrow` | tomorrow (needs `-W`) |
| `-N` / `+N` | N days before / after today |
| `monday`…`sunday`, `mon`…`sun` | **the most recent occurrence at or before today** |
| `w##`, `w2026-W##` | that week |
| `w0`, `w-1`, `w+1` | this week, last week, next week |

Weekday names resolve *backwards* on purpose. A future weekday has no tasks recorded
yet, so resolving forwards would always come back empty. On a Monday, `tuesday` means
last Tuesday and `monday` means today.

Asking for a future date without `-W` is an error: the daily note won't exist. A `w##` or
`-W` may look forward freely — the weekly note is often written before the week starts.

Weeks run Sunday to Saturday, and **a week is named for the year it ends in** — week 1 is
the week containing Jan 1, so Sun 2026-12-27 → Sat 2027-01-02 is `w2027-W01`, matching the
vault's filenames. Naming a week the calendar can't produce (`w2026-W53`, which is really
2027-W01) is rejected with the correct label, rather than silently reading a note that
doesn't exist.

Every one of these forms comes from `tdiff`, verbatim — the resolver is shared code, so the
two tools always take the same arguments.

### Options

| Flag | Effect |
| --- | --- |
| `-D`, `--dailies` | read only daily notes: on a `w##`, the week's seven; on a date, the daily note, which is already the default |
| `-W`, `--weekly` | read only the `YYYY-W##` weekly note: on a date, that weekday's allocation; on a `w##`, the whole week's plan |
| `-S SET`, `--status SET` | show only these status chars; prefix `^` to invert. Overrides hidden statuses |
| `-I`, `--ignore` | hide settled tasks — the statuses in `[roles].settled` — leaving only what is still open |
| `--all` | ignore the whole `[exclude]` table — sections and tags alike — for one run. Fenced blocks are still skipped |
| `--json` | machine-readable output |
| `--no-color`, `--no-summary` | as in `tdiff` |
| `--config PATH` | additional (merging) config layer, applied last |

`-D` and `-W` are mutually exclusive: naming neither reads both sources, so naming both
would be a second spelling of the default. They are `tdiff`'s letters with `tdiff`'s
polarity — `-W` means *read only the weekly note* in both tools.

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
| `tcat 2026-03-04 -W` | `5 tasks  ·  plan  ·  2026-W10` |
| `tcat w10` | `44 tasks  ·  week  ·  2026-W10 (6/7 dailies, weekly)` |
| `tcat w10 -D` | `38 tasks  ·  week dailies  ·  2026-W10 (6/7 dailies)` |
| `tcat w10 -W` | `31 tasks  ·  week plan  ·  2026-W10` |

The file field names **what was actually read**, which is why `-W` shows the weekly note
rather than the day you asked about, and why a week states its coverage — how many of the
seven dailies were on disk, and whether the weekly note was among the sources.

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

**Links keep their brackets.** A wikilink loses only its folder path
(`[[folder/note|alias]]` → `[[note|alias]]`); a markdown link reduces to its display text
(`[text](url)` → `text`). A trailing ` – comment` is dropped **before** links are
touched, so a linked title containing a dash survives intact — `tcat` used to reduce the
link first and cut the name at the dash, which is fixed and matches `tdiff` exactly.
Which characters cut a comment is yours to set in `[comment] separators`, and one only
counts between spaces and outside every bracket *and* parenthesis.

### Order

Rows are ranked by `[order].statuses`, then alphabetically within a rank — at every level,
top-level rows and project children alike. There is no flag: `--flat` and `--order` both
existed and both were removed, because neither had a second setting worth keeping.
`--flat`'s stated purpose was "the task set `tdiff` sees", which stopped being true once
`tdiff` started grouping by project too; `--order alpha` was indistinguishable from the
default unless a config existed, and `--order page` forced a page position through the
whole pipeline to serve only itself.

With no config there are no ranks, so everything is `UNRANKED` and the order is
alphabetical.

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

A `w##` widens the lens from a day to a week. A week has two sources, and `-D`/`-W` pick
which to read; naming neither reads both.

| | reads | answers |
| --- | --- | --- |
| `tcat w30 -D` | the week's seven **daily notes** | what did I actually do |
| `tcat w30 -W` | the weekly note | what was the week supposed to be |
| `tcat w30` | **both**, merged and deduped | everything this week involved |

Same grouping, same dedup, same sorting as a single day. Only the source widens, and the
footer names the week.

```
$ tcat w10 -D
  [u] site migration
      [#] confirm dns cutover window
      [x] audit redirect map
  [!] renew domain
  [ ] tidy downloads folder

  4 tasks, 1 project  ·  week dailies  ·  2026-W10 (6/7 dailies)
```

The `6/7 dailies` is the point: days without a note are skipped silently, so a thin week
is usually a week you didn't write up rather than a week you didn't work. A week in
progress shows `2/7`.

**In the merged form, the dailies win.** The weekly note is read first and the seven
dailies after it, so when a task appears in both, the row carries the status the *daily*
gave it — the plan says what was intended, the daily says what became of it. This is the
same precedence `tdiff` gets by ranking the weekly note below every daily.

Day attribution is dropped by design — a week answers *what is in this week*, not *when*.
Dedup therefore spans the whole read: a task written on Monday and restated on Friday
appears once, and `[dedup]` priority decides which status it carries — so a task written
`[x]` on Tuesday and `[/]` on Friday reads as done, whichever line came last.

**Restated means restated identically.** Two tasks merge iff their names are the same
after normalisation, ignoring case — there is no similarity metric. Dedup used to also
merge names with equal token sets, or where one was a strict token-subset sharing a
first word, and that made 221 merges across this vault including `purchase coffee`
swallowing `purchase new coffee grinder`. Nothing separates those from the routine
merges they look identical to, so the rule went rather than being tuned. A task you
reworded on Friday is now two rows, which is what the notes actually say.

Every note is read whole, so `w## -W` gives you the whole plan: tasks allocated to a
weekday marker and tasks allocated to none, which on a week you are still drafting is
usually all of them. The single-day form (`tcat tuesday -W`) asks the narrower question —
what is allocated to *that day* — and reads that marker alone, using the literals from
`[days]`. A marker is matched exactly and must be alone on its line, and markers are
looked for in weekly notes only: a task or a comment that mentions a weekday is not one.

In `--json`, `weekday` is `null` for a week payload and `files` lists exactly which notes
were read.

## Status order

Rows sort by status rank first, then alphabetically — the only order there is, the
default; see [Order](#order) for the other two. **There are no built-in ranks** — the
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

One folder, shared with `tdiff`, split by concern rather than by tool. Copy the examples
from the [`tnotes`](https://github.com/brunnorpdias/tnotes) repo:

```sh
mkdir -p ~/.config/tconfig
cp ../tnotes/notation.example.toml ~/.config/tconfig/notation.toml
cp ../tnotes/statuses.example.toml ~/.config/tconfig/statuses.toml
```

Then edit `notation.toml` to match how you write your notes.

**`notation.toml` — how the vault writes things.** `[exclude] sections` names headings that
are never read, `[exclude] tags` names tags whose task lines are not really tasks, `[days]`
says what a weekday marker looks like, `[comment] separators` says which characters cut a
trailing comment off a task name, `[vault]` pins folder prefixes.

**`statuses.toml` — what the statuses mean.** `[order]` display rank, `[dedup]` dedup
precedence, `[roles]` project/hide/settled/full_row, `[theme.*]` colours.

Both files describe *your vault*, not either tool, which is why they live in a directory
neither `tcat` nor `tdiff` owns. Each tool ignores what it has no use for — `[theme.*]` and
`[roles].full_row` are `tcat`'s alone — and neither has to be installed for the other to
work. Splitting by concern rather than by tool is deliberate: it is the axis along which a
file actually changes, and splitting by tool would mean writing the same section twice and
watching the copies drift.

**`~/.config/tconfig/tcat.toml` — an optional `tcat`-only overlay.** See
[`tcat.example.toml`](tcat.example.toml).

**Layers**, lowest precedence first. Each *merges* over the ones below it, so a partial
file never erases what a lower layer set:

1. `$XDG_CONFIG_HOME/tconfig/notation.toml`
2. `$XDG_CONFIG_HOME/tconfig/statuses.toml`
3. `$XDG_CONFIG_HOME/tconfig/tcat.toml`
4. `$TCAT_CONFIG`
5. `--config PATH`

`$TCONFIG_DIR` relocates the folder. Nothing is ever bootstrapped, and there are no
built-in ranks or colours: with no config at all `tcat` runs unranked and uncoloured and
says so once on stderr. If `tconfig/` holds none of the first three files, the older
layout — `~/.config/obsidian-tasks/statuses.toml` and `~/.config/tcat/config.toml` — is
read instead, with one notice naming the new home.

## How the weekly note is read

The same way a daily note is: **whole**. There is nothing left to say about *which*
sections to read.

This used to be a section about whitelists — the plan pinned to one `###` heading, days
pinned to a ladder of markers spelled into the source, and fences ignored on purpose
because one vault's frozen task section happened to be wrapped in one. Every part of that
was a fact about one person's notes living in the code, and it made a plan parked under an
unfamiliar heading unreachable however the config was written.

What replaced it:

- **`[exclude] sections`** names headings that are never read, along with everything under
  them. A section is skipped for what it is *called*, not for how it happens to be
  formatted — which is the durable version of the same idea. `>` separates ancestors
  (`"plan > deferred"`), and emphasis, backticks and case are ignored.
- **Fenced blocks are skipped**, a reversal of the old rule. Fencing is how a vault
  freezes a task list, and reading a frozen copy as live tasks is a bug — on one note it
  was 76 phantom rows out of 85. The old argument for ignoring fences was really an
  argument for naming the section, which the exclude list now does. `--all` lifts the
  exclude list for one run and does **not** lift the fence.
- **`[days]`** says what a weekday marker looks like — a **literal** per weekday, or a
  list of them so a vault that has changed notation keeps reading its own history. It is
  matched against the whole line and anchored, so the marker must be alone on it, and
  nothing in a value is a wildcard except `{date}`, which stands for an ISO date. It is
  read for one purpose: `tcat <date> -W`, that weekday's allocation. With no `[days]`
  configured nothing opens a day, so that form reads empty — which is the honest answer
  for a vault that does not allocate tasks to days.
- **`[comment] separators`** names the characters that cut a trailing comment off a task
  name, so `- [ ] do blood screening – will complete saturday` is the task
  `do blood screening`. A separator only counts between spaces and outside every bracket
  and parenthesis. Name none and nothing is stripped.

An empty result is never an error: no note, no matching section, nothing under a marker —
all of them print `nothing to show` and exit 0.

## Empty results

An empty result is never an error. Whatever the cause — no note, no matching section,
nothing allocated to that day, or a weekly note predating the day ladder — the output is
one line, `nothing to show`, and the exit status is 0. `--no-summary` suppresses even that.

An earlier build explained *which* of those it was, behind `-v`. Both are gone.

## Known gaps

**No test suite.** Testing is manual via CLI invocation, matching `tdiff`. The check worth
automating first is cross-tool: `tcat --json` row names and statuses against the
corresponding side of `tdiff --json` for the same week. The two share the parser, the name
normalisation and the dedup rule now, so any disagreement is a real regression.

## Development

`tcat` and `tdiff` import their shared half from **[`tnotes`](https://github.com/brunnorpdias/tnotes)**
— one module, one copy — rather than each carrying its own. Everything that has to be
answered identically lives there: which note to open, what counts as a task, what a task
is called, when two tasks are the same one, how statuses rank, and what a missing config
means.

**It used to be vendored**, with a marked block in this file, a pinned `tdiff` commit and
a `tools/check-core-sync.sh` that diffed the two. That failed the way vendoring always
does. The pin went stale — two `tdiff` commits behind by the end — `parse_note` and
`clean_text` drifted, and the check never covered `materialize` or `load_config` at all,
so the two tools quietly disagreed about which status a deduped task carries and about
what no config means. The check script is deleted; the drift it existed to catch cannot
occur.

What is still `tcat`'s own: project grouping, the theme machinery, rendering, the footer,
and the argument parser. The check worth running by hand is cross-tool — `tcat w32 -D`
and the A side of `tdiff w32 w33 -D` should name the same tasks with the same statuses.
Before the module they could not.

No test suite; testing is manual via CLI invocation, matching `tdiff`.

## License

MIT
