#!/bin/bash
# modules/report.sh

generate_report() {
    local target="$1"
    local out_dir="$2"
    local profile="$3"
    
    log_info "Phase 4: Reporting"
    
    local report_file="$out_dir/REPORT.md"
    
    {
        echo "# Recon-v7 Scan Report"
        echo "**Target:** $target"
        echo "**Date:** $(date)"
        echo "**Profile:** $profile"
        echo "---"
        
        echo "## Summary"
        echo "- Live Hosts: $([ -f "$out_dir/live_hosts.txt" ] && wc -l < "$out_dir/live_hosts.txt" || echo 0)"
        echo "- Endpoints: $([ -f "$out_dir/content/endpoints.txt" ] && wc -l < "$out_dir/content/endpoints.txt" || echo 0)"
        echo "- Nuclei Findings: $([ -f "$out_dir/vulns/nuclei_results.txt" ] && wc -l < "$out_dir/vulns/nuclei_results.txt" || echo 0)"
        echo "- XSS Findings: $([ -f "$out_dir/vulns/xss.txt" ] && wc -l < "$out_dir/vulns/xss.txt" || echo 0)"
        echo ""
        
        echo "## Critical Findings"
        if [[ -s "$out_dir/vulns/nuclei_results.txt" ]]; then
            grep "\[critical\]" "$out_dir/vulns/nuclei_results.txt" || echo "None"
        else
            echo "None"
        fi
        
        echo "## High Findings"
        if [[ -s "$out_dir/vulns/nuclei_results.txt" ]]; then
            grep "\[high\]" "$out_dir/vulns/nuclei_results.txt" || echo "None"
        else
            echo "None"
        fi

        echo "## XSS Findings"
        if [[ -s "$out_dir/vulns/xss.txt" ]]; then
            cat "$out_dir/vulns/xss.txt"
        else
            echo "None"
        fi

    } > "$report_file"
    
    log_success "Report generated: $report_file"
}
