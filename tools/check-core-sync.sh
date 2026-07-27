#!/usr/bin/env bash
# Verify tcat's vendored task core still matches tdiff's source at the pinned commit.
#
# tcat vendors a block of tdiff rather than importing it: two files on $PATH with no
# install step is the deployment model. Vendoring only stays honest if drift is loud,
# which is what this script is for.
#
# Usage:  tools/check-core-sync.sh [path-to-tdiff-repo]
# Exit:   0 identical, 1 drifted, 2 could not check.

set -uo pipefail

PIN='123b5b1'
TDIFF_REPO="${1:-$HOME/Projects/tdiff}"
TCAT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tcat"

BEGIN='# ── Vendored task core'
END='# ── End vendored core'

die() { echo "check-core-sync: $*" >&2; exit 2; }

[ -f "$TCAT" ]                || die "no tcat at $TCAT"
[ -d "$TDIFF_REPO/.git" ]     || die "no tdiff git repo at $TDIFF_REPO (pass its path as \$1)"

# The functions vendored verbatim. `materialize` is deliberately NOT here: tcat
# reduces a cluster by page position, tdiff by STATUS_PRIORITY.
#
# `resolve_date` lives outside the marked block in both files — it needs `parser`,
# so it has to sit after the argument parser — but it is checked all the same. The
# two tools promising the same date arguments is only true if it cannot drift.
FUNCS=(
  strip_section_suffix
  _strip_wiki_path
  normalize_wikilinks
  _tokens
  cluster_records
  week_span
  resolve_week_label
  _week_label_to_sunday
  resolve_date
)

extract() {
  # extract <file> <name> — print a top-level def and its body.
  awk -v name="$2" '
    $0 ~ "^def " name "\\(" { inside=1; print; next }
    inside && /^[^ \t)]/ && !/^\)/ { inside=0 }
    inside { print }
  ' "$1"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git -C "$TDIFF_REPO" cat-file -e "$PIN^{commit}" 2>/dev/null \
  || die "pinned commit $PIN not found in $TDIFF_REPO"
git -C "$TDIFF_REPO" show "$PIN:tdiff" > "$tmp/tdiff" 2>/dev/null \
  || die "could not read tdiff at $PIN"

grep -q "$BEGIN" "$TCAT" || die "tcat is missing its '$BEGIN' marker"
grep -q "$END"   "$TCAT" || die "tcat is missing its '$END' marker"

status=0
for fn in "${FUNCS[@]}"; do
  extract "$TCAT"      "$fn" > "$tmp/tcat.$fn"
  extract "$tmp/tdiff" "$fn" > "$tmp/tdiff.$fn"
  if [ ! -s "$tmp/tcat.$fn" ]; then
    echo "MISSING in tcat:  $fn" >&2; status=1; continue
  fi
  if [ ! -s "$tmp/tdiff.$fn" ]; then
    echo "MISSING in tdiff@$PIN: $fn" >&2; status=1; continue
  fi
  if ! diff -q "$tmp/tdiff.$fn" "$tmp/tcat.$fn" >/dev/null; then
    echo "DRIFTED: $fn" >&2
    diff -u "$tmp/tdiff.$fn" "$tmp/tcat.$fn" | sed 's/^/    /' >&2
    status=1
  fi
done

# Module-level constants copied alongside the functions.
CONSTS=(_SEP_RE WIKILINK_RE _PUNCT _WEEK_SHORT_RE _WEEK_FULL_RE
        _ISO_RE _OFF_RE _WEEKDAY_NAMES WEEKDAYS)
for const in "${CONSTS[@]}"; do
  a="$(grep -m1 -E "^${const}[[:space:]]*= " "$tmp/tdiff" || true)"
  b="$(grep -m1 -E "^${const}[[:space:]]*= " "$TCAT" || true)"
  if [ -z "$b" ]; then echo "MISSING in tcat:  $const" >&2; status=1; continue; fi
  if [ "$a" != "$b" ]; then
    echo "DRIFTED: $const" >&2
    echo "    tdiff@$PIN: $a" >&2
    echo "    tcat:       $b" >&2
    status=1
  fi
done

if [ "$status" -eq 0 ]; then
  echo "check-core-sync: vendored core matches tdiff@$PIN (${#FUNCS[@]} functions, ${#CONSTS[@]} constants)"
else
  echo "check-core-sync: vendored core has DRIFTED from tdiff@$PIN" >&2
fi
exit "$status"
