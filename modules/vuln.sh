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
    local auth_args=()
    if [[ -n "$auth_cookie" ]]; then
        auth_args+=(-H "Cookie: $auth_cookie")
    fi
    if [[ -n "$auth_header" ]]; then
        auth_args+=(-H "$auth_header")
    fi

    # 3. Run Nuclei
    # We use -json-export to get structured data for evidence generation
    log_info "Scanning $(wc -l < "$scan_list") targets..."
    nuclei -l "$scan_list" \
        -tags "$tags" \
        -severity "$severity" \
        -rate-limit "$rate_limit" \
        -c "${tools_nuclei_concurrency:-25}" \
        "${auth_args[@]}" \
        -silent -retries 2 \
        -duc \
        -o "$out_dir/vulns/nuclei_results.txt" \
        -json-export "$out_dir/vulns/nuclei_results.json"
        
    # 4. Generate Evidence (Reproducer)
    if [[ -f "$out_dir/vulns/nuclei_results.json" ]]; then
        log_info "Generating evidence/reproducer_curl.sh..."
        local evidence_file="$out_dir/evidence/reproducer_curl.sh"
        echo "#!/bin/bash" > "$evidence_file"
        echo "# Auto-generated reproduction scripts" >> "$evidence_file"
        
        # Parse JSON and extract curl commands (using jq if available, else simple grep/awk fallback)
        # Assuming jq is standard in APT env, but providing fallback just in case
        if command -v jq &>/dev/null; then
            jq -r '. | "# " + .info.name + "\n" + "curl -k -v \"" + .matched_at + "\"" + (if .curl_command then " # " + .curl_command else "" end) + "\n"' "$out_dir/vulns/nuclei_results.json" >> "$evidence_file"
        else
            # Fallback: Simple URL extraction
            grep "matched-at" "$out_dir/vulns/nuclei_results.json" | \
            awk -F'"' '{print "# Potential Vuln\ncurl -k -v \"" $4 "\""}' >> "$evidence_file"
        fi
        chmod +x "$evidence_file"
    fi

    # --- DALFOX ---
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
            -o "$out_dir/vulns/xss.txt"
            
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
