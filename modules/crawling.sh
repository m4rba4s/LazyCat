#!/bin/bash
# modules/crawling.sh

run_crawling() {
    local out_dir="$1"
    
    log_info "Phase 2: Deep Crawling (Katana)"
    
    katana -list "$out_dir/urls.txt" -jc -kf -silent \
        -c "${tools_katana_concurrency:-10}" \
        -d "${tools_katana_depth:-3}" \
        -H "User-Agent: ${user_agent}" \
        -o "$out_dir/content/endpoints.txt"
        
    local count=$(wc -l < "$out_dir/content/endpoints.txt")
    log_success "Crawled Endpoints: $count"
}
