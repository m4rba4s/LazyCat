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
source "$SCRIPT_DIR/modules/dns_security.sh"
source "$SCRIPT_DIR/modules/tls_audit.sh"
source "$SCRIPT_DIR/modules/smb_audit.sh"
source "$SCRIPT_DIR/modules/service_exploit.sh"
source "$SCRIPT_DIR/modules/payload_test.sh"
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
    DRY_RUN="false"
    AUTH_COOKIE=""
    AUTH_HEADER=""

    # Parse Args (Manual loop to support long options)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--target) TARGET="$2"; shift 2 ;;
            -o|--output) OUT_DIR="$2"; shift 2 ;;
            -s|--scope) SCOPE_FILE="$2"; shift 2 ;;
            -p|--profile) PROFILE="$2"; shift 2 ;;
            -c|--config) CONFIG_FILE="$2"; shift 2 ;;
            --cookie) AUTH_COOKIE="$2"; shift 2 ;;
            --auth-header) AUTH_HEADER="$2"; shift 2 ;;
            --dry-run|--plan) DRY_RUN="true"; shift 1 ;;
            -h|--help) 
                echo "Usage: $0 -t <target> [-p fast|default|full|stealth|noisy] [--dry-run] [--cookie \"...\"]"
                exit 0 
                ;;
            *) echo "Unknown option: $1"; exit 1 ;;
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
    
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$OUT_DIR"/{content,vulns,evidence}
        export LOG_FILE="$OUT_DIR/run.log"
    else
        echo -e "${YELLOW}[PLAN] Dry-run mode enabled. No changes will be made.${NC}"
    fi
    
    banner

    log_info "Loading configuration from $CONFIG_FILE..."
    # Parse YAML config into bash variables
    eval $(parse_yaml "$CONFIG_FILE")

    # Override Auth from CLI
    if [[ -n "$AUTH_COOKIE" ]]; then
        auth_cookie="$AUTH_COOKIE"
        log_info "Auth Cookie provided via CLI"
    fi
    if [[ -n "$AUTH_HEADER" ]]; then
        auth_header="$AUTH_HEADER"
        log_info "Auth Header provided via CLI"
    fi

    log_info "Starting LazyCat on $TARGET using profile: $PROFILE"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[PLAN] Target: $TARGET"
        log_info "[PLAN] Profile: $PROFILE"
        log_info "[PLAN] Output: $OUT_DIR"
        log_info "[PLAN] Auth: $([[ -n "$auth_cookie" || -n "$auth_header" ]] && echo "YES" || echo "NO")"
        
        # Simulate Discovery
        log_info "[PLAN] Step 1: Discovery (Subfinder + HTTPX)"
        
        # Simulate Crawling
        local crawl_enabled="profiles_${PROFILE}_katana"
        if [[ "${!crawl_enabled}" == "true" ]]; then
            log_info "[PLAN] Step 2: Crawling (Katana) - Enabled"
        else
            log_info "[PLAN] Step 2: Crawling - Disabled"
        fi
        
        # Simulate Vuln Scan
        local nuclei_tags="profiles_${PROFILE}_nuclei_tags"
        local nuclei_sev="profiles_${PROFILE}_nuclei_severity"
        local nuclei_rate="profiles_${PROFILE}_nuclei_rate_limit" # Check for override
        [[ -z "${!nuclei_rate}" ]] && nuclei_rate="${tools_nuclei_rate_limit}"
        
        log_info "[PLAN] Step 3: Vuln Scan (Nuclei)"
        log_info "[PLAN]   Tags: ${!nuclei_tags}"
        log_info "[PLAN]   Severity: ${!nuclei_sev}"
        log_info "[PLAN]   Rate Limit: ${!nuclei_rate}"
        
        return 0
    fi

    # 1. Discovery
    run_discovery "$TARGET" "$OUT_DIR" "$SCOPE_FILE"

    # 1.5 DNS Security Audit
    run_dns_security "$TARGET" "$OUT_DIR"
    
    # 1.6 TLS/SSL Audit
    run_tls_audit "$OUT_DIR"

    # 2. Network Exploitation Tests
    run_smb_audit "$OUT_DIR"
    run_service_exploit "$OUT_DIR"
    run_payload_test "$OUT_DIR"

    # 3. Crawling (if enabled in profile)
    local crawl_enabled="profiles_${PROFILE}_katana"
    if [[ "${!crawl_enabled}" == "true" ]]; then
        run_crawling "$OUT_DIR"
    else
        log_info "Skipping Crawling (disabled in profile)"
    fi

    # 4. Vulnerability Scanning
    run_vuln_scan "$OUT_DIR" "$PROFILE"

    # 5. Reporting
    generate_report "$TARGET" "$OUT_DIR" "$PROFILE"

    log_success "Scan Complete! Results in: $OUT_DIR"
}

main "$@"
