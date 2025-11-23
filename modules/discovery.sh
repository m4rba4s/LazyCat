#!/bin/bash
# modules/discovery.sh

run_discovery() {
    local target="$1"
    local out_dir="$2"
    local scope_file="$3"
    
    log_info "Phase 1: Discovery (Subfinder & HTTPX)"
    
    # 1. Subdomain Enumeration
    local subfinder_enabled="profiles_${PROFILE}_subfinder"
    if [[ "${!subfinder_enabled:-true}" == "true" ]]; then
        log_info "Running Subfinder..."
        subfinder -d "$target" -silent -all -o "$out_dir/subs_raw.txt" || true
    else
        echo "$target" > "$out_dir/subs_raw.txt"
    fi
    
    # Always append the root target
    echo "$target" >> "$out_dir/subs_raw.txt"
    sort -u -o "$out_dir/subs_raw.txt" "$out_dir/subs_raw.txt"

    # 2. Scope Filtering
    if [[ -n "$scope_file" ]]; then
        log_info "Applying Scope Filter..."
        grep -Ff "$scope_file" "$out_dir/subs_raw.txt" > "$out_dir/subs_scoped.txt" || true
        local diff=$(($(wc -l < "$out_dir/subs_raw.txt") - $(wc -l < "$out_dir/subs_scoped.txt")))
        log_warn "Excluded $diff out-of-scope subdomains."
    else
        cp "$out_dir/subs_raw.txt" "$out_dir/subs_scoped.txt"
    fi

    # 2. HTTPX Probing
    log_info "Running HTTPX..."
    
    local auth_args=($(build_auth_args))
    
    cat "$out_dir/subs_scoped.txt" | httpx -silent \
        -threads "${tools_httpx_threads:-40}" \
        "${auth_args[@]}" \
        -retries "${tools_httpx_retries:-2}" \
        -timeout "${timeout:-300}" \
        -random-agent \
        -ports "80,443,8080,8443,4443,8000,8008,8888,9443,10443" \
        -tech-detect -status-code -title \
        -o "$out_dir/live_hosts.txt" || true

    local count=0
    if [[ -f "$out_dir/live_hosts.txt" ]]; then
        count=$(wc -l < "$out_dir/live_hosts.txt")
    fi
    log_success "Live Assets: $count"
    
    if [[ "$count" -eq 0 ]]; then
        log_crit "No live hosts found. Exiting."
        exit 1
    fi

    # Extract URLs
    awk '{print $1}' "$out_dir/live_hosts.txt" > "$out_dir/urls.txt"
}
