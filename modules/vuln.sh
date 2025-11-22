#!/bin/bash
# modules/vuln.sh

run_vuln_scan() {
    local out_dir="$1"
    local profile="$2"
    
    log_info "Phase 3: Vulnerability Scanning (Nuclei & Dalfox)"
    
    # Determine scan list (Endpoints if crawled, else URLs)
    local scan_list="$out_dir/urls.txt"
    if [[ -s "$out_dir/content/endpoints.txt" ]]; then
        scan_list="$out_dir/content/endpoints.txt"
    fi

    # Nuclei Scan
    log_info "Running Nuclei Engine..."
    
    # Construct Nuclei flags based on profile config
    # Note: Variables like profiles_default_nuclei_tags come from config.yaml parsing
    local tags_var="profiles_${profile}_nuclei_tags"
    local sev_var="profiles_${profile}_nuclei_severity"
    
    local tags="${!tags_var}"
    local severity="${!sev_var}"
    
    nuclei -l "$scan_list" \
        -tags "$tags" \
        -severity "$severity" \
        -rate-limit "${tools_nuclei_rate_limit:-150}" \
        -c "${tools_nuclei_concurrency:-25}" \
        -silent -retries 2 \
        -o "$out_dir/vulns/nuclei_results.txt"
        
    # Dalfox Scan (if enabled in profile)
    local dalfox_enabled="profiles_${profile}_dalfox"
    if [[ "${!dalfox_enabled}" == "true" ]] && [[ -s "$out_dir/content/endpoints.txt" ]]; then
        log_info "Running Dalfox XSS Engine..."
        # Filter for parameters to optimize
        cat "$out_dir/content/endpoints.txt" | grep "=" | head -n 5000 | \
        dalfox pipe --skip-bav --silence --multicast \
            --workers "${tools_dalfox_workers:-40}" \
            -o "$out_dir/vulns/xss.txt"
    fi
}
