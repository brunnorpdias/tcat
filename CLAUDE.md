# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What the vault taught us, and what is left of it

This file used to open with ten numbered findings about one vault — which sections are
fenced, which heading holds the plan, which markers a day ladder accepts. **They are
gone, and their absence is the point.** Every one of them was a fact about one person's
notes that had been spelled into the source, and each decided on the tool's behalf where
a plan lives. A vault that wrote things differently was unreachable however its config
was written.

What survives is only what is true of the *notation's shape* rather than of any vault:

1. **`obsidian read`, not `obsidian tasks`.** The flat task list `tasks` returns has
   already thrown away the headings an exclude list names, and the day markers that say
   when a planned task was due. `tcat` has always read raw markdown; `tdiff` moved onto
   it, and that is where the two stopped disagreeing about what a note contains.

2. **Fenced blocks are skipped.** ` ``` ` / `~~~` toggle, and nothing inside is parsed.
   This is a **reversal**: the reader used to ignore fences on purpose, because one
   vault's frozen task section was itself wrapped in a fence and toggling desynchronised
   the read. That argument was really an argument for naming the section, which
   `[exclude] sections` now does — durably, since a section is skipped for what it is
   called rather than for how it happens to be formatted. Fencing is how a vault freezes
   a list; reading those as live tasks is a bug, and on `2026-05-17` it was 76 phantom
   rows out of 85.

3. **A missing note is ordinary.** No note, no matching section, nothing under a day
   marker — all of these are an empty result and exit 0, never a parse failure.

4. **Dedup spans the whole read**, and the winner comes from `[dedup]` priority. See
   **Architecture** step 4: this changed, and it is the one place `tcat`'s output moved
   for a reason other than the fence.


## What this project does

`tcat` is a Python CLI that shows **what is in a note**: one day's tasks, or one week's.
It reads the vault through `tnotes`, a module it shares with `tdiff`.

**`--missio` is gone.** It printed one named section of one vault's weekly note as
verbatim prose — a whole flag, a whole `extract_section()`, a whole JSON shape and a
whole footer branch, all of them spelling a section name into the source. Nothing about
it generalised, and the tool is leaner for its absence. A vault that wants prose out of a
note has `obsidian read`.

**The grammar is one sentence, and it is tdiff's: a date names a day, a `w##` names a
week, and a week has two sources you narrow with `-D`/`-W`.** The positional picks the
scope, the flags pick the source.

| invocation | reads |
|---|---|
| `tcat today` / `tcat today -D` | that day's daily note |
| `tcat today -W` | the weekly note's allocation for that weekday |
| `tcat w34` | the whole week, both sources merged and deduped |
| `tcat w34 -D` | the week's seven daily notes |
| `tcat w34 -W` | the week's plan, whole |

`--dupes` narrows any of those five to the tasks dedup collapsed. It is a filter over one
read, not a second grammar and not a comparison — see **Architecture** step 4.

`-D` on a date is a documented no-op — a day's daily note is already the default. It
exists so the two flags read as a pair rather than as one flag with a gap.

**`-D`/`-W` are tdiff's letters with tdiff's polarity, and that is deliberate.** This
used to be `-P/--plan`, on the argument that `-W` in tdiff meant *exclude the weekly
note* — the opposite polarity on two tools run side by side. tdiff reversed that in
`596020d`: `-W` now means *read only the weekly note*, which is exactly what `-P` meant.
The collision the old name avoided no longer exists, so don't reintroduce `-P`. The same
goes for `-A`, which was chosen over `-W` for the same now-void reason, and for `-w`,
which tcat's docs claimed was "copied from tdiff exactly" when tdiff has never had it.

Sibling to `tdiff`. **`tdiff` answers *what changed*; `tcat` answers *what is there*.**
`tcat` never compares two sources — every comparison stays with `tdiff`. Resist requests
to add plan-vs-daily columns, drift markers, or diffing of any kind; that is `tdiff`'s job
and the separation is deliberate.

