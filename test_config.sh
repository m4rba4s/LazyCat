#!/bin/bash
# test_config.sh - sanity check for local config parsing
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/logger.sh"

CONFIG_FILE="$SCRIPT_DIR/config.yaml"
echo "Testing Config Parsing from $CONFIG_FILE ..."

eval "$(parse_yaml "$CONFIG_FILE")"

echo "Checking variables..."
if [[ "${tools_nuclei_rate_limit:-}" == "150" ]]; then
    echo "[PASS] tools_nuclei_rate_limit = $tools_nuclei_rate_limit"
else
    echo "[FAIL] tools_nuclei_rate_limit = ${tools_nuclei_rate_limit:-unset} (Expected: 150)"
    exit 1
fi

if [[ "${profiles_fast_katana:-}" == "false" ]]; then
    echo "[PASS] profiles_fast_katana = $profiles_fast_katana"
else
    echo "[FAIL] profiles_fast_katana = ${profiles_fast_katana:-unset} (Expected: false)"
    exit 1
fi

echo "Config Test Passed."
