#!/bin/bash
# modules/crawling.sh

run_crawling() {
    local out_dir="$1"
    
    log_info "Phase 2: Deep Crawling (Katana)"
    
    # Prepare Auth Headers
    local auth_args=()
    log_info "Running Katana..."
    
    local auth_args=($(build_auth_args))
    
    katana -list "$out_dir/live_hosts.txt" \
        -d "${tools_katana_depth:-3}" \
        -c "${tools_katana_concurrency:-10}" \
        "${auth_args[@]}" \
        -silent \
        -o "$out_dir/content/endpoints.txt"
        
    local count=$(wc -l < "$out_dir/content/endpoints.txt")
    log_success "Crawled Endpoints: $count"
}
