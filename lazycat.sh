#!/bin/bash
# LazyCat - The APT Recon Suite
# Author: Mary Jane (Agent)
# Version: 1.0.0

set -euo pipefail
IFS=$'\n\t'

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Source Libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logger.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# Source Modules
source "$SCRIPT_DIR/modules/discovery.sh"
source "$SCRIPT_DIR/modules/dns_security.sh"
source "$SCRIPT_DIR/modules/tls_audit.sh"
source "$SCRIPT_DIR/modules/smb_audit.sh"
source "$SCRIPT_DIR/modules/service_exploit.sh"
source "$SCRIPT_DIR/modules/payload_test.sh"
source "$SCRIPT_DIR/modules/secrets.sh"
source "$SCRIPT_DIR/modules/sqli_scan.sh"
source "$SCRIPT_DIR/modules/crawling.sh"
source "$SCRIPT_DIR/modules/vuln.sh"
source "$SCRIPT_DIR/modules/report.sh"

# Trap Interrupts
trap cleanup SIGINT SIGTERM

require_tools() {
    local missing=0
    for tool in "$@"; do
        if ! check_dependency "$tool"; then
            missing=1
        fi
    done

    if [[ "$missing" -ne 0 ]]; then
        log_crit "Missing required dependencies. Install the tools above and re-run."
        exit 1
    fi
}

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

    # Target Normalization
    RAW_TARGET="$TARGET"
    if [[ ! "$TARGET" =~ ^https?:// ]]; then
        TARGET="https://$TARGET"
    fi
    # Extract host for naming
    TARGET_HOST=$(echo "$TARGET" | sed -e 's|^[^/]*//||' -e 's|/.*$||')

    # Scope Check
    if [[ -n "$SCOPE_FILE" ]]; then
        if [[ ! -f "$SCOPE_FILE" ]]; then
             log_crit "Scope file not found: $SCOPE_FILE"
             exit 1
        fi
        if ! grep -qF "$TARGET_HOST" "$SCOPE_FILE"; then
            log_warn "Target $TARGET_HOST is not present in scope file $SCOPE_FILE"
            log_warn "Refusing to scan outside of scope."
            exit 1
        fi
    fi

    # Setup Workspace
    if [[ -z "$OUT_DIR" ]]; then
        OUT_DIR="lazycat_${TARGET_HOST}_$(date +%F_%H%M)"
    fi
    
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$OUT_DIR"/{content,vulns,evidence}
        export LOG_FILE="$OUT_DIR/run.log"
    else
        echo -e "${YELLOW}[PLAN] Dry-run mode enabled. No changes will be made.${NC}"
        # Dummy log file for dry run to avoid unbound variable errors
        export LOG_FILE="/dev/null"
    fi
    
    banner

    log_info "Loading configuration from $CONFIG_FILE..."
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_crit "Config file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Parse YAML config into bash variables (Safe Eval)
    eval "$(parse_yaml "$CONFIG_FILE")"

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

    # Dependency preflight (profile-aware)
    local core_tools=(subfinder httpx nuclei curl dig jq)
    local profile_katana="profiles_${PROFILE}_katana"
    local profile_dalfox="profiles_${PROFILE}_dalfox"

    # katana if profile enables crawling
    if [[ "${!profile_katana:-false}" == "true" ]]; then
        core_tools+=(katana)
    fi

    # dalfox if enabled
    if [[ "${!profile_dalfox:-false}" == "true" ]]; then
        core_tools+=(dalfox)
    fi

    # sqlmap only when profile runs SQLi
    if [[ "$PROFILE" != "fast" && "$PROFILE" != "stealth" ]]; then
        core_tools+=(sqlmap)
    fi

    # nmap used in SMB/service scanning
    core_tools+=(nmap)

    require_tools "${core_tools[@]}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[PLAN] Target: $TARGET"
        log_info "[PLAN] Profile: $PROFILE"
        log_info "[PLAN] Output: $OUT_DIR"
        log_info "[PLAN] Auth: $([[ -n "${auth_cookie-}" || -n "${auth_header-}" ]] && echo "YES" || echo "NO")"
        
        # Simulate Discovery
        log_info "[PLAN] Step 1: Discovery (Subfinder + HTTPX)"
        log_info "[PLAN] Step 1.5: DNS & TLS Security Audit"
        log_info "[PLAN] Step 1.9: WAF Detection"
        log_info "[PLAN] Step 2: Network Exploitation (SMB, Services, Payloads)"
        log_info "[PLAN] Step 2.4: Secrets & Supply Chain Analysis"
        log_info "[PLAN] Step 2.5: Smart SQL Injection Scan"
        
        # Simulate Crawling
        local crawl_var="profiles_${PROFILE}_katana"
        local crawl_enabled="${!crawl_var-false}"
        if [[ "$crawl_enabled" == "true" ]]; then
            log_info "[PLAN] Step 2: Crawling (Katana) - Enabled"
        else
            log_info "[PLAN] Step 2: Crawling - Disabled"
        fi
        
        # Simulate Vuln Scan
        local tags_var="profiles_${PROFILE}_nuclei_tags"
        local sev_var="profiles_${PROFILE}_nuclei_severity"
        local nuclei_tags="${!tags_var-}"
        local nuclei_sev="${!sev_var-}"
        
        # Handle Rate Limit Override
        local rate_var="profiles_${PROFILE}_nuclei_rate_limit"
        local final_rate="${!rate_var-}"
        [[ -z "$final_rate" ]] && final_rate="${tools_nuclei_rate_limit-150}"
        
        log_info "[PLAN] Step 3: Vuln Scan (Nuclei)"
        log_info "[PLAN]   Tags: $nuclei_tags"
        log_info "[PLAN]   Severity: $nuclei_sev"
        log_info "[PLAN]   Rate Limit: $final_rate"
        
        return 0
    fi

    # 1. Discovery (use host-only for subdomain enumeration)
    run_discovery "$TARGET_HOST" "$OUT_DIR" "$SCOPE_FILE"

    # 1.5 DNS Security Audit
    run_dns_security "$TARGET" "$OUT_DIR"
    
    # 1.6 TLS/SSL Audit
    run_tls_audit "$OUT_DIR"

    # WAF Detection (Pro Feature)
    log_info "Phase 1.9: WAF & CDN Detection"
    local waf_sig
    waf_sig=$(curl -I -s -k --max-time 5 "$TARGET" 2>/dev/null | grep -iE "(server|x-cdn|x-waf|cloudflare|akamai|imperva)" || true)
    
    if [[ -n "$waf_sig" ]]; then
        log_warn "WAF/CDN Detected:"
        echo "$waf_sig" | sed 's/^/  /'
        echo "$waf_sig" > "$OUT_DIR/waf_detection.txt"
    else
        log_info "No obvious WAF signatures found"
    fi

    # 2. Network Exploitation Tests
    run_smb_audit "$OUT_DIR"
    run_service_exploit "$OUT_DIR"
    run_payload_test "$OUT_DIR"
    run_secrets_scan "$OUT_DIR"
    run_sqli_scan "$OUT_DIR" "$PROFILE"

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
