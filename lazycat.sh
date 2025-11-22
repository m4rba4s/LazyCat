#!/bin/bash
# lazycat.sh - "The LazyCat Recon Suite"
# Author: the 0utspoken & metal gear
# Description: Modular, Configurable, Professional Recon Framework

# Resolve Script Directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load Libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logger.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# Load Modules
source "$SCRIPT_DIR/modules/discovery.sh"
source "$SCRIPT_DIR/modules/crawling.sh"
source "$SCRIPT_DIR/modules/vuln.sh"
source "$SCRIPT_DIR/modules/report.sh"

# Trap Interrupts
trap cleanup SIGINT SIGTERM

# --- MAIN ---
main() {
    # Defaults
    TARGET=""
    OUT_DIR=""
    SCOPE_FILE=""
    PROFILE="default"
    CONFIG_FILE="$SCRIPT_DIR/config.yaml"

    # Parse Args
    while getopts "t:o:s:p:c:h" opt; do
        case "$opt" in
            t) TARGET="$OPTARG" ;;
            o) OUT_DIR="$OPTARG" ;;
            s) SCOPE_FILE="$OPTARG" ;;
            p) PROFILE="$OPTARG" ;;
            c) CONFIG_FILE="$OPTARG" ;;
            h) 
                echo "Usage: $0 -t <target> [-p fast|default|full] [-s scope.txt] [-o output_dir]"
                exit 0 
                ;;
            *) exit 1 ;;
        esac
    done

    if [[ -z "$TARGET" ]]; then
        echo -e "${RED}[!] Target (-t) is required.${NC}"
        exit 1
    fi

    # Setup Workspace
    if [[ -z "$OUT_DIR" ]]; then
        OUT_DIR="lazycat_${TARGET}_$(date +%F_%H%M)"
    fi
    mkdir -p "$OUT_DIR"/{content,vulns}
    
    # Init Logger
    export LOG_FILE="$OUT_DIR/run.log"
    banner

    log_info "Loading configuration from $CONFIG_FILE..."
    # Parse YAML config into bash variables (e.g. tools_nuclei_rate_limit)
    eval $(parse_yaml "$CONFIG_FILE")

    log_info "Starting LazyCat on $TARGET using profile: $PROFILE"

    # 1. Discovery
    run_discovery "$TARGET" "$OUT_DIR" "$SCOPE_FILE"

    # 2. Crawling (if enabled in profile)
    local crawl_enabled="profiles_${PROFILE}_katana"
    if [[ "${!crawl_enabled}" == "true" ]]; then
        run_crawling "$OUT_DIR"
    else
        log_info "Skipping Crawling (disabled in profile)"
    fi

    # 3. Vulnerability Scanning
    run_vuln_scan "$OUT_DIR" "$PROFILE"

    # 4. Reporting
    generate_report "$TARGET" "$OUT_DIR" "$PROFILE"

    log_success "Scan Complete! Results in: $OUT_DIR"
}

main "$@"
