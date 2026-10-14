#!/bin/bash
# shellcheck disable=SC2154

source /gauntlet/support/get_named_parameters.sh

MAX_LINT=30       # details line of flake8
MAX_MYPY=20       # details line of mypy
MAX_PYTEST=80     # output line of pytest
TEST_TIMEOUT=300  # seconds

status=0
summary=""
details=""

# 1. Auto-fix provided by black and isort
black -q "$path"
isort -q --profile black "$path"

# 2. flake8 (fail on error)
flake8_out=$(flake8 --config /gauntlet/config/.flake8 \
   --format='%(code)s %(path)s:%(row)d %(text)s' "$path" 2>&1)
flake8_rc=$?

if [ "$flake8_rc" -ne 0 ]; then
   status=1

   total=$(echo "$flake8_out" | wc -l)

   summary+="flake8: FAIL ($total errori)"$'\n'

   details+="=== flake8: errori per tipo ==="$'\n'
   details+="$(echo "$flake8_out" | cut -d' ' -f1 | sort | uniq -c | sort -rn)"$'\n\n'
   details+="=== flake8: primi $MAX_LINT ==="$'\n'
   details+="$(echo "$flake8_out" | head -n "$MAX_LINT")"$'\n'
   [ "$total" -gt "$MAX_LINT" ] && details+="... e altri $((total - MAX_LINT)) errori"$'\n'
   details+=$'\n'
else
   summary+="flake8: ok"$'\n'
fi

# 3. pytest (fail on error)
pytest_out=$(timeout "$TEST_TIMEOUT" python -m pytest "$path" \
   -q --tb=short --maxfail=3 -p no:cacheprovider 2>&1)
pytest_rc=$?

case "$pytest_rc" in
   0 ) summary+="pytest: ok"$'\n' ;;
   5 ) summary+="pytest: nessun test trovato"$'\n' ;;
   124 ) status=1
         summary+="pytest: TIMEOUT (${TEST_TIMEOUT}s)"$'\n' ;;
   * ) status=1
       summary+="pytest: FAIL"$'\n'
       details+="=== pytest ==="$'\n'
       details+="$(echo "$pytest_out" | tail -n "$MAX_PYTEST")"$'\n\n' ;;
esac

# 4. mypy
mypy_out=$(mypy --ignore-missing-imports "$path" 2>&1)
if [ $? -ne 0 ]; then
   summary+="mypy: warning ($(echo "$mypy_out" | grep -c 'error:') errori, non bloccante)"$'\n'
   details+="=== mypy (info) ==="$'\n'
   details+="$(echo "$mypy_out" | head -n "$MAX_MYPY")"$'\n'
else
   summary+="mypy: ok"$'\n'
fi

# Output: summary details
echo "=== RIEPILOGO ==="
echo "$summary"
[ -n "$details" ] && echo "$details"
[ "$status" -eq 0 ] && echo "Gauntlet superato ✓" || echo "Gauntlet NON superato ✗"
exit "$status"