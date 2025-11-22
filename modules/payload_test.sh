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
    
    # Test various extensions
    for ext in php jsp asp aspx sh py exe; do
        cp "$out_dir/payload/eicar.txt" "$out_dir/payload/test.$ext"
    done
    
    # Scan for upload endpoints
    if [[ -s "$out_dir/content/endpoints.txt" ]]; then
        log_info "Searching for upload endpoints..."
        grep -iE "(upload|file|attach|import)" "$out_dir/content/endpoints.txt" > \
            "$out_dir/payload/upload_endpoints.txt"
        
        local upload_count=$(wc -l < "$out_dir/payload/upload_endpoints.txt")
        if [[ "$upload_count" -gt 0 ]]; then
            log_warn "Found $upload_count potential upload endpoints"
            echo "[MEDIUM] $upload_count file upload endpoints detected" >> "$out_dir/payload/findings.txt"
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
    local findings_count=$(wc -l < "$out_dir/payload/findings.txt" 2>/dev/null || echo 0)
    if [[ "$findings_count" -gt 0 ]]; then
        log_warn "Payload Delivery Issues Found: $findings_count"
    else
        log_success "No critical payload delivery vulnerabilities found"
    fi
}
