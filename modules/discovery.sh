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
        subfinder -d "$target" -silent -all -o "$out_dir/subs_raw.txt"
    else
        echo "$target" > "$out_dir/subs_raw.txt"
    fi
    
    # Always append the root target
    echo "$target" >> "$out_dir/subs_raw.txt"
    sort -u -o "$out_dir/subs_raw.txt" "$out_dir/subs_raw.txt"

    # 2. Scope Filtering
    if [[ -n "$scope_file" ]]; then
        log_info "Applying Scope Filter..."
        grep -Ff "$scope_file" "$out_dir/subs_raw.txt" > "$out_dir/subs_scoped.txt"
        local diff=$(($(wc -l < "$out_dir/subs_raw.txt") - $(wc -l < "$out_dir/subs_scoped.txt")))
        log_warn "Excluded $diff out-of-scope subdomains."
    else
        cp "$out_dir/subs_raw.txt" "$out_dir/subs_scoped.txt"
    fi

    # 3. Live Host Verification
    log_info "Checking Live Hosts (HTTPX)..."
    cat "$out_dir/subs_scoped.txt" | httpx -silent \
        -threads "${tools_httpx_threads:-40}" \
        -retries "${tools_httpx_retries:-2}" \
        -timeout "${timeout:-300}" \
        -random-agent \
        -tech-detect -status-code -title \
        -o "$out_dir/live_hosts.txt"

    local count=$(wc -l < "$out_dir/live_hosts.txt")
    log_success "Live Assets: $count"
    
    if [[ "$count" -eq 0 ]]; then
        log_crit "No live hosts found. Exiting."
        exit 1
    fi

    # Extract URLs
    awk '{print $1}' "$out_dir/live_hosts.txt" > "$out_dir/urls.txt"
}
