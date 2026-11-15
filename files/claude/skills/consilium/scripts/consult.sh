#!/usr/bin/env bash
# Usage: consult.sh <brief.md> [repo-dir]
# Sends one planning brief to each consilium model via opencode (read-only plan agent), in parallel,
# and prints every answer under a "## <model>" header. Failed models get an "## ERROR" block;
# exit code is the number of failed models.
set -u
brief=$1
dir=${2:-$PWD}
# Panels live outside the repo: ~/.config/consilium/config sets CONSILIUM_MODELS and CONSILIUM_REVIEW_MODELS.
[ -z "${CONSILIUM_MODELS:-}" ] && [ -r "$HOME/.config/consilium/config" ] && . "$HOME/.config/consilium/config"
models=${CONSILIUM_MODELS:?set CONSILIUM_MODELS to "provider/model ..." (see: opencode models) or create ~/.config/consilium/config}
out=$(mktemp -d)

for m in $models; do
  f="$out/${m//\//_}"
  ( timeout "${CONSILIUM_TIMEOUT:-480}" opencode run --pure --agent plan --dir "$dir" -m "$m" --format json "$(cat "$brief")" >"$f.json" 2>"$f.err"
    echo $? >"$f.rc" ) &
done
wait

failed=0
for m in $models; do
  f="$out/${m//\//_}"
  rc=$(cat "$f.rc")
  text=$(jq -R -r 'fromjson? | select(.type=="text") | .part.text' "$f.json")
  errs=$( { jq -R -r 'fromjson? | select(.type=="error") | .error.data.message // .error.name // (.error|tostring)' "$f.json"; grep -v '^$' "$f.err"; } | head -5)
  if [ "$rc" != 0 ] || [ -n "$errs" ] || [ -z "$text" ]; then
    failed=$((failed + 1))
    echo "## ERROR $m (exit $rc)"
    echo "${errs:-no text returned}"
    [ -n "$text" ] && { echo "partial answer:"; echo "$text"; }
  else
    echo "## $m"
    echo "$text"
  fi
  echo
done
exit $failed
