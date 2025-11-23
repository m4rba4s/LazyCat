#!/bin/bash
# lib/utils.sh

check_dependency() {
    local tool="$1"
    if ! command -v "$tool" &>/dev/null; then
        log_crit "Dependency missing: $tool"
        log_info "Attempting to locate in common paths..."
        
        # Check Go bin
        if [[ -f "$HOME/go/bin/$tool" ]]; then
            export PATH=$PATH:$HOME/go/bin
            log_success "Found $tool in ~/go/bin"
            return 0
        fi
        
        log_warn "Please install $tool (e.g., 'go install ...' or 'brew install ...')"
        return 1
    fi
}

parse_yaml() {
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -e 's/#.*//' "$1" | tr -d '\r' | sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" |
    awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
    }'
}

cleanup() {
    log_warn "Interrupted! Cleaning up..."
    kill 0 2>/dev/null || true
    wait 2>/dev/null || true
    exit 1
}

banner() {
    echo -e "${CYAN}"
    echo "    __                        ______      __ "
    echo "   / /   ____  ____  __  __  / ____/___ _/ /_"
    echo "  / /   / __ \/_  / / / / / / /   / __ \/ __/"
    echo " / /___/ /_/ / / /_/ /_/ / / /___/ /_/ / /_  "
    echo "/_____/\__,_/ /___/\__, /  \____/\__,_/\__/  "
    echo "                  /____/                     "
    echo -e "${NC}"
    echo -e "${BOLD}LazyCat - now get some cofee and chill${NC}"
    echo -e "Target: ${TARGET:-None} | Profile: ${PROFILE:-Default}"
    echo "------------------------------------------------"
}

get_cpu_count() {
    if command -v nproc &>/dev/null; then
        nproc
    elif command -v sysctl &>/dev/null; then
        sysctl -n hw.ncpu 2>/dev/null || echo 4
    else
        echo 4
    fi
}