**`--dupes` is not an exception to that.** It compares nothing: a duplicate is a property
of a *single* read — the same task written twice in whatever the invocation opened — so the
answer is still "what is there", with the count of how often. `tdiff` used to own this as
`-D`/`--dupes` and it was deleted in `596020d` along with `-E`; it lives here now because
one read is all it ever needed. Its two sigils did not come with it: `!!` (exact repeat)
versus `~~` (variant wordings) was a distinction fuzzy clustering could draw, and
`cluster_records` has been exact since `3e11c8b`, so there is one kind of duplicate left.
**The letter did not come with it either** — `-D` is `--dailies` in both tools now, so
`--dupes` is long-only rather than a third meaning for that key.

**The seam now lives entirely inside `tdiff`, and `tcat` owes it nothing.** Plan-vs-actual
is `tdiff today -W`: tdiff reads the weekly note itself, so it no longer needs tcat to
hand it a task set. `tdiff -E`, which used to take shell commands as
its two sides, was deleted in `596020d` — and with it the only consumer of tcat's nested
`--json` envelope. That envelope is now flat `rows` in tdiff's shape, and nothing parses
it; earlier docs here said to freeze it "because `tdiff` parses it", which stopped being
true and is the reason the shape was free to change.

External dependencies: the `obsidian` CLI (`read` subcommand only) and `tnotes` on
`~/.local/lib`. Requires Python 3.11+ (stdlib `tomllib`).

## Running

```bash
tcat [date|w##] [flags]            # no build step

python3 tcat 2026-03-04 --no-color
python3 tcat tuesday -W --no-color         # tuesday's allocation in the weekly plan
python3 tcat 2026-03-04 --json
python3 tcat w30 --no-color                # a week, both sources merged
python3 tcat w30 -D --no-color             # the week actually done
python3 tcat w30 -W --no-color             # the week as planned
python3 tcat w0 --no-color                 # this week
python3 tcat w-1 -D --json                 # last week's dailies
python3 tcat today --all --no-color        # ignore [exclude]; fences still skipped
python3 tcat w30 --dupes --no-color        # only what that week wrote more than once
```

No test suite — testing is manual via CLI invocation, as in `tdiff`.

## Architecture

One executable file, `tcat`, on top of `tnotes`. Pipeline — steps 1, 2 and 4 are the
shared module's, and only the seams are described here:

1. **Read** — `tn.obsidian_lines()` memoises `obsidian read file=<name>`; `tn.prefetch()`
   warms several notes at once through a 4-worker pool (`TNOTES_WORKERS`). It is called
   on every path, since the read plan is one list of notes; a single-note run takes the
   serial branch. The timeout, retry and `stdin=DEVNULL` guards live there too.

2. **Parse** — `tn.parse_note()` yields `(indent, status_char, name, seq)`. Every note is
   read **whole**, daily and weekly alike. `[exclude] sections` says what to leave out and
   `[exclude] tags` says which task lines are not really tasks; `--all` ignores both for
   one run, and neither lifts the fence.

   **The whitelists are gone.** The reader used to pin a weekly note to one `###` heading
   and, within it, to a ladder of day markers spelled into the source — `promissum`,
   `sunday`…`saturday`, `future` — with the argument that a template gains sections over
   time and a whitelist is safer than a blacklist. The argument was sound about the risk
   and wrong about the remedy: it made every section name a fact in the code, so a plan
   parked under a heading this file had never heard of was unreachable however the config
   was written. **No section name appears anywhere in the script now.**

   What survives of the ladder is `only_days`, and only to answer `-W <date>`: which
   weekday's allocation. Which lines are markers comes from `[days]`, a **literal** per
   weekday supplied by the vault, matched against the whole stripped line and anchored
   at both ends — so a marker must be alone on its line. `{date}` is the one placeholder
   and stands for an ISO date; everything else means itself. With no `[days]` configured
   nothing opens a day, so `-W` on a date reads empty — the honest answer for a vault
   that does not allocate tasks to days.

   **Markers are looked for in the weekly note and nowhere else.** `WEEKLY_KW` is the
   only kwarg table that carries `day_patterns`; a daily note gets `NOTE_KW`, which does
   not. A daily note carries its date in its filename and nothing inside it allocates a
   day, so a marker found there could only ever be a false one — 240 of them in this
   vault, back when `day_patterns` rode on every `parse_note` call.

   **And a task line is never a marker**, whatever it says: `parse_note` tests `TASK_RE`
   first. These were globs until `tdiff` reported `do blood screening` as deleted from a
   project it had never left — `**saturday**` is `*saturday*` to a glob, so
   `- [ ] do blood screening – will complete saturday or next week` was consumed as a
   marker and the task never yielded. 22 tasks were lost that way across this vault.

