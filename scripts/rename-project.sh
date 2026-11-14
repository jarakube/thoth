#!/usr/bin/env bash
# rename-project.sh - rename this project (currently: thoth) to your own name.
#
# Rewrites the project name everywhere it is used as an identifier:
#   docker compose service/image/container names, Makefile targets, the
#   bundled developer skill (skills/<name>/), the login banner, CI image
#   labels, the iptables block marker, test fixtures, all docs, and
#   GitHub/ghcr links (jarakube/thoth -> <owner/repo>).
#
# Usage:
#   ./scripts/rename-project.sh [--force] <new-name> [owner/repo]
#
#     new-name    lowercase letters/digits/dashes (docker-safe), e.g. athena
#     owner/repo  optional GitHub slug for links; default jarakube/<new-name>
#     --force     allow running with uncommitted changes to tracked files
#
# Details:
#   - only touches git-tracked files (plus this script itself); user data
#     (workspace/, share/, suricata/logs/) and the goosetown submodule are
#     never modified
#   - removes the "Named after Thoth" etymology paragraph (README.md,
#     llms-full.txt) and the block-letter art from the banner - both spell
#     the old name
#   - rewrites this script too, so it can be run again later
#   - maintainer credits (jarakube.eu, Jaraco GmbH) are left untouched
#   - never commits; review with git status/git diff, then commit with
#     `git commit --signoff` (DCO)
#
# Undo (destructive): git reset --hard && git clean -fd

set -euo pipefail

# Self-synced: a rename rewrites these lines on disk, so the script stays
# re-runnable under the new name.
OLD_NAME="thoth"
OLD_CAP="Thoth"

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

# --- args -------------------------------------------------------------------

FORCE=0
if [ "${1:-}" = "--force" ] || [ "${1:-}" = "-f" ]; then FORCE=1; shift; fi
NEW_NAME="${1:-}"
SLUG="${2:-}"
[ -n "$NEW_NAME" ] || usage

if ! printf '%s' "$NEW_NAME" | grep -Eq '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
  echo "ERROR: invalid name '$NEW_NAME' - use lowercase letters/digits/dashes, starting with a letter" >&2
  exit 1
fi
if [ "$NEW_NAME" = "$OLD_NAME" ]; then
  echo "ERROR: '$NEW_NAME' is already the current name" >&2
  exit 1
fi
if [ -z "$SLUG" ]; then SLUG="jarakube/$NEW_NAME"; fi
if ! printf '%s' "$SLUG" | grep -Eq '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'; then
  echo "ERROR: invalid GitHub slug '$SLUG' (expected owner/repo)" >&2
  exit 1
fi
NEW_CAP="${NEW_NAME^}"
command -v perl >/dev/null 2>&1 || { echo "ERROR: perl is required" >&2; exit 1; }

# --- locate the repo ---------------------------------------------------------

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  cd "$(git rev-parse --show-toplevel)"
fi
[ -f docker-compose.yml ] || { echo "ERROR: run from the repository root" >&2; exit 1; }

IN_GIT=0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && IN_GIT=1

if [ "$IN_GIT" = 1 ]; then
  if { ! git diff --quiet || ! git diff --cached --quiet; } && [ "$FORCE" -ne 1 ]; then
    echo "ERROR: tracked files have uncommitted changes - commit or stash first, or pass --force" >&2
    exit 1
  fi
fi

# --- collect target files ---------------------------------------------------
# Tracked files only (plus this script); never the submodule or user data.

if [ "$IN_GIT" = 1 ]; then
  files="$(git ls-files)"
  # drop submodule gitlinks and everything under them
  while read -r sm; do
    [ -n "$sm" ] || continue
    files="$(printf '%s\n' "$files" | grep -v "^$sm\(/\|$\)" || true)"
  done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}' || true)
else
  files="$(find . \( -name .git -o -name goosetown -o -name workspace -o -name share \) -prune \
    -o -path ./suricata/logs -prune -o -type f -print | sed 's|^\./||')"
