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
   list with no `**day**` markers (two such notes in testing held 36 and 46 tasks). `-W`
   correctly returns nothing for a specific day, and says only `nothing to show` — the
   distinct explanation `-v` used to give was removed along with the flag.

7. **`### *Missio*` is unfenced prose.** It sits under `## *Prospectus*`, immediately
   before `### *Actio*`, and holds paragraphs (sometimes a bullet list), not tasks.
   Verified across every weekly note in the vault (`2026-W20`…`2026-W31`): present in 9,
   **absent in W24–W26**, and no weekly note exists before W20 — the weekly structure lived
   in the Sunday daily note back then. So a missing Missio is a normal state, never a parse
   failure. `extract_section()` is fence-agnostic for the same reason `parse_note()` is, and
   it is safe here because every fenced block lives under `## *Recensio*` or `### *Fixa*`.

8. **Daily notes are ~6 of 7 per week, and pre-`2026-W20` Sundays are contaminated.**
   Measured over the last eight full weeks: 7,6,5,4,7,5,7,7 notes. A week aggregator must
   treat a missing day as ordinary, never an error. Worse, before W20 the weekly structure
   lived inside the Sunday daily — `tcat 2026-05-17` returns **90 tasks** because that note
   carries the coming week's whole plan inside a fence. A week read drops `**future**` (20 of
   them in that note) which removes the largest slice; the rest is a documented known gap.
   Do **not** "fix" it with fence tracking — see finding 4.

9. **The `obsidian` CLI intermittently wedges.** A read that normally takes ~10 ms
   occasionally hangs for minutes. Observed directly while building the week aggregation. It also **drains
   stdin**, so every call needs `stdin=DEVNULL` or `tcat` eats its caller's input. Both are
   handled in `_read_uncached()` (cap, retry, skip) — the same reasons `tdiff` guards its
   calls. Don't remove either.

10. **A `future` block can contain its own ladder markers.** One note's future fence
   carried `**sunday**` and `**other**` inside it. Once inside `**future**`, the parser stays there — it
   never re-enters the day ladder.

## What this project does

`tcat` is a single-file Python CLI that shows **what is in a note**: one day's tasks, or
one week's. `--missio` prints the weekly note's mission prose instead.

**The grammar is one sentence, and it is tdiff's: a date names a day, a `w##` names a
week, and a week has two sources you narrow with `-D`/`-W`.** The positional picks the
scope, the flags pick the source.

| invocation | reads |
|---|---|
| `tcat today` / `tcat today -D` | that day's daily note |
| `tcat today -W` | the weekly note's Actio allocation for that weekday |
| `tcat w34` | the whole week, both sources merged and deduped |
| `tcat w34 -D` | the week's seven daily notes |
| `tcat w34 -W` | the week's Actio plan, whole |

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

**The seam now lives entirely inside `tdiff`, and `tcat` owes it nothing.** Plan-vs-actual
is `tdiff today -W`: tdiff reads the weekly note's Actio section itself now, so it no
longer needs tcat to hand it a task set. `tdiff -E`, which used to take shell commands as
its two sides, was deleted in `596020d` — and with it the only consumer of tcat's nested
`--json` envelope. That envelope is now flat `rows` in tdiff's shape, and nothing parses
it; earlier docs here said to freeze it "because `tdiff` parses it", which stopped being
true and is the reason the shape was free to change.

External dependencies: `obsidian` CLI (`read` subcommand only). Requires Python 3.11+
(stdlib `tomllib`). No `rg` — unlike `tdiff`, `tcat` parses note source directly.

## Running

```bash
tcat [date|w##] [flags]            # no build step

python3 tcat 2026-03-04 --no-color
python3 tcat tuesday -W --no-color         # tuesday's allocation in the weekly plan
python3 tcat 2026-01-07 -W --no-color      # pre-ladder week, empty
python3 tcat 2026-03-04 --json
python3 tcat w30 --no-color                # a week, both sources merged
python3 tcat w30 -D --no-color             # the week actually done
python3 tcat w30 -W --no-color             # the week as planned
python3 tcat w0 --no-color                 # this week
python3 tcat w-1 -D --json                 # last week's dailies
python3 tcat --missio --no-color           # the week's mission, verbatim
python3 tcat 2026-06-10 --missio           # a week with no Missio section
```

No test suite — testing is manual via CLI invocation, as in `tdiff`.

## Architecture

One executable file: `tcat`. Pipeline:

