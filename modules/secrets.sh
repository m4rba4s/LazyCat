#!/bin/bash
# modules/secrets.sh
# Secrets Scanning Module (JS Analysis)

run_secrets_scan() {
    local out_dir="$1"
    
    log_info "Phase 2.4: Secrets Scanning (JS Analysis)"
    
    mkdir -p "$out_dir/secrets"
    
    # 1. Extract JS URLs from endpoints
    if [[ -s "$out_dir/content/endpoints.txt" ]]; then
        log_info "Extracting JavaScript files..."
        grep -E "\.js(\?|$)" "$out_dir/content/endpoints.txt" | sort -u > "$out_dir/secrets/js_urls.txt"
        
        local js_count=$(wc -l < "$out_dir/secrets/js_urls.txt")
        if [[ "$js_count" -eq 0 ]]; then
            log_warn "No JS files found for analysis"
            return 0
        fi
        
        log_info "Found $js_count unique JS files"
        
        # 2. Download JS files
        log_info "Downloading JS files for analysis..."
        mkdir -p "$out_dir/secrets/js_files"
        
        local count=0
        while read -r url; do
            local filename=$(basename "$url" | cut -d? -f1)
            # Prevent overwriting same filenames from diff paths
            filename="${count}_${filename}"
            
            # Download with timeout
            curl -s -L --max-time 5 "$url" -o "$out_dir/secrets/js_files/$filename"
            ((count++))
        done < "$out_dir/secrets/js_urls.txt"
        
        # 3. Regex Analysis
        log_info "Hunting for secrets in downloaded files..."
        local findings_file="$out_dir/secrets/findings.txt"
        touch "$findings_file"
        
        # Define Regex Patterns
        # AWS Access Key ID
        grep -rE "AKIA[0-9A-Z]{16}" "$out_dir/secrets/js_files" | \
            awk '{print "[CRITICAL] AWS Access Key found in " $1 ": " $2}' >> "$findings_file" || true
            
        # Google API Key
        grep -rE "AIza[0-9A-Za-z\\-_]{35}" "$out_dir/secrets/js_files" | \
            awk '{print "[HIGH] Google API Key found in " $1 ": " $2}' >> "$findings_file" || true
            
        # Slack Token
        grep -rE "xox[baprs]-([0-9a-zA-Z]{10,48})" "$out_dir/secrets/js_files" | \
            awk '{print "[CRITICAL] Slack Token found in " $1 ": " $2}' >> "$findings_file" || true
            
        # Private Key Header
        grep -r "BEGIN RSA PRIVATE KEY" "$out_dir/secrets/js_files" | \
            awk '{print "[CRITICAL] RSA Private Key found in " $1}' >> "$findings_file" || true
            
        # Stripe Key
        grep -rE "sk_live_[0-9a-zA-Z]{24}" "$out_dir/secrets/js_files" | \
            awk '{print "[CRITICAL] Stripe Live Key found in " $1 ": " $2}' >> "$findings_file" || true
            
        # --- Supply Chain Analysis (Library Detection) ---
        log_info "Analyzing JS libraries for known vulnerabilities..."
        local supply_chain_file="$out_dir/secrets/supply_chain.txt"
        
        # jQuery Version
        grep -rE "jQuery v[0-9]+\.[0-9]+\.[0-9]+" "$out_dir/secrets/js_files" | \
            grep -oE "jQuery v[0-9]+\.[0-9]+\.[0-9]+" | sort -u > "$supply_chain_file" || true
            
        # Bootstrap Version
        grep -rE "Bootstrap v[0-9]+\.[0-9]+\.[0-9]+" "$out_dir/secrets/js_files" | \
            grep -oE "Bootstrap v[0-9]+\.[0-9]+\.[0-9]+" | sort -u >> "$supply_chain_file" || true
            
        # React/Angular (heuristic)
        if grep -rq "React.createElement" "$out_dir/secrets/js_files"; then
            echo "React Framework detected" >> "$supply_chain_file"
        fi
        if grep -rq "angular.module" "$out_dir/secrets/js_files"; then
            echo "Angular Framework detected" >> "$supply_chain_file"
        fi
        
        # Check for Vulnerable Versions (Basic)
        if [[ -s "$supply_chain_file" ]]; then
            log_info "Libraries detected:"
            cat "$supply_chain_file" | sed 's/^/  /'
            
            # jQuery < 3.5.0 XSS check
            if grep -qE "jQuery v(1\.|2\.|3\.[0-4]\.)" "$supply_chain_file"; then
                echo "[HIGH] Vulnerable jQuery version detected (< 3.5.0)" >> "$findings_file"
                log_warn "⚠️  Vulnerable jQuery detected!"
            fi
            
            # Bootstrap < 4.0.0 (XSS in tooltips)
            if grep -qE "Bootstrap v(3\.|2\.)" "$supply_chain_file"; then
                echo "[MEDIUM] Outdated Bootstrap version detected" >> "$findings_file"
            fi
        fi
            
        # 4. Summary
        local findings_count=0
        if [[ -f "$findings_file" ]]; then
            findings_count=$(wc -l < "$findings_file")
        fi
        
        if [[ "$findings_count" -gt 0 ]]; then
            log_warn "Secrets Found: $findings_count"
            cat "$findings_file"
        else
            log_success "No secrets found in JS files"
        fi
        
    else
        log_info "No endpoints to analyze for secrets"
    fi
}
