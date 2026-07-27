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
   carries the coming week's whole plan inside a fence. `-A` drops `**future**` (20 of them
   in that note) which removes the largest slice; the rest is a documented known gap.
   Do **not** "fix" it with fence tracking — see finding 4.

9. **The `obsidian` CLI intermittently wedges.** A read that normally takes ~10 ms
   occasionally hangs for minutes. Observed directly while building `-A`. It also **drains
   stdin**, so every call needs `stdin=DEVNULL` or `tcat` eats its caller's input. Both are
   handled in `_read_uncached()` (cap, retry, skip) — the same reasons `tdiff` guards its
   calls. Don't remove either.

10. **A `future` block can contain its own ladder markers.** One note's future fence
   carried `**sunday**` and `**other**` inside it. Once inside `**future**`, the parser stays there — it
   never re-enters the day ladder.

## What this project does

`tcat` is a single-file Python CLI that shows **one day's tasks** — from that day's daily
note (`<YYYY-MM-DD>`) or, with `-P`, from the weekly note's (`YYYY-W##`) Actio allocation
for that weekday. Two flags widen the lens to the week without changing what the tool is
for: `-A` merges a whole week into one list — the seven daily notes, or with `-P` the
weekly Actio plan — and `--missio` prints the weekly note's mission prose.

**`-A` mirrors the existing polarity, and that is the whole point.** Bare date = actual,
`-P` = plan; `-A` = actual week, `-A -P` = planned week. An earlier draft made `-A`
plan-only; that was wrong and was corrected before release. Don't re-collapse it.

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
python3 tcat -P 2026-01-07 --no-color      # pre-ladder week, empty
python3 tcat 2026-03-04 --json
python3 tcat -A --no-color                 # the week actually done, merged
python3 tcat -A -P --no-color              # the week as planned
python3 tcat -A w30 --no-color             # a week by number
python3 tcat -A -w -1 --flat --json        # last week
python3 tcat --missio --no-color           # the week's mission, verbatim
python3 tcat 2026-06-10 --missio           # a week with no Missio section
```

No test suite — testing is manual via CLI invocation, as in `tdiff`.

## Architecture

One executable file: `tcat`. Pipeline:

1. **Read** — `read_note()` shells out to `obsidian read file=<name>`, returns lines or
   `None`. See finding 5 about the missing-file detection, and finding 9 for the timeout,
   retry and `stdin=DEVNULL` guards. Results are memoised; `prefetch()` warms several notes
   at once through a 4-worker pool (`TCAT_WORKERS`) and is called only by `-A`, so
   single-note modes cost exactly what they always did.

   `survey_region()` used to sit here, existing only to tell empty results apart for `-v`.
   Both are gone — see **Key behaviours**.

2. **Parse** — `parse_note()` yields `(indent, status_char, name, seq)`. Fence-agnostic
   (finding 4). In weekly mode it filters to `region='actio'` and a ladder day; in daily
   mode it yields everything. `day=` takes one marker name **or a tuple** of them —
   `-A` passes `WEEK_DAYS`, which is why the whole week is one pass and not seven.
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

5. **Sort & render** — `(STATUS_ORDER rank, name.lower())` at every level. `--flat` drops
   project parents and sorts alphabetically only. `row()` colours the status marker only,
   except for `FULL_ROW` statuses (`x`, `-`) which take the colour across the whole line;
   `footer()` emits the single context line, always `contents · mode · file(s)`.

## Vendored core

The block between `# ── Vendored task core` and `# ── End vendored core` is copied
verbatim from `tdiff` at pinned commit **`1e7f11c`**: `strip_section_suffix`,
`WIKILINK_RE`/`_strip_wiki_path`/`normalize_wikilinks`, `_PUNCT`/`_tokens`/`is_same_task`,
`cluster_records`, `week_span`, `_SEP_RE`, and the week-selection set
`resolve_week_label`/`_week_label_to_sunday`/`_WEEK_SHORT_RE`/`_WEEK_FULL_RE`.

Vendoring beats a shared module: two files on `$PATH` with no install step is the
deployment model. Keep it honest with:

```bash
tools/check-core-sync.sh [path-to-tdiff-repo]   # exit 1 on any drift
```

`materialize` is deliberately **not** checked — see pipeline step 4. If you change
anything inside the vendored block, either revert it or move it out of the block and
document why.

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
the other being installed. Each ignores the other's keys — `tcat` reads `[order]`,
`[theme.*]`, `[roles]`; `tdiff` reads `priority`/`ignore` — so they cannot drift.

**Order is a list, not integer ranks.** `[order].statuses` is an ordered list; rank is
position. Ties are therefore inexpressible (the old table had three) and reordering is a
move rather than a renumbering. Statuses absent from it get `UNRANKED`, sort last, render
uncoloured, and are named once on stderr by `report_unlisted()`.

Other keys: `[roles]` `project` / `hide` / `full_row`, `[theme.dark]` / `[theme.light]`
(24-bit hex), `[vault]` folders. Theme choice: `$TCAT_THEME` → `COLORFGBG` → dark.
Lists replace wholesale; only tables merge (`_merge()`).

## Key behaviours