3. **Group** — `build_groups()` folds flat records into project groups. A top-level
   `[p]`/`[i]`/`[u]` opens a group; indented tasks are its children. Groups **merge**
   across the note case-insensitively (a note may write both `[[Project Alpha]]` and
   `[[project alpha]]`), because block markers are hidden and five identical headers
   would be noise.

4. **Dedup** — `tn.cluster_records()` and `tn.materialize()`, which now reduces a cluster
   by **`[dedup]` priority**, tie-broken by page position.

   **A cluster is now exact.** `cluster_records()` groups by name, case-folded, and
   nothing else. It used to run union-find over two heuristics — equal token sets, or a
   strict token-subset sharing a first word — which over this vault made 221 merges
   including `purchase coffee` swallowing `purchase new coffee grinder` and `essay`
   swallowing `essay planning`. No threshold separates those from the routine merges
   they look exactly like, so the rule went rather than being tuned. See `tdiff`'s
   CLAUDE.md, **Deduplicate**, for the measurements.

   `dedup()` carries the cluster's members out alongside the winner — every occurrence's
   status char in page order — because that is what `--dupes` reports, and because the
   cluster is already in hand. Recovering it later would mean a second clustering pass
   that could disagree with this one about what a duplicate is. `--dupes` then drops every
   row whose occurrence list has one entry, **per scope**, so "duplicated" and "collapsed"
   name the same thing: a task under two projects is two scopes and stays two rows. The
   count includes occurrences the `hide`/`-I`/`-S` filters would drop, since those run
   after dedup.

   **This changed, and it is the one place `tcat`'s output moved for a reason other than
   the fence.** `tcat` used to take the last occurrence in page order outright — the
   reasonable-sounding rule that the latest statement is the current one. It was also the
   single most important divergence from `tdiff`, and precisely the disagreement the
   vendored check could not see, because it never covered `materialize`: one vault, two
   tools, two statuses for the same task. Priority is the better rule anyway — "done" is
   the truest thing you can say about a task also written `[/]` on Tuesday, whichever line
   came last — and page order survives as the tie-break, so within one note nothing
   changes.

5. **Sort & render** — `order_rows()` at every level: `(display_rank, name.lower())`,
   and nothing else. Output is always grouped and always in that order — `--flat` and
   `--order` are both gone, and neither should come back as a flag. `--flat`'s stated
   purpose ("the task set `tdiff` sees") stopped being true when `tdiff` started grouping
   by project too, and it carried a second dedup scoping rule that made its counts
   legitimately differ from the grouped view. `--order` had three modes of which one
   (`alpha`) was indistinguishable from the default without a config, and one (`page`)
   forced a page position through the whole pipeline to serve only itself. Every sort in
   the output path goes through `order_rows()`, so the levels can't drift apart the way
   `--flat`'s private alphabetical sort silently had. `row()` colours the status marker
   only, except for `FULL_ROW` statuses (`x`, `-`) which take the colour across the whole
   line; `footer()` emits the single context line, always `contents · mode · file(s)`.
   `dup_trail()` appends `--dupes`'s `×n` and occurrence statuses, dim and after the name:
   the row is still the answer, the trail is only why it survived the filter. It names no
   note — a week drops day attribution everywhere else, and for the same reason here. In
   the footer `--dupes` changes the noun in `contents` and nothing else, because `mode`
   names what was *read* and a filter is not a different read.

6. **Read plan** — one ordered list of `(note, parse kwargs)` built from the scope the
   positional named and the source `-D`/`-W` asked for, consumed by one loop. It is the
   only place that decides what an invocation opens. `build_groups()` takes the records
   **grouped per note**, so a project header left open at the end of one note cannot adopt
   the indented tasks at the start of the next — a real hazard once a week read opens
   eight notes, and one the old flat-stream `-A` was already exposed to.

## Sharing with `tdiff`: `tnotes`

Everything both tools need lives in **`tnotes`** (`~/Projects/tnotes/tnotes.py`),
symlinked to `~/.local/lib/tnotes.py` the same way both scripts are symlinked into
`~/.local/bin/`. No packaging, no install step; `tcat` puts that directory on
`sys.path` and imports, reporting a missing symlink in a sentence rather than as a bare
`ImportError`:

```python
sys.path.insert(0, str(Path.home() / '.local' / 'lib'))
import tnotes as tn
tn.init('tcat')
```

**This replaced vendoring, and the history is the argument for it.** `tcat` used to
carry a marked copy of `tdiff`'s task core with a pinned commit hash, verified by
`tools/check-core-sync.sh`. It failed the way vendoring always does: the pin went stale
(`92f195c`, two `tdiff` commits behind at the end), `parse_note` and `clean_text`
drifted, and the check *never covered `materialize` or `load_config` at all* — so the
two tools quietly disagreed about which status a deduped task carries and about what a
missing config means. **The check script is deleted.** The drift it existed to catch
cannot occur.

`tnotes` owns: name normalisation (`clean_text` and friends, plus the print-time
`display_text`), `parse_note` and its
regexes, the whole vault reader (`obsidian_lines`, `prefetch`, `die`, the stall
handling), config loading, the date core, and `cluster_records`/`materialize`. `tcat`
keeps what is its own: `build_groups`, `dedup`, the theme machinery, rendering, the
footer, and argparse.

**`display_text` is normalisation's print-time half, and calling it anywhere else is a
bug.** It collapses an aliased wikilink to its alias in a *single* bracket
(`[[…bodner ⟦book⟧.pdf|learning go (5/15) – functions]]` → `[learning go (5/15) –
functions]`) and leaves an unaliased one alone. The alias is the vault already saying in
its own words what the target is, and the target is the long half — a reading list
printed as a wall of identical PDF filenames is what prompted this. One bracket because
the printed text is no longer a link; a double bracket therefore means the name really
is the link. But an alias is display text and two notes may share one, which is exactly
why `normalize_wikilinks` keeps the target: collapsing before `dedup` would claim two
tasks are one. `row()` is the only caller here, `render()` and the project header in
`tdiff`, and `--json` reports the canonical name.

**Where the two tools genuinely differ, the difference is now a parameter rather than
two copies of a function:**

- **`tn.init(tool)`** names the caller, so every message the module writes is prefixed
  correctly and `config_paths()` finds `tcat.toml` and `$TCAT_CONFIG`. The environment
  variables are the *module's* — `TNOTES_WORKERS`, `TNOTES_TIMEOUT`, `TNOTES_DEBUG`,
  replacing the `TCAT_*` spellings — because they are read at import, before `init()`
  has been called.
- **`tn.load_config(…, required=False)`** is what makes no config survivable here.
  `tdiff` passes `True`: an empty `PROJECT_STATUSES` leaks project headers into every
  diff, so it cannot degrade. `tcat` runs unranked and uncoloured and says so.
- **`tn.resolve_date` raises `tn.DateError`** instead of calling `parser.error`. That
  call is exactly why the function used to sit outside the vendored block and drift: the
  message belongs to the caller's argument parser, the one thing a shared module cannot
  own. A four-line local wrapper catches it.
- **`parse_note` takes `only_days` as well as `skip_days`.** `tcat -W <date>` wants one
  weekday's allocation; `tdiff` wants everything up to an anchor. Both are the caller's
  to supply, so neither is a whitelist the module holds.
- **`tn.status_char()`** reads a status whether the caller stores `'x'` or `'[x]'`.
  `tdiff` brackets and `tcat` does not; that is a rendering choice each made, and a
  shared dedup should not have an opinion about it.


## Config

`tn.load_config()` does the work; this section is what `tcat` asks of it.

**Layered, lowest precedence first** — every source *merges* over the ones below it,
including `$TCAT_CONFIG` and `--config`:

1. `~/.config/tconfig/notation.toml` — how the vault writes things: `[exclude]`, `[days]`, `[comment]`, `[vault]`
2. `~/.config/tconfig/statuses.toml` — what the statuses mean: `[order]`, `[dedup]`, `[roles]`, `[theme.*]`
3. `~/.config/tconfig/tcat.toml` — tcat-only overrides
4. `$TCAT_CONFIG`
5. `--config`

`$TCONFIG_DIR` relocates the folder. If `tconfig/` holds none of the first three, the
pre-`tconfig` layout — `~/.config/obsidian-tasks/statuses.toml` and
`~/.config/tcat/config.toml` — is read instead with one notice naming the new home. That
is a fallback for the first run after the move, not a layer: a `tconfig/` that exists
wins outright.

