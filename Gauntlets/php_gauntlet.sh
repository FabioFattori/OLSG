#!/bin/bash
# shellcheck disable=SC2154

source /gauntlet/support/get_named_parameters.sh

PHPSTAN_LEVEL="${PHPSTAN_LEVEL:-10}"
PHPSTAN_MEMORY_LIMIT="${PHPSTAN_MEMORY_LIMIT:-2G}"
MAX_PHPSTAN=30     # righe di dettaglio PHPStan
MAX_PHPUNIT=80     # righe di output PHPUnit
TEST_TIMEOUT=300   # secondi

status=0
summary=""
details=""

# $path = root del progetto PHP (quella che contiene src/, tests/, vendor/)
cd "$path" || { echo "path not found: $path"; exit 2; }

targets=()
for dir in src tests test; do
   [ -d "$dir" ] && targets+=("$dir")
done

if [ ${#targets[@]} -eq 0 ]; then
   echo "no src/, tests/ or test/ directory found in $path"
   exit 2
fi

if [ ! -f vendor/autoload.php ]; then
   summary+="note: vendor/ non trovato (esegui 'composer install'): PHPStan non vedra' le dipendenze"$'\n'
fi

# 1. Auto-fix: lo stile non deve arrivare all'agente
pint_out=$(pint --config /gauntlet/config/pint.json "${targets[@]}" 2>&1)
pint_rc=$?

if [ "$pint_rc" -ne 0 ]; then
   status=1
   summary+="pint: FAIL (probabile syntax error)"$'\n'
   details+="=== pint ==="$'\n'
   details+="$(echo "$pint_out" | tail -n 30)"$'\n\n'
else
   summary+="pint: ok (auto-fix applicato)"$'\n'
fi

# 2. PHPStan (bloccante): errori per file + primi N
phpstan_args=(analyse "${targets[@]}"
   --level="$PHPSTAN_LEVEL"
   --memory-limit="$PHPSTAN_MEMORY_LIMIT"
   --error-format=raw
   --no-progress
   --no-interaction)

if [ -f vendor/autoload.php ]; then
   phpstan_args+=(--autoload-file=vendor/autoload.php)
fi

phpstan_out=$(phpstan "${phpstan_args[@]}" 2>&1)
phpstan_rc=$?

if [ "$phpstan_rc" -ne 0 ]; then
   status=1
   total=$(echo "$phpstan_out" | grep -c .)
   summary+="phpstan (level $PHPSTAN_LEVEL): FAIL ($total righe di errore)"$'\n'
   details+="=== phpstan: errori per file ==="$'\n'
   details+="$(echo "$phpstan_out" | cut -d: -f1 | sort | uniq -c | sort -rn | head -n 10)"$'\n\n'
   details+="=== phpstan: primi $MAX_PHPSTAN ==="$'\n'
   details+="$(echo "$phpstan_out" | head -n "$MAX_PHPSTAN")"$'\n'
   [ "$total" -gt "$MAX_PHPSTAN" ] && details+="... e altre $((total - MAX_PHPSTAN)) righe"$'\n'
   details+=$'\n'
else
   summary+="phpstan (level $PHPSTAN_LEVEL): ok"$'\n'
fi

# 3. PHPUnit (bloccante, solo se il progetto lo ha installato)
if [ -x vendor/bin/phpunit ]; then
   phpunit_out=$(timeout "$TEST_TIMEOUT" vendor/bin/phpunit --stop-on-failure 2>&1)
   phpunit_rc=$?

   case "$phpunit_rc" in
      0 ) summary+="phpunit: ok"$'\n' ;;
      124 ) status=1
            summary+="phpunit: TIMEOUT (${TEST_TIMEOUT}s)"$'\n' ;;
      * ) status=1
          summary+="phpunit: FAIL"$'\n'
          details+="=== phpunit ==="$'\n'
          details+="$(echo "$phpunit_out" | tail -n "$MAX_PHPUNIT")"$'\n\n' ;;
   esac
else
   summary+="phpunit: saltato (vendor/bin/phpunit non presente)"$'\n'
fi

# Output: riepilogo, poi dettagli
echo "=== RIEPILOGO ==="
echo "$summary"
[ -n "$details" ] && echo "$details"
[ "$status" -eq 0 ] && echo "Gauntlet superato" || echo "Gauntlet NON superato"
exit "$status"