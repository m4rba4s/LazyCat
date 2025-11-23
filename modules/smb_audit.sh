#!/bin/bash
# modules/smb_audit.sh
# SMB/NetBIOS Security Audit Module

run_smb_audit() {
    local out_dir="$1"
    
    log_info "Phase 2.1: SMB/NetBIOS Security Audit"
    
    mkdir -p "$out_dir/smb"
    
    # Extract unique IPs from live hosts
    local ip_list="$out_dir/smb/target_ips.txt"
    if [[ -f "$out_dir/live_hosts.txt" ]]; then
        awk '{print $1}' "$out_dir/live_hosts.txt" | \
            sed 's|https\?://||' | cut -d'/' -f1 | \
            grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u > "$ip_list"
    fi
    
    # If no IPs, try to resolve from URLs
    if [[ ! -s "$ip_list" ]]; then
        log_info "Resolving IPs from hostnames..."
        while read -r url; do
            local host=$(echo "$url" | sed 's|https\?://||' | cut -d'/' -f1)
            dig +short "$host" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' >> "$ip_list"
        done < "$out_dir/urls.txt"
        sort -u -o "$ip_list" "$ip_list"
    fi
    
    local ip_count=$(wc -l < "$ip_list" 2>/dev/null || echo 0)
    if [[ "$ip_count" -eq 0 ]]; then
        log_warn "No IPs found for SMB scanning"
        return 0
    fi
    
    log_info "Scanning $ip_count targets for SMB vulnerabilities..."
    
    # 1. SMB Version Detection & EternalBlue Check
    log_info "Running SMB version detection..."
    while read -r ip; do
        [[ -z "$ip" ]] && continue
        
        log_info "Scanning $ip..."
        {
            echo "=== SMB Scan for $ip ==="
            
            # Nmap SMB scripts
            nmap -p 445,139 --script smb-protocols,smb-security-mode,smb-vuln-ms17-010,smb-vuln-cve-2020-0796 \
                -Pn --open "$ip" 2>/dev/null
            
            echo ""
        } >> "$out_dir/smb/scan_results.txt"
        
        # Check for critical vulns
        if grep -q "VULNERABLE" "$out_dir/smb/scan_results.txt"; then
            echo "[CRITICAL] SMB vulnerability detected on $ip" >> "$out_dir/smb/findings.txt"
        fi
        
        # Check for SMBv1
        if grep -q "SMBv1" "$out_dir/smb/scan_results.txt"; then
            echo "[HIGH] SMBv1 enabled on $ip (EternalBlue risk)" >> "$out_dir/smb/findings.txt"
        fi
        
    done < "$ip_list"
    
    # 2. Share Enumeration (if enum4linux available)
    if command -v enum4linux &>/dev/null; then
        log_info "Enumerating SMB shares..."
        while read -r ip; do
            [[ -z "$ip" ]] && continue
            
            log_info "Enumerating shares on $ip..."
            timeout 60 enum4linux -S "$ip" >> "$out_dir/smb/shares_${ip}.txt" 2>&1
            
            # Check for open shares
            if grep -q "Mapping:" "$out_dir/smb/shares_${ip}.txt"; then
                echo "[MEDIUM] Open SMB shares found on $ip" >> "$out_dir/smb/findings.txt"
            fi
        done < "$ip_list"
    else
        log_warn "enum4linux not found, skipping share enumeration"
    fi
    
    # 3. Null Session Check
    log_info "Testing for null sessions..."
    while read -r ip; do
        [[ -z "$ip" ]] && continue
        
        if smbclient -L "//$ip" -N &>/dev/null; then
            echo "[HIGH] Null session allowed on $ip" >> "$out_dir/smb/findings.txt"
            log_warn "⚠️  Null session allowed on $ip"
        fi
    done < "$ip_list"
    
    # Summary
    local findings_count=0
    if [[ -f "$out_dir/smb/findings.txt" ]]; then
        findings_count=$(wc -l < "$out_dir/smb/findings.txt")
    fi
    if [[ "$findings_count" -gt 0 ]]; then
        log_warn "SMB Security Issues Found: $findings_count"
    else
        log_success "No critical SMB vulnerabilities found"
    fi
}
