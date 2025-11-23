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

    # --- NUCLEI ---
    log_info "Running Nuclei Engine..."
    
    # 1. Resolve Profile Config
    local tags_var="profiles_${profile}_nuclei_tags"
    local sev_var="profiles_${profile}_nuclei_severity"
    local rate_var="profiles_${profile}_nuclei_rate_limit"
    
    local tags="${!tags_var}"
    local severity="${!sev_var}"
    # Use profile rate limit if set, otherwise default to tool config, otherwise 150
    local rate_limit="${!rate_var:-${tools_nuclei_rate_limit:-150}}"
    
    log_info "Configuration: Tags=[$tags] Severity=[$severity] Rate=[$rate_limit]"

    # 2. Prepare Auth Flags
    # 1. Nuclei Scan
    log_info "Running Nuclei..."
    
    local auth_args=($(build_auth_args))
    
    # We use -json-export to get structured data for evidence generation
    nuclei -l "$scan_list" \
        -tags "$tags" \
        -severity "$severity" \
        -rate-limit "$rate_limit" \
        -c "${tools_nuclei_concurrency:-25}" \
        "${auth_args[@]}" \
        -silent -retries 2 \
        -duc \
        -o "$out_dir/vulns/nuclei_results.txt" \
        -json-export "$out_dir/vulns/nuclei_results.json" || true
        
    # Parse Results (JSON)
    local evidence_file="$out_dir/evidence/nuclei_evidence.sh"
    echo "#!/bin/bash" > "$evidence_file"
    
    if [[ -f "$out_dir/vulns/nuclei_results.json" ]]; then
        jq -r '.[] | "# " + .info.name + "\ncurl -k -v \"" + .matched_at + "\"\n"' "$out_dir/vulns/nuclei_results.json" >> "$evidence_file" 2>/dev/null || \
        grep "matched-at" "$out_dir/vulns/nuclei_results.json" | awk -F'"' '{print "# Potential Vuln\ncurl -k -v \"" $4 "\""}' >> "$evidence_file" || true
    fi
    
    chmod +x "$evidence_file"
    
    local vuln_count=$(wc -l < "$out_dir/vulns/nuclei_results.txt" 2>/dev/null || echo 0)
    if [[ "$vuln_count" -gt 0 ]]; then
        log_warn "Nuclei found $vuln_count vulnerabilities!"
    else
        log_success "Nuclei scan clean."
    fi

    # --- DALFOX (XSS) ---
    local dalfox_enabled="profiles_${profile}_dalfox"
    if [[ "${!dalfox_enabled}" == "true" ]] && [[ -s "$out_dir/content/endpoints.txt" ]]; then
        log_info "Running Dalfox XSS Engine..."
        
        # Prepare dalfox auth args
        local dalfox_args=()
        if [[ -n "$auth_cookie" ]]; then
            dalfox_args+=(--cookie "$auth_cookie")
        fi
        if [[ -n "$auth_header" ]]; then
            dalfox_args+=(--header "$auth_header")
        fi

        # Filter for parameters to optimize
        cat "$out_dir/content/endpoints.txt" | grep "=" | head -n 5000 | \
        dalfox pipe --skip-bav --silence --multicast \
            -w "${tools_dalfox_workers:-40}" \
            "${dalfox_args[@]}" \
            -o "$out_dir/vulns/xss.txt" || true
            
        # Append Dalfox findings to evidence
        if [[ -s "$out_dir/vulns/xss.txt" ]]; then
            echo "" >> "$evidence_file"
            echo "# Dalfox XSS Findings" >> "$evidence_file"
            while read -r line; do
                # Dalfox output format usually contains the URL
                # Extract URL from the line (simplified)
                local url=$(echo "$line" | awk '{print $2}') 
                [[ -z "$url" ]] && url="$line" # Fallback
                echo "curl -k -v \"$url\"" >> "$evidence_file"
            done < "$out_dir/vulns/xss.txt"
        fi
    fi
}