1. **Read** — `read_note()` shells out to `obsidian read file=<name>`, returns lines or
   `None`. See finding 5 about the missing-file detection, and finding 9 for the timeout,
   retry and `stdin=DEVNULL` guards. Results are memoised; `prefetch()` warms several notes
   at once through a 4-worker pool (`TCAT_WORKERS`). It is now called on every path, since
   the read plan is one list of notes; a single-note run takes the serial branch.

   `survey_region()` used to sit here, existing only to tell empty results apart for `-v`.
   Both are gone — see **Key behaviours**.

2. **Parse** — `parse_note()` yields `(indent, status_char, name, seq)`. Fence-agnostic
   (finding 4). In weekly mode it filters to `region='actio'` and a ladder day; in daily
   mode it yields everything. `day=` takes one marker name **or a tuple** of them —
   a week read passes `(None,) + WEEK_DAYS`, which is why the whole plan is one pass.
   `LADDER` is derived from `WEEK_DAYS` so the two can't drift.
   `extract_section()` is the prose counterpart: it returns one `###` section's body
   verbatim (`None` when the heading is absent, `''` when the body is), and is what
   `--missio` runs on. It deliberately does **not** call `clean_text()`. `clean_text()` un-escapes `\[`/`\]` (the vault writes both
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

6. **Read plan** — one ordered list of `(note, parse kwargs)` built from the scope the
   positional named and the source `-D`/`-W` asked for, consumed by one loop. It is the
   only place that decides what an invocation opens. `build_groups()` takes the records
   **grouped per note**, so a project header left open at the end of one note cannot adopt
   the indented tasks at the start of the next — a real hazard once a week read opens
   eight notes, and one the old flat-stream `-A` was already exposed to.

## Vendored core

The block between `# ── Vendored task core` and `# ── End vendored core` is copied
verbatim from `tdiff` at pinned commit **`92f195c`**. The checked surface is now
**15 functions and 18 constants** — roughly twice what it was, because a large amount of
genuinely shared code was sitting outside the guard:

| group | names |
|---|---|
| task names | `strip_section_suffix`, `clean_text`, `normalize_wikilinks`, `_strip_wiki_path`, `WIKILINK_RE`, `MDLINK_RE`, `_SEP_RE` |
| parsing | `parse_note`, `TASK_RE`, `H2_RE`, `H3_RE`, `MARK_RE`, `WEEK_DAYS`, `LADDER` |
| clustering | `cluster_records`, `_tokens`, `_PUNCT` |
| dates & weeks | `week_span`, `resolve_date`, `resolve_week_label`, `_week_label_to_sunday`, `_WEEK_REL_RE`, `_WEEK_SHORT_RE`, `_WEEK_FULL_RE`, `_ISO_RE`, `_OFF_RE`, `_WEEKDAY_NAMES`, `WEEKDAYS` |
| display & plumbing | `display_rank`, `UNRANKED`, `_xdg_base`, `notice`, `restore` |

**`parse_note` came *from* `tcat`**, but `tdiff` is the canonical side now: it moved off
`obsidian tasks` onto raw markdown in `596020d` and took tcat's parser with it. Both
copies are identical; the pin is what says which one wins a disagreement.

**`clean_text` was the one function that had genuinely drifted**, and reconciling it was a
real fix rather than a formality. `tcat` used to reduce links to their display text
*before* stripping the ` – …` section suffix, which truncated any linked title containing
a dash. Measured on this vault: 106 of 435 names rendered differently, 22 of them losing
text outright. It is now `tdiff`'s: un-escape → `strip_section_suffix` → shorten wikilink
paths, brackets kept → reduce markdown links. Names therefore display as
`read [[2026 mechanica]]`, which is a visible change and the right one.

**`resolve_date` is checked too, but lives outside the block** — in both files, because it
needs `parser` and so has to follow the argument parser. It is vendored all the same: the
promise that `tcat` and `tdiff` take the same date arguments (weekday names, `tomorrow`,
`-N`/`+N`, `w##`, `w-1`) is only true if it cannot drift. `_WEEKDAY_NAMES` and `WEEKDAYS`
are deliberately one-liners, because the script's constant check compares a single
assignment line and a multi-line `WEEKDAYS` would have been checked only on its first.
`UNRANKED` carries no trailing comment in either file for the same reason — `tdiff` moved
its comment to the line above so the two assignment lines match exactly.

One deliberate divergence, and it is in the caller rather than the function: `tcat`
hard-errors on a future date without `-W` (or a `w##`), since the daily note won't exist
yet. `tdiff` accepts it — an empty side is a legitimate diff.

**`is_same_task` is gone** — upstream folded it into `cluster_records`, which now buckets
on the two merge keys instead of scanning all pairs. Same clusters, ~3× faster on `tdiff`'s
inputs and immaterial on `tcat`'s. It came in with the `e2976c0` pin bump rather than
being chosen: the whole block moves together or the sync check goes red. Verified inert
against eleven `--json` captures across five weeks before landing.

Vendoring beats a shared module: two files on `$PATH` with no install step is the
deployment model. Keep it honest with:

```bash
tools/check-core-sync.sh [path-to-tdiff-repo]   # exit 1 on any drift
```

Deliberately **not** checked, and the script says why in a comment: `materialize` (tcat
reduces a cluster by page position, tdiff by `STATUS_PRIORITY` — see pipeline step 4);
`load_config`/`config_paths`/`_merge` (different env var, and tcat survives with no config
where tdiff hard-errors); `die`/`_on_uncaught`/`_obsidian_once`/`_run_obsidian`/`prefetch`/
`flush_notices`/`finish` (each prints the tool's own name); and
`build_groups`/`dedup`/`sort_key`/`order_rows`/`status_match` (tcat-only shape — tdiff
groups inside its own parser). If you change anything inside the vendored block, either
revert it or move it out of the block and document why.

## Config

**Layered, lowest precedence first** — every source *merges* over the ones below it,
including `$TCAT_CONFIG` and `--config`:

1. `~/.config/obsidian-tasks/statuses.toml` — the shared table
2. `~/.config/tcat/config.toml` — tcat-only overlay
3. `$TCAT_CONFIG`
4. `--config`

**There is no built-in layer, and nothing is ever bootstrapped.** `BUILTIN_ORDER` was
deleted deliberately: inventing a fallback rank table is exactly how the old build ended
up sorting by ranks nobody had chosen (`~/.config/tcat/config.toml` didn't exist, so it
silently fell back to `tdiff`'s config, which has no `order` key at all, so every rank came
from code). With no config `tcat` runs unranked and uncoloured and says so via `notice()`.
Don't reintroduce a default table in Python — the defaults belong in
`statuses.example.toml`, which the user owns and edits.

**The shared file sits outside both tool directories on purpose.** The status table
describes the *vault's* notation, not either tool, so `obsidian-tasks/` is a directory
neither owns. That is what lets `tcat` and `tdiff` share one table while neither depends on
the other being installed.

**The sharing is live as of July 2026** — briefly it wasn't, and the file's header claimed
otherwise, which is worth knowing if you meet an older checkout. `tdiff` now layers the same
`obsidian-tasks/statuses.toml` beneath its own config and reads `[roles]` from it. The split:

| key | read by |
|---|---|
| `[order]` display rank, `[theme.*]` colours, `[roles].full_row` | `tcat` |
| `[dedup].priority` tiers | `tdiff` |
| `[roles]` `project` / `hide` / `settled` | **both** |

`[order]` and `[dedup]` are deliberately *not* one key. They run opposite ways: `[order]`
sorts `x` last (finished work belongs at the bottom), `[dedup]` ranks `x` first ("done" is
the truest thing you can say about a task also written `[/]` on Tuesday). A flat list also
can't express ties, and `[dedup]` has three.

**`statuses.example.toml` is byte-identical in both repos, on purpose** — installing either
tool gets the whole table. Keep it that way: `diff` it against `../tdiff/statuses.example.toml`
before committing a change to it. It is the one file with no sync check, because it isn't
code.

**Order is a list, not integer ranks.** `[order].statuses` is an ordered list; rank is
position. Ties are therefore inexpressible (the old table had three) and reordering is a
move rather than a renumbering. Statuses absent from it get `UNRANKED`, sort last, render
uncoloured, and are named once on stderr by `report_unlisted()`.

Other keys: `[roles]` `project` / `hide` / `settled` / `full_row`, `[theme.dark]` / `[theme.light]`
(24-bit hex), `[vault]` folders. Theme choice: `$TCAT_THEME` → `COLORFGBG` → dark.
Lists replace wholesale; only tables merge (`_merge()`).

## Key behaviours

| Behaviour | Note |
|---|---|
| Weekday names resolve **backwards** | `tuesday` = most recent Tuesday at or before today. A future weekday has no tasks yet. |
| Future date without `-W` | Hard error — the daily note won't exist. A `w##` or `-W` may look forward freely: the weekly note is often written ahead of the week. |
| `&` `»` `«` hidden | Filtered **after** dedup, so an earlier `[»]` never suppresses a later `[x]`. `-S` overrides. |
| `-I` hides `[roles].settled` | Boolean, like `tdiff`'s — *not* a char list; `-S` already covers that axis. Three filters compose (`hide`, `-I`, `-S`) under one rule: **a positive `-S` wins for the statuses it names**, so `-I -S x` shows done tasks rather than nothing. A negated `-S` names only what to drop, so `-I` still applies to the rest. No built-in set: unconfigured `-I` hides nothing and says so, like `[order].statuses`. |
| `settled` is not `full_row` | They hold the same two chars by default and are still separate keys: `full_row` says how a row is *painted*, `settled` whether it is *there*. Welding them would make a colour edit silently change which tasks you see. |
| Empty is never an error | Exit 0, one dim `nothing to show`, whatever the cause. `-v` and the eleven per-reason strings were removed deliberately; don't reinstate them. |
| Fixa, `future`, `promissum` | Parsed as ladder markers so they can't leak into a day, but **not exposed** — including under a week read. v1 is Actio days only. |
| Dedup is **scoped**, not global | Each project's children collapse among themselves; bare top-level tasks collapse among themselves as one further scope. The scopes never merge, so a task under two projects keeps a row under each, and a bare occurrence never swallows a project's copy. Until July 2026 the bare scope was skipped entirely: `build_groups()` dropped `seq` for bare rows and the render loop `continue`d past `dedup()`, so top-level duplicates printed twice. Both halves of that fix have to stay — the `seq` is what lets `materialize()` pick a winner. |
| Dedup spans the whole read | A task on Monday restated on Friday collapses to one row with Friday's status. Falls out of `materialize()`'s last-occurrence rule — but only because the notes are read in order and `seq` is **offset to keep climbing between them**. `parse_note()` restarts `seq` at 1 per call; drop the offset and "last in page order" silently becomes "last in whichever note". Under a bare `w##` the weekly note is read **first**, which is what makes every daily's status beat the plan's. |
| A week drops day attribution | Deliberate. `tcat w34` answers *what is in this week*, not *when* — a by-day layout was considered and rejected. `weekday` is `null` in JSON for any week form. No labels, no by-day layout. |
| A week drops `**future**` | Via `parse_note(skip_future=True)`, passed only for a daily note read *as part of a week*. A day read on its own still shows its future bucket — deferring something is part of that day. See finding 8. |
| Colour is marker-only | The whole `[x]` marker, brackets included — tinting only the inner char was tried in July 2026 and reverted; it reads as half-lit. Except `FULL_ROW` (`x`, `-`), which colour the whole row. Two signals: grey marker = deprioritised but open, grey line = settled. |
| Footer is always three fields | `contents · mode · file(s)`, in every mode including `--missio` (whose `contents` is the literal `text`). Projects fold into `contents` rather than taking a field. `--no-summary` drops the whole line, date included. |
| The file field names what was read | So `-W` on a date shows the weekly note, not the invoked day; a week names the label plus `(n/7 dailies)`, and `, weekly` too when the weekly note was one of the sources. |
| `--missio` is verbatim | No link cleaning, no comment stripping, no `strip_section_suffix()`. It's prose, not a task name. Standalone: exits before any task machinery runs, so `-S`/`-I`/`--routines` are ignored — but `-D`/`-W` are **rejected**, since --missio already reads the weekly note and they would have nothing to narrow. |
| `--missio` JSON is minimal | Exactly `{"week", "missio"}` — deliberately *not* the task envelope. `missio` is `null` for missing note, missing heading, or empty body. |

## Known gaps

See the **Known gaps** section of `README.md`.

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

The fix landed in `tdiff@e2976c0` first, then here with the pin bump — it must stay joint,
since all three week functions are vendored. Two consequences worth keeping:

- **The phantom guard is `tcat`-only** and lives at the week-selection call site, not in the
  vendored block. `w2026-W53` still resolves to a real Sunday, so it is caught by
  round-tripping the label through `week_span()` and rejected with a suggestion. Without it
  a user naming a plausible-but-nonexistent week gets silently wrong output.
- `resolve_week_label('w01')` still stamps `date.today().year`, so a bare `w1` typed in late
  December names *this* year's week 1, not the one about to start. Pre-existing, unrelated
  to this fix, and arguably correct — noted so it isn't mistaken for a regression.

Still outstanding: the Mensis exclusion is unverified (the vault holds no such note), the
pre-`2026-W20` Sunday contamination under `w## -D` (finding 8), and there is no test suite.

## Style

Match `tdiff`: `# ── Section ─…` banner comments, argparse with a `__NEG__` interception
for bare negative numbers, colour gated on `sys.stdout.isatty()`, summary line suppressed
by `--no-summary`.