**The folder is split by concern, not by tool.** That is the axis along which a file
actually changes — you rewrite `notation.toml` when you change how you write a note, and
`statuses.toml` when a status changes meaning. Splitting by tool would have meant writing
the same section twice and letting the two copies drift, which is the vendoring mistake in
config form.

**There is no built-in layer, and nothing is ever bootstrapped.** `BUILTIN_ORDER` was
deleted deliberately: inventing a fallback rank table is exactly how the old build ended
up sorting by ranks nobody had chosen (`~/.config/tcat/config.toml` didn't exist, so it
silently fell back to `tdiff`'s config, which has no `order` key at all, so every rank came
from code). With no config `tcat` runs unranked and uncoloured and says so via `notice()`.
Don't reintroduce a default table in Python — the defaults belong in
`statuses.example.toml`, which the user owns and edits.

**The folder sits outside both tool directories on purpose.** It describes the *vault*,
not either tool, so `tconfig/` is a directory neither owns — which is what lets the two
share it while neither depends on the other being installed. The split:

| key | read by |
|---|---|
| `[theme.*]` colours, `[roles].full_row` | `tcat` |
| `[exclude]`, `[days]`, `[comment]`, `[order]`, `[dedup]`, `[roles]` `project`/`hide`/`settled`, `[vault]` | **both** |

`[dedup]` is new to `tcat` here — see **Architecture** step 4. `[exclude]` and `[days]`
are too: this file used to read neither, because the whitelists in `parse_note` did that
job in code.

`[order]` and `[dedup]` are deliberately *not* one key. They run opposite ways: `[order]`
sorts `x` last (finished work belongs at the bottom), `[dedup]` ranks `x` first ("done" is
the truest thing you can say about a task also written `[/]` on Tuesday). A flat list also
can't express ties, and `[dedup]` has three.

**The example files ship once, from `tnotes`** — `notation.example.toml` and
`statuses.example.toml`. Neither tool carries a copy any more, so there is no pair to keep
byte-identical and no check to forget. `tcat.example.toml` here documents the overlay
only.

**Order is a list, not integer ranks.** `[order].statuses` is an ordered list; rank is
position. Ties are therefore inexpressible (the old table had three) and reordering is a
move rather than a renumbering. Statuses absent from it get `UNRANKED`, sort last, render
uncoloured, and are named once on stderr by `report_unlisted()`.

Other keys: `[roles]` `project` / `hide` / `settled` / `full_row`, `[theme.dark]` /
`[theme.light]` (24-bit hex), `[exclude]` `sections` / `tags`, `[days]` `sunday`..`saturday`,
`[comment]` `separators`, `[vault]` folders. Theme choice: `$TCAT_THEME` → `COLORFGBG` → dark. Lists replace
wholesale; only tables merge (`tn._merge()`).

## Key behaviours

