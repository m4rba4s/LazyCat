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
            awk '{print "[CRITICAL] AWS Access Key found in " $1 ": " $2}' >> "$findings_file"
            
        # Google API Key
        grep -rE "AIza[0-9A-Za-z\\-_]{35}" "$out_dir/secrets/js_files" | \
            awk '{print "[HIGH] Google API Key found in " $1 ": " $2}' >> "$findings_file"
            
        # Slack Token
        grep -rE "xox[baprs]-([0-9a-zA-Z]{10,48})" "$out_dir/secrets/js_files" | \
            awk '{print "[CRITICAL] Slack Token found in " $1 ": " $2}' >> "$findings_file"
            
        # Private Key Header
        grep -r "BEGIN RSA PRIVATE KEY" "$out_dir/secrets/js_files" | \
            awk '{print "[CRITICAL] RSA Private Key found in " $1}' >> "$findings_file"
            
        # Stripe Key
        grep -rE "sk_live_[0-9a-zA-Z]{24}" "$out_dir/secrets/js_files" | \
            awk '{print "[CRITICAL] Stripe Live Key found in " $1 ": " $2}' >> "$findings_file"
            
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
