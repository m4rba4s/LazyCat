#!/bin/bash
# modules/tls_audit.sh
# SSL/TLS Security Audit Module

run_tls_audit() {
    local out_dir="$1"
    
    log_info "Phase 1.6: SSL/TLS Security Audit"
    
    mkdir -p "$out_dir/tls"
    
    # Check if testssl.sh is available
    if ! command -v testssl.sh &>/dev/null && ! command -v testssl &>/dev/null; then
        log_warn "testssl.sh not found, using basic openssl checks"
        
        # Fallback: Basic SSL checks with openssl
        while read -r url; do
            [[ -z "$url" ]] && continue
            local host=$(echo "$url" | sed 's|https\?://||' | cut -d'/' -f1)
            
            log_info "Checking TLS for $host..."
            {
                echo "=== Certificate Info for $host ==="
                echo | timeout 5 openssl s_client -connect "$host:443" -servername "$host" 2>/dev/null | \
                    openssl x509 -noout -text 2>/dev/null || echo "Connection timeout or failed"
                
                echo ""
                echo "=== Cipher Suites ==="
                timeout 10 nmap --script ssl-enum-ciphers -p 443 "$host" 2>/dev/null || \
                    echo "nmap not available or timed out"
            } >> "$out_dir/tls/${host}_ssl_report.txt"
            
            # Check for weak ciphers
            if echo | timeout 5 openssl s_client -connect "$host:443" -cipher 'DES' 2>/dev/null | grep -q "Cipher"; then
                echo "[CRITICAL] Weak cipher (DES) supported on $host" >> "$out_dir/tls/findings.txt"
            fi
            
            # Check certificate expiry
            local expiry=$(echo | timeout 5 openssl s_client -connect "$host:443" -servername "$host" 2>/dev/null | \
                openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || echo "Failed")
            echo "$host: Certificate expires $expiry" >> "$out_dir/tls/cert_expiry.txt"
            
        done < "$out_dir/urls.txt"
    else
        # Use testssl.sh for comprehensive checks
        log_info "Running testssl.sh comprehensive scan..."
        
        while read -r url; do
            [[ -z "$url" ]] && continue
            local host=$(echo "$url" | sed 's|https\?://||' | cut -d'/' -f1)
            
            log_info "Testing $host with testssl.sh..."
            timeout 60 testssl.sh --quiet --jsonfile "$out_dir/tls/${host}_testssl.json" "$host" \
                > "$out_dir/tls/${host}_testssl.txt" 2>&1 || log_warn "testssl.sh timed out or failed for $host"
            
            # Extract critical findings
            if [[ -f "$out_dir/tls/${host}_testssl.json" ]]; then
                jq -r '.[] | select(.severity == "CRITICAL" or .severity == "HIGH") | 
                    "[" + .severity + "] " + .id + ": " + .finding' \
                    "$out_dir/tls/${host}_testssl.json" >> "$out_dir/tls/findings.txt" 2>/dev/null || true
            fi
        done < "$out_dir/urls.txt"
    fi
    
    # Summary
    local findings_count=0
    if [[ -f "$out_dir/tls/findings.txt" ]]; then
        findings_count=$(wc -l < "$out_dir/tls/findings.txt")
    fi
    if [[ "$findings_count" -gt 0 ]]; then
        log_warn "TLS Security Issues Found: $findings_count"
    else
        log_success "No critical TLS security issues found"
    fi
}