| Behaviour | Note |
|---|---|
| Weekday names resolve **backwards** | `tuesday` = most recent Tuesday at or before today. A future weekday has no tasks yet. |
| Future date without `-P` | Hard error — the daily note won't exist. |
| `&` `»` `«` hidden | Filtered **after** dedup, so an earlier `[»]` never suppresses a later `[x]`. `-S` overrides. |
| Empty is never an error | Exit 0, one dim `nothing to show`, whatever the cause. `-v` and the eleven per-reason strings were removed deliberately; don't reinstate them. |
| Fixa, `future`, `promissum` | Parsed as ladder markers so they can't leak into a day, but **not exposed** — including under `-A`. v1 is Actio days only. |
| `-A` dedup spans the week | A task on Monday restated on Friday collapses to one row with Friday's status. Falls out of `materialize()`'s last-occurrence rule — but only because the seven notes are read in date order and `seq` is **offset to keep climbing between notes**. `parse_note()` restarts `seq` at 0 per call; drop the offset and "last in page order" silently becomes "last in whichever note". |
| `-A` drops day attribution | Deliberate. It answers *what happened this week*, not *when* — a by-day layout was considered and rejected. The date picks the week, the weekday is ignored, and `weekday` is `null` in JSON. |
| `-A` drops `**future**` | Via `parse_note(skip_future=True)`, which **only** `-A` passes. Single-day output still shows future buckets, unchanged. See finding 8. |
| `-A` never reads the weekly note | Dailies only. That is why `tcat` has no `-W/--no-weekly`: unlike `tdiff`, plan and actual never share an aggregate, so there is nothing to switch off. |
| Colour is marker-only | Except `FULL_ROW` (`x`, `-`), which colour the whole row. Two signals: grey marker = deprioritised but open, grey line = settled. |
| Footer is always three fields | `contents · mode · file(s)`, in every mode including `--missio` (whose `contents` is the literal `text`). Projects fold into `contents` rather than taking a field. `--no-summary` drops the whole line, date included. |
| The file field names what was read | So `-P` shows the weekly note, not the invoked day; `-A` names the week plus `(n/7 dailies)` because it never opens the weekly note. |
| `--missio` is verbatim | No link cleaning, no comment stripping, no `strip_section_suffix()`. It's prose, not a task name. Standalone: exits before any task machinery runs, so `-P`/`-f`/`-S`/`--routines`/`-A` are ignored. |
| `--missio` JSON is minimal | Exactly `{"week", "missio"}` — deliberately *not* the task envelope. `missio` is `null` for missing note, missing heading, or empty body. |

### The plan flag is `-P`, not `-w`

Deliberate, and not an oversight to be "corrected" toward `tdiff`. In `tdiff`,
`-W/--no-weekly` means *exclude* the weekly file; in `tcat` the same letter would mean
*use* it — the same object with opposite polarity, across two tools run side by side.
`-P/--plan` collides with neither and matches how the weekly Actio allocation is actually
described. Don't rename it to `-w` or `-W`.

**The whole-week flag is `-A`, not `-W`, for the same reason.** `-W` reads as the obvious
letter in isolation, but it already means *exclude the weekly note* in `tdiff` — the exact
opposite polarity, on two tools run side by side. `-A/--all-week` collides with nothing.

**`-w` and `w##`, however, are copied from `tdiff` exactly.** Week *selection* has no
polarity problem, so the two tools should take identical arguments: `w30` / `w2026-W30` as
the positional, `-w N` as a relative offset. `resolve_week_label`, `_week_label_to_sunday`
and both week regexes are vendored verbatim and covered by `tools/check-core-sync.sh`.
Note `-w` is an **offset**, not a week number — that is `tdiff`'s meaning and it stays.
One divergence: `tdiff -w 0` excludes the anchor from its own week because it is diffing;
`tcat` isn't, so `-w 0` is simply the anchor's week.

## Known gaps

See the **Known gaps** section of `README.md`.

### Outstanding: weeks across a year boundary — STILL BROKEN, fix before December 2026

`week_span()` disagrees with the templates' moment `gggg[-W]ww` for the one week that
straddles a New Year: Sun 2026-12-27 → Sat 2027-01-02 is `2027-W01` in the vault and
`2026-W53` here. Every other week of the year agrees.

Week selection made this worse, not better, and it is the reason to prioritise the fix:

- `-A` survives — the seven dates are right whatever the label says; only the header lies.
- `-A -P` and `--missio` look for a note that doesn't exist and say "no note found".
- **`w2027-W01` is silently wrong.** `_week_label_to_sunday('2027-W01')` gives Sun
  2026-12-27, which `week_span()` then relabels `2026-W53`. The user names a real week and
  gets a phantom, with no error. The vault's actual `2027-W01` cannot be addressed by name.

The fix is **joint with `tdiff`** and must stay joint: `week_span`, `resolve_week_label`
and `_week_label_to_sunday` are all vendored, so patching `tcat` alone would make the two
tools disagree about which note to read — worse than the current shared wrongness. Do not
"fix" it here in isolation, and do not let `tools/check-core-sync.sh` be the thing that
discovers it.

Also outstanding: the Mensis exclusion is unverified (the vault holds no such note), the
pre-`2026-W20` Sunday contamination under `-A` (finding 8), and there is no test suite.

## Style

Match `tdiff`: `# ── Section ─…` banner comments, argparse with a `__NEG__` interception
for bare negative numbers, colour gated on `sys.stdout.isatty()`, summary line suppressed
by `--no-summary`.