fi
files="$(printf '%s\n%s\n' "$files" "$SCRIPT_PATH" | sort -u)"

targets=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if grep -qIi -- "$OLD_NAME" "$f"; then targets+=("$f"); fi
done <<< "$files"

if [ "${#targets[@]}" -eq 0 ]; then
  echo "Nothing to do: no tracked file mentions '$OLD_NAME' anymore."
  exit 0
fi

echo "Renaming: $OLD_NAME -> $NEW_NAME   (links: jarakube/$OLD_NAME -> $SLUG)"
echo "Files to touch: ${#targets[@]}"

# --- 1. drop the Thoth etymology paragraph (its URL must not be rewritten) --

for f in README.md llms-full.txt; do
  [ -f "$f" ] || continue
  perl -0pi -e 's{\nNamed after \[Thoth\]\(https://en\.wikipedia\.org/wiki/Thoth\), the ancient\nEgyptian deity of wisdom, writing, and knowledge\.\n}{}g' "$f"
done

# --- 2. rewrite names in all target files ------------------------------------
# Order matters: repo slug first (it contains the old name), then the
# capitalized variant, then the plain lowercase name.

for f in "${targets[@]}"; do
  perl -pi -e "s{jarakube/\\Q$OLD_NAME\\E}{$SLUG}g; s{\\Q$OLD_CAP\\E}{$NEW_CAP}g; s{\\Q$OLD_NAME\\E}{$NEW_NAME}g" "$f"
done

# --- 3. rename named files and the skill directory ---------------------------

mv_cmd="mv"
[ "$IN_GIT" = 1 ] && mv_cmd="git mv"

banner_old="assets/${OLD_NAME}-banner.txt"
banner_new="assets/${NEW_NAME}-banner.txt"
skill_old="skills/${OLD_NAME}"
skill_new="skills/${NEW_NAME}"
[ -e "$banner_old" ] && $mv_cmd "$banner_old" "$banner_new"
[ -e "$skill_old" ]  && $mv_cmd "$skill_old" "$skill_new"

# --- 4. strip the block-letter art (it spells the old name) ------------------

if [ -f "$banner_new" ] && grep -qE '____|\|_' "$banner_new"; then
  tmp="$(mktemp)"
  grep -vE '____|\|_' "$banner_new" > "$tmp"
  cat "$tmp" > "$banner_new"
  rm -f "$tmp"
  echo "Banner: removed the letter art (kept the goose + tagline)."
fi

# --- 5. sanity checks --------------------------------------------------------

echo
echo "== shell syntax of changed scripts:"
for f in "${targets[@]}"; do
  case "$f" in
    *.sh) bash -n "$f" && echo "  OK  $f" ;;
  esac
done

if command -v docker >/dev/null 2>&1; then
  echo "== docker compose config:"
  if docker compose -f docker-compose.yml -f docker-compose.suricata.yml config --quiet; then
    echo "  OK (service: $NEW_NAME)"
  else
    echo "  FAILED - review docker-compose*.yml" >&2
  fi
fi

echo "== residual references to '$OLD_NAME':"
leftover=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if grep -qIi -- "$OLD_NAME" "$f"; then echo "  still present: $f"; leftover=1; fi
done <<< "$files"
[ "$leftover" -eq 0 ] && echo "  none"

# --- summary -----------------------------------------------------------------

echo
echo "Done. Changed ${#targets[@]} files; renames are staged (git mv)."
echo "Next steps:"
echo "  1. rename the directory itself:   mv ../$OLD_NAME ../$NEW_NAME"
echo "  2. point git at your fork:       git remote set-url origin git@github.com:$SLUG.git"
echo "  3. review and commit:            git add -A && git commit --signoff \\"
echo "        -m 'chore: rename project to $NEW_NAME'"
echo "  4. rebuild:                      make build"
echo "     (the old '$OLD_NAME' image/container are not removed - docker rmi/rm them as needed)"
