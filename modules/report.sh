#!/bin/bash
# modules/report.sh

# Helper: Count lines in file
count_lines() {
    local file="$1"
    [[ -f "$file" ]] && wc -l < "$file" || echo 0
}

# Helper: Extract findings by severity
extract_findings() {
    local file="$1"
    local severity="$2"
    if [[ -s "$file" ]]; then
        grep -i "\[${severity}\]" "$file" || echo "None"
    else
        echo "None"
    fi
}

generate_report() {
    local target="$1"
    local out_dir="$2"
    local profile="$3"
    
    log_info "Phase 4: Reporting"
    
    local report_file="$out_dir/REPORT.md"
    
    {
        echo "# LazyCat Scan Report"
        echo "**Target:** $target"
        echo "**Date:** $(date)"
        echo "**Profile:** $profile"
        echo "---"
        
        echo "## Summary"
        echo "- Live Hosts: $(count_lines "$out_dir/live_hosts.txt")"
        echo "- Endpoints: $(count_lines "$out_dir/content/endpoints.txt")"
        echo "- Nuclei Findings: $(count_lines "$out_dir/vulns/nuclei_results.txt")"
        echo "- XSS Findings: $(count_lines "$out_dir/vulns/xss.txt")"
        echo ""
        
        echo "## Critical Findings"
        extract_findings "$out_dir/vulns/nuclei_results.txt" "critical"
        
        echo "## High Findings"
        extract_findings "$out_dir/vulns/nuclei_results.txt" "high"

        echo "## XSS Findings"
        if [[ -s "$out_dir/vulns/xss.txt" ]]; then
            cat "$out_dir/vulns/xss.txt"
        else
            echo "None"
        fi

    } > "$report_file"
    
    log_success "Report generated: $report_file"
}
