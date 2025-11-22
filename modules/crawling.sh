#!/bin/bash
# modules/crawling.sh

run_crawling() {
    local out_dir="$1"
    
    log_info "Phase 2: Deep Crawling (Katana)"
    
    # Prepare Auth Headers
    local auth_args=()
    auth_args+=(-H "User-Agent: ${user_agent}")
    if [[ -n "$auth_cookie" ]]; then
        auth_args+=(-H "Cookie: $auth_cookie")
    fi
    if [[ -n "$auth_header" ]]; then
        auth_args+=(-H "$auth_header")
    fi
    
    katana -list "$out_dir/urls.txt" -jc -kf -silent \
        -c "${tools_katana_concurrency:-10}" \
        -d "${tools_katana_depth:-3}" \
        "${auth_args[@]}" \
        -o "$out_dir/content/endpoints.txt"
        
    local count=$(wc -l < "$out_dir/content/endpoints.txt")
    log_success "Crawled Endpoints: $count"
}
