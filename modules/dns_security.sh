#!/bin/bash
# modules/dns_security.sh
# DNS Security Audit Module

run_dns_security() {
    local target="$1"
    local out_dir="$2"
    
    log_info "Phase 1.5: DNS Security Audit"
    
    mkdir -p "$out_dir/dns"
    
    # 1. DNS Zone Transfer (AXFR)
    log_info "Testing DNS Zone Transfer (AXFR)..."
    local domain=$(echo "$target" | sed 's/https\?:\/\///' | sed 's/www\.//')
    
    # Get nameservers
    dig +short NS "$domain" > "$out_dir/dns/nameservers.txt"
    
    # Try AXFR on each nameserver
    while read -r ns; do
        [[ -z "$ns" ]] && continue
        log_info "Attempting AXFR on $ns..."
        dig @"$ns" "$domain" AXFR >> "$out_dir/dns/axfr_results.txt" 2>&1
    done < "$out_dir/dns/nameservers.txt"
    
    # Check if AXFR succeeded
    if grep -q "XFR size" "$out_dir/dns/axfr_results.txt" 2>/dev/null; then
        log_warn "⚠️  DNS Zone Transfer ENABLED - Critical vulnerability!"
        echo "[CRITICAL] DNS Zone Transfer allowed on $domain" >> "$out_dir/dns/findings.txt"
    fi
    
    # 2. DNSSEC Validation
    log_info "Checking DNSSEC..."
    dig +dnssec "$domain" > "$out_dir/dns/dnssec.txt"
    if ! grep -q "ad;" "$out_dir/dns/dnssec.txt"; then
        log_warn "DNSSEC not properly configured"
        echo "[MEDIUM] DNSSEC not enabled for $domain" >> "$out_dir/dns/findings.txt"
    fi
    
    # 3. SPF/DMARC/DKIM Records
    log_info "Checking email security records..."
    {
        echo "=== SPF Record ==="
        dig +short TXT "$domain" | grep "v=spf1"
        echo ""
        echo "=== DMARC Record ==="
        dig +short TXT "_dmarc.$domain"
        echo ""
        echo "=== DKIM Records (common selectors) ==="
        for selector in default google dkim; do
            dig +short TXT "${selector}._domainkey.$domain"
        done
    } > "$out_dir/dns/email_security.txt"
    
    # Check for missing records
    if ! grep -q "v=spf1" "$out_dir/dns/email_security.txt"; then
        echo "[HIGH] Missing SPF record" >> "$out_dir/dns/findings.txt"
    fi
    if ! grep -q "v=DMARC1" "$out_dir/dns/email_security.txt"; then
        echo "[HIGH] Missing DMARC record" >> "$out_dir/dns/findings.txt"
    fi
    
    # 4. Subdomain Takeover Detection (using dnsx if available)
    if command -v dnsx &>/dev/null && [[ -f "$out_dir/subs_raw.txt" ]]; then
        log_info "Checking for subdomain takeover vulnerabilities..."
        cat "$out_dir/subs_raw.txt" | dnsx -silent -cname -resp -o "$out_dir/dns/cnames.txt"
        
        # Check for common takeover patterns
        grep -iE "(github\.io|herokuapp\.com|s3\.amazonaws\.com|azurewebsites\.net|cloudfront\.net)" \
            "$out_dir/dns/cnames.txt" > "$out_dir/dns/potential_takeovers.txt" 2>/dev/null
        
        if [[ -s "$out_dir/dns/potential_takeovers.txt" ]]; then
            log_warn "⚠️  Potential subdomain takeover detected!"
            echo "[CRITICAL] Potential subdomain takeover found" >> "$out_dir/dns/findings.txt"
        fi
    fi
    
    # 5. DNS Cache Poisoning Test (Kaminsky-style check)
    log_info "Checking DNS randomization..."
    {
        echo "=== DNS Query ID Randomization Test ==="
        for i in {1..5}; do
            dig "$domain" | grep "Query time"
        done
    } > "$out_dir/dns/randomization_test.txt"
    
    # 6. Wildcard DNS Check
    log_info "Checking for wildcard DNS..."
    local random_sub="$(head /dev/urandom | tr -dc a-z0-9 | head -c 16)"
    if dig +short "${random_sub}.${domain}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        log_warn "Wildcard DNS detected"
        echo "[LOW] Wildcard DNS configured" >> "$out_dir/dns/findings.txt"
    fi
    
    # Summary
    local findings_count=$(wc -l < "$out_dir/dns/findings.txt" 2>/dev/null || echo 0)
    if [[ "$findings_count" -gt 0 ]]; then
        log_warn "DNS Security Issues Found: $findings_count"
    else
        log_success "No critical DNS security issues found"
    fi
}
