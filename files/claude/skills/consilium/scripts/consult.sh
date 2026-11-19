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

# opencode canonicalizes its project dir (symlinks resolved, e.g. /tmp -> /private/tmp on macOS) and
# auto-rejects reads under any other prefix as "external_directory" in non-interactive mode. A model
# that follows an absolute path from the brief verbatim then gets no answer. Pass the canonical dir
# and rewrite the brief to use it, so both spellings of the path land inside the project.
real=$(cd "$dir" && pwd -P) || { echo "consult.sh: cannot cd to $dir" >&2; exit 1; }
if [ "$real" != "$dir" ] && grep -qF "$dir" "$brief"; then
  sed "s#$dir#$real#g" "$brief" >"$out/brief.md"
  brief=$out/brief.md
  echo "consult.sh: rewrote $dir -> $real in the brief (opencode resolves symlinks)" >&2
fi
dir=$real

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
  # Some models leak their tool-call markup (e.g. "<｜DSML｜function_calls") into the text stream;
  # the calls still run, so drop the markers rather than the answer.
  text=$(jq -R -r 'fromjson? | select(.type=="text") | .part.text' "$f.json" | grep -v '^<｜DSML｜')
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
