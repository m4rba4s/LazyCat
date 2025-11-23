#!/bin/bash
# modules/sqli_scan.sh
# Smart SQL Injection Scanner Module

run_sqli_scan() {
    local out_dir="$1"
    local profile="$2"
    
    # Only run in default or full/noisy profiles
    if [[ "$profile" == "fast" || "$profile" == "stealth" ]]; then
        log_info "Skipping SQLi Scan (disabled in $profile profile)"
        return 0
    fi
    
    log_info "Phase 2.5: Smart SQL Injection Scanning"
    
    if ! command -v sqlmap &>/dev/null; then
        log_warn "sqlmap not found, skipping SQLi scan"
        return 0
    fi
    
    mkdir -p "$out_dir/sqli"
    
    # 1. Identify Parameterized URLs
    if [[ -s "$out_dir/content/endpoints.txt" ]]; then
        log_info "Identifying parameterized URLs..."
        grep "=" "$out_dir/content/endpoints.txt" | sort -u > "$out_dir/sqli/params.txt"
        
        local param_count=$(wc -l < "$out_dir/sqli/params.txt")
        if [[ "$param_count" -eq 0 ]]; then
            log_info "No parameterized URLs found for SQLi testing"
            return 0
        fi
        
        # Limit targets to avoid taking forever
        local max_targets=20
        if [[ "$profile" == "noisy" ]]; then max_targets=100; fi
        
        head -n "$max_targets" "$out_dir/sqli/params.txt" > "$out_dir/sqli/targets.txt"
        log_info "Selected top $(wc -l < "$out_dir/sqli/targets.txt") targets for Smart SQLi scan"
        
        # 2. Run SQLMap (Smart Mode)
        log_info "Running SQLMap (Smart Mode)..."
        
        # SQLMap Args:
        # --batch: Never ask for user input
        # --smart: Scan only if heuristic positive
        # --random-agent: Use random User-Agent
        # --level 1 --risk 1: Safe scan
        # --forms: Parse forms (optional, we use URLs here)
        
        sqlmap -m "$out_dir/sqli/targets.txt" \
            --batch --smart --random-agent \
            --level 1 --risk 1 \
            --output-dir="$out_dir/sqli/output" \
            --results-file="$out_dir/sqli/findings.csv" \
            > "$out_dir/sqli/sqlmap.log" 2>&1
            
        # 3. Analyze Results
        if [[ -f "$out_dir/sqli/findings.csv" ]]; then
            local findings=$(grep -c "," "$out_dir/sqli/findings.csv")
            if [[ "$findings" -gt 0 ]]; then
                log_warn "SQL Injection Vulnerabilities Found: $findings"
                echo "[CRITICAL] SQL Injection found! Check $out_dir/sqli/findings.csv" >> "$out_dir/sqli/findings.txt"
            else
                log_success "No SQLi vulnerabilities confirmed by SQLMap"
            fi
        else
            log_info "SQLMap finished with no findings"
        fi
        
    else
        log_info "No endpoints available for SQLi scan"
    fi
}