| Behaviour | Note |
|---|---|
| Weekday names resolve **backwards** | `tuesday` = most recent Tuesday at or before today. A future weekday has no tasks yet. |
| Future date without `-W` | Hard error — the daily note won't exist. A `w##` or `-W` may look forward freely: the weekly note is often written ahead of the week. |
| `&` `»` `«` hidden | Filtered **after** dedup, so an earlier `[»]` never suppresses a later `[x]`. `-S` overrides. |
| `-I` hides `[roles].settled` | Boolean, like `tdiff`'s — *not* a char list; `-S` already covers that axis. Three filters compose (`hide`, `-I`, `-S`) under one rule: **a positive `-S` wins for the statuses it names**, so `-I -S x` shows done tasks rather than nothing. A negated `-S` names only what to drop, so `-I` still applies to the rest. No built-in set: unconfigured `-I` hides nothing and says so, like `[order].statuses`. |
| `settled` is not `full_row` | They hold the same two chars by default and are still separate keys: `full_row` says how a row is *painted*, `settled` whether it is *there*. Welding them would make a colour edit silently change which tasks you see. |
| Empty is never an error | Exit 0, one dim `nothing to show`, whatever the cause. `-v` and the eleven per-reason strings were removed deliberately; don't reinstate them. |
| Dedup is **scoped**, not global | Each project's children collapse among themselves; bare top-level tasks collapse among themselves as one further scope. The scopes never merge, so a task under two projects keeps a row under each, and a bare occurrence never swallows a project's copy. Until July 2026 the bare scope was skipped entirely: `build_groups()` dropped `seq` for bare rows and the render loop `continue`d past `dedup()`, so top-level duplicates printed twice. Both halves of that fix have to stay — the `seq` is what lets `materialize()` pick a winner. |
| Dedup spans the whole read | A task on Monday restated on Friday collapses to one row, and `[dedup]` priority picks its status. `seq` is still **offset to keep climbing between notes** — `tn.parse_note()` restarts it at 1 per call — because it is the tie-break within a priority tier; drop the offset and "later in the read" silently becomes "later in whichever note". |
| `--dupes` filters, it doesn't compare | Only the rows dedup collapsed, each with `×n` and every occurrence's status in page order. Same scoping as dedup, so a task under two projects is two rows and neither is a duplicate. In `--json` the row gains `count` and `statuses` **only** under the flag — otherwise every row would carry a `count` of 1 — and the payload gains `dupes`. `mode` still names the read. |
| A week drops day attribution | Deliberate. `tcat w34` answers *what is in this week*, not *when* — a by-day layout was considered and rejected. `weekday` is `null` in JSON for any week form. No labels, no by-day layout. |
| Every note is read whole | Daily and weekly alike, whether read alone or folded into a week. `[exclude] sections` is the only thing that leaves a section out, and it applies everywhere. A week read used to drop a named deferred-work section from each daily, which hardcoded both that such a section exists and what it means. |
| Colour is marker-only | The whole `[x]` marker, brackets included — tinting only the inner char was tried in July 2026 and reverted; it reads as half-lit. Except `FULL_ROW` (`x`, `-`), which colour the whole row. Two signals: grey marker = deprioritised but open, grey line = settled. |
| Footer is always three fields | `contents · mode · file(s)`. Projects fold into `contents` rather than taking a field. `--no-summary` drops the whole line, date included. |
| The file field names what was read | So `-W` on a date shows the weekly note, not the invoked day; a week names the label plus `(n/7 dailies)`, and `, weekly` too when the weekly note was one of the sources. |

## Known gaps

`README.md` is a user's guide now, not a second copy of this file: it says what the tool
does and how to configure it, and every *argument* for why lives here. Keep it that way —
when behaviour changes, the guide gets the new fact and this file gets the reasoning.

### Weeks across a year boundary — FIXED July 2026, joint with `tdiff`

**A week is labelled by the year it *ends* in.** Week 1 is the week containing Jan 1, so
Sun 2026-12-27 → Sat 2027-01-02 is `2027-W01`, matching the templates' moment `gggg[-W]ww`.
`week_span()` anchors both its label and its Jan-1 reference on the **Saturday**; anchoring
on the Sunday (as it did until this fix) produced `2026-W53` — a file that never exists —
and made the vault's real `2027-W01` unaddressable by name.

Only the straddling week per year ever differed, which is why it stayed invisible: verified
over 2020–2035, exactly 13 weeks change label, all of the form `YYYY-W53` → `YYYY+1-W01`
(the old rule even invented a `2028-W54`). `_week_label_to_sunday()` was always correct and
was **not** changed; label → Sunday → label round-trips under both rules, which is precisely
why the bug was silent.

The fix landed in `tdiff@e2976c0` first and then here, at a time when the week functions
were vendored in both files and had to move together. They live in `tnotes` now, so this
class of joint fix has stopped existing. Two consequences worth keeping:

- **The phantom guard is `tcat`-only** and lives at the week-selection call site, not in
  the module. `w2026-W53` still resolves to a real Sunday, so it is caught by
  round-tripping the label through `week_span()` and rejected with a suggestion. Without it
  a user naming a plausible-but-nonexistent week gets silently wrong output.
- `resolve_week_label('w01')` still stamps `date.today().year`, so a bare `w1` typed in late
  December names *this* year's week 1, not the one about to start. Pre-existing, unrelated
  to this fix, and arguably correct — noted so it isn't mistaken for a regression.

Still outstanding: there is no test suite.

## Style

Match `tdiff`: `# ── Section ─…` banner comments, argparse with a `__NEG__` interception
for bare negative numbers, colour gated on `sys.stdout.isatty()`, summary line suppressed
by `--no-summary`.
