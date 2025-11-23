#!/bin/bash
# test_config.sh
source /home/mindlock/programms/recon-v7/lib/utils.sh
source /home/mindlock/programms/recon-v7/lib/logger.sh

CONFIG_FILE="/home/mindlock/programms/recon-v7/config.yaml"
echo "Testing Config Parsing..."

eval $(parse_yaml "$CONFIG_FILE")

echo "Checking variables..."
if [[ "$tools_nuclei_rate_limit" == "150" ]]; then
    echo "[PASS] tools_nuclei_rate_limit = $tools_nuclei_rate_limit"
else
    echo "[FAIL] tools_nuclei_rate_limit = $tools_nuclei_rate_limit (Expected: 150)"
    exit 1
fi

if [[ "$profiles_fast_katana" == "false" ]]; then
    echo "[PASS] profiles_fast_katana = $profiles_fast_katana"
else
    echo "[FAIL] profiles_fast_katana = $profiles_fast_katana (Expected: false)"
    exit 1
fi

echo "Config Test Passed."
