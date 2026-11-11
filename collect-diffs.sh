#!/usr/bin/env bash
# collect-diffs.sh — gather diff + commit-message pairs from several repos

# ---------- CONFIG ----------
GENCODE="/c/Users/hp/Desktop/AA/6th_year_1st_semester/Selected_topics/gencode"
REPOS=(
  "/c/path/to/repo1"
  "/c/path/to/repo2"
  "/c/path/to/repo3"
)
PATHSPECS=( '*.py' )        # e.g. ( '*.py' '*.ts' )  — empty () means all files
MAX_PER_REPO=20
MIN_LINES=5
MAX_LINES=200
TARGET=15
# ----------------------------

DIFF_DIR="$GENCODE/tests/diffs"
mkdir -p "$DIFF_DIR"

collected=$(find "$DIFF_DIR" -maxdepth 1 -name '*.diff' | wc -l)
echo "Existing diffs in $DIFF_DIR : $collected"
echo "Target total: $TARGET"

for repo in "${REPOS[@]}"; do
  [ "$collected" -ge "$TARGET" ] && break

  if [ ! -d "$repo" ]; then
    echo "!! skipping (not found): $repo" >&2
    continue
  fi

  cd "$repo" || continue
  if [ ! -d .git ]; then
    echo "!! skipping (not a git repo): $repo" >&2
    continue
  fi

  repo_name=$(basename "$repo")
  echo
  echo "=== $repo_name ==="

  # Build git log command
  log_cmd=( git log --no-merges --format='%H' -n "$MAX_PER_REPO" )
  if [ "${#PATHSPECS[@]}" -gt 0 ]; then
    log_cmd+=( -- "${PATHSPECS[@]}" )
  fi

  while IFS= read -r sha; do
    [ -z "$sha" ] && continue
    [ "$collected" -ge "$TARGET" ] && break

    short=${sha:0:8}
    base="${repo_name}_${short}"
    diff_file="$DIFF_DIR/${base}.diff"
    msg_file="$DIFF_DIR/${base}.msg.txt"

    # idempotent: skip if already collected
    [ -f "$diff_file" ] && continue

    show_cmd=( git show --no-color --format="commit %H%n%n%s%n" "$sha" )
    if [ "${#PATHSPECS[@]}" -gt 0 ]; then
      show_cmd+=( -- "${PATHSPECS[@]}" )
    fi

    "${show_cmd[@]}" > "$diff_file" 2>/dev/null
    git show -s --format='%B' "$sha" > "$msg_file" 2>/dev/null

    lines=$(wc -l < "$diff_file")
    if [ "$lines" -lt "$MIN_LINES" ] || [ "$lines" -gt "$MAX_LINES" ]; then
      rm -f "$diff_file" "$msg_file"
      continue
    fi

    collected=$((collected + 1))
    printf '  [%2d/%d] kept %s (%d lines)\n' "$collected" "$TARGET" "$base" "$lines"
  done < <("${log_cmd[@]}" 2>/dev/null)
done

echo
echo "--------------------------------------------"
echo "Done. Total diffs collected: $collected / $TARGET"
if [ "$collected" -lt "$TARGET" ]; then
  echo "!! Need $((TARGET - collected)) more. Add repos or lower filters."
fi

echo
echo "Files in $DIFF_DIR:"
ls -1 "$DIFF_DIR"/*.diff 2>/dev/null | sed 's|.*/||'