#!/bin/bash
# modules/payload_test.sh
# Payload Delivery & Firewall Egress Test Module

run_payload_test() {
    local out_dir="$1"
    
    log_info "Phase 2.3: Payload Delivery & Egress Testing"
    
    mkdir -p "$out_dir/payload"
    
    # 1. File Upload Vulnerability Testing
    log_info "Testing for unrestricted file upload..."
    
    # Generate EICAR test file (harmless malware test signature)
    local eicar='X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
    echo "$eicar" > "$out_dir/payload/eicar.txt"
    
    # Generate Large Payloads (Stress Test)
    log_info "Generating large payloads for stress testing..."
    dd if=/dev/zero of="$out_dir/payload/large_1mb.bin" bs=1M count=1 2>/dev/null || true
    dd if=/dev/zero of="$out_dir/payload/large_5mb.bin" bs=1M count=5 2>/dev/null || true
    
    # Test various extensions (Polyglots & Bypasses)
    for ext in php jsp asp aspx sh py exe php.jpg php%00.jpg; do
        cp "$out_dir/payload/eicar.txt" "$out_dir/payload/test.$ext"
    done
    
    # Scan for upload endpoints
    if [[ -s "$out_dir/content/endpoints.txt" ]]; then
        log_info "Searching for upload endpoints..."
        grep -iE "(upload|file|attach|import)" "$out_dir/content/endpoints.txt" > \
            "$out_dir/payload/upload_endpoints.txt" || true
        
        local upload_count=$(wc -l < "$out_dir/payload/upload_endpoints.txt")
        if [[ "$upload_count" -gt 0 ]]; then
            log_warn "Found $upload_count potential upload endpoints"
            echo "[MEDIUM] $upload_count file upload endpoints detected" >> "$out_dir/payload/findings.txt"
            
            # Active Stress Test (if not dry-run)
            if [[ "${DRY_RUN:-false}" == "false" ]]; then
                log_info "Running Active Upload Stress Test..."
                while read -r endpoint; do
                    log_info "Stress testing $endpoint with 1MB payload..."
                    # Try to upload 1MB file (timeout 10s)
                    local http_code=$(curl -s -o /dev/null -w "%{http_code}" \
                        -X POST -F "file=@$out_dir/payload/large_1mb.bin" \
                        --max-time 10 "$endpoint" || echo "TIMEOUT")
                    
                    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
                        echo "[CRITICAL] Large file (1MB) accepted by $endpoint" >> "$out_dir/payload/findings.txt"
                        log_warn "⚠️  Endpoint $endpoint accepted 1MB payload!"
                    elif [[ "$http_code" == "TIMEOUT" ]]; then
                         echo "[HIGH] Upload timeout (DoS potential) on $endpoint" >> "$out_dir/payload/findings.txt"
                    else
                        log_info "Endpoint returned $http_code (Safe)"
                    fi
                done < "$out_dir/payload/upload_endpoints.txt"
            fi
        fi
    fi
    
    # 2. Webshell Detection Simulation
    log_info "Testing webshell upload patterns..."
    {
        echo "=== Common Webshell Patterns ==="
        echo "Testing for:"
        echo "  - PHP: <?php system(\$_GET['cmd']); ?>"
        echo "  - JSP: <% Runtime.getRuntime().exec(request.getParameter(\"cmd\")); %>"
        echo "  - ASPX: <% eval(Request[\"cmd\"]); %>"
        echo ""
        echo "Note: Only EICAR test files generated, no actual webshells"
    } > "$out_dir/payload/webshell_test.txt"
    
    # 3. Firewall Egress Testing
    log_info "Testing firewall egress rules..."
    {
        echo "=== Egress Testing ==="
        
        # Test common callback ports
        for port in 80 443 53 8080 4444 1337; do
            log_info "Testing egress on port $port..."
            
            # Try to connect to a known external service
            if timeout 3 bash -c "echo test | nc -w 2 portquiz.net $port" 2>/dev/null; then
                echo "[INFO] Egress allowed on port $port" >> "$out_dir/payload/egress.txt"
            else
                echo "[BLOCKED] Egress blocked on port $port" >> "$out_dir/payload/egress.txt"
            fi
        done
        
        # DNS exfiltration test
        if dig +short test.$(date +%s).portquiz.net &>/dev/null; then
            echo "[CRITICAL] DNS exfiltration possible" >> "$out_dir/payload/findings.txt"
        fi
        
    } > "$out_dir/payload/egress_test.txt"
    
    # 4. Reverse Shell Connectivity Test
    log_info "Testing reverse shell connectivity patterns..."
    {
        echo "=== Reverse Shell Test Patterns ==="
        echo "Common reverse shell ports tested:"
        echo "  - 4444 (Metasploit default)"
        echo "  - 1337 (Common backdoor)"
        echo "  - 443 (HTTPS masquerade)"
        echo "  - 53 (DNS masquerade)"
        echo ""
        echo "Recommendation: Block outbound connections on non-standard ports"
    } > "$out_dir/payload/reverse_shell_test.txt"
    
    # 5. Generate Payload Delivery Report
    {
        echo "# Payload Delivery Test Report"
        echo "Generated: $(date)"
        echo ""
        echo "## Upload Endpoints"
        if [[ -s "$out_dir/payload/upload_endpoints.txt" ]]; then
            cat "$out_dir/payload/upload_endpoints.txt"
        else
            echo "No upload endpoints detected"
        fi
        echo ""
        echo "## Egress Test Results"
        cat "$out_dir/payload/egress.txt" 2>/dev/null || echo "No egress tests performed"
        echo ""
        echo "## Recommendations"
        echo "1. Implement strict file upload validation"
        echo "2. Use file type verification (magic bytes, not just extension)"
        echo "3. Store uploads outside webroot"
        echo "4. Implement egress filtering on firewall"
        echo "5. Monitor for DNS tunneling attempts"
    } > "$out_dir/payload/PAYLOAD_REPORT.md"
    
    # Summary
    # Summary
    local findings_count=0
    if [[ -f "$out_dir/payload/findings.txt" ]]; then
        findings_count=$(wc -l < "$out_dir/payload/findings.txt")
    fi
    if [[ "$findings_count" -gt 0 ]]; then
        log_warn "Payload Delivery Issues Found: $findings_count"
    else
        log_success "No critical payload delivery vulnerabilities found"
    fi
}
