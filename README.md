# LazyCat Recon Suite 🐱‍👤

**LazyCat** is a modular, automated reconnaissance framework designed for APT-style engagements and Bug Bounty hunting. It automates the boring stuff (discovery, crawling, basic scanning) so you can focus on the fun stuff (exploitation, logic bugs, chaining).

> **Disclaimer**: This tool is for authorized security testing only. The authors are not responsible for misuse.

## 🚀 Features

*   **Modular Architecture**: Each phase is a separate module (`discovery`, `crawling`, `vuln`, etc.).
*   **Smart Profiling**: Choose your noise level (`stealth`, `default`, `noisy`).
*   **Advanced Discovery**: Subdomain enumeration + HTTP probing + WAF detection.
*   **Deep Crawling**: Integrated `katana` for finding hidden endpoints.
*   **Vulnerability Scanning**: `nuclei` with smart tagging and severity filtering.
*   **Special Ops**:
    *   **Secrets Scanning**: Finds API keys and Supply Chain risks (outdated JS).
    *   **Smart SQLi**: Targeted SQLMap injection on dynamic parameters.
    *   **Payload Testing**: Stress tests uploads and checks for RCE.
*   **Professional Reporting**: Generates clean Markdown reports and evidence.

## 📦 Installation

### Prerequisites
*   Linux/macOS
*   `go` (1.21+)
*   `jq`, `curl`, `git`

### Setup
```bash
git clone https://github.com/your-repo/LazyCat.git
cd LazyCat
chmod +x lazycat.sh modules/*.sh
```

### Dependencies
LazyCat relies on the following tools (must be in `$PATH` or `~/go/bin`):
*   `subfinder`
*   `httpx`
*   `nuclei`
*   `katana`
*   `dalfox` (optional, for full profile)
*   `sqlmap` (optional, for SQLi scan)

## 🛠 Usage

### Basic Scan (Default Profile)
```bash
./lazycat.sh -t example.com
```

### Fast Discovery (No heavy scanning)
```bash
./lazycat.sh -t example.com -p fast
```

### Full Assault (Crawling, XSS, SQLi, Fuzzing)
```bash
./lazycat.sh -t example.com -p full
```

### Authenticated Scan
```bash
./lazycat.sh -t target.com --cookie "JSESSIONID=..."
```

### Dry Run (See what will happen)
```bash
./lazycat.sh -t target.com -p noisy --dry-run
```

## ⚙️ Configuration

Edit `config.yaml` to tweak threads, timeouts, and profile settings.

### Profiles
| Profile | Description | Tools |
|---------|-------------|-------|
| `fast` | Quick discovery & critical CVEs | Subfinder, HTTPX, Nuclei (Crit/High) |
| `default` | Balanced recon & scanning | + Katana, Nuclei (Med), Secrets |
| `full` | Deep dive & active fuzzing | + Dalfox, FFUF, SQLMap, Heavy Nuclei |
| `stealth` | Low rate limits, minimal noise | Slow scan, minimal active probing |
| `noisy` | Max threads, all checks | aggressive rate limits |

## 📂 Directory Structure

```
LazyCat/
├── lazycat.sh          # Main entry point
├── config.yaml         # Configuration
├── lib/                # Core libraries
│   ├── utils.sh        # Helpers (Auth, Banner, etc.)
│   ├── logger.sh       # Logging logic
│   └── colors.sh       # UI styling
├── modules/            # Feature modules
│   ├── discovery.sh    # Subdomains & Live hosts
│   ├── crawling.sh     # Katana integration
│   ├── vuln.sh         # Nuclei & Dalfox
│   ├── secrets.sh      # JS Analysis & Key hunting
│   ├── sqli_scan.sh    # Smart SQLMap wrapper
│   └── ...
└── output/             # Scan results (created per target)
```

## 🛡️ Safety & Scope

*   **Scope Enforcement**: Use `-s scope.txt` to strictly limit scanning to allowed hosts.
*   **Rate Limiting**: Default is conservative (150 req/s). Use `stealth` profile for sensitive targets (30 req/s).
*   **WAF Detection**: Automatically detects WAFs and warns before aggressive scanning.

## 🤝 Contributing

Pull requests are welcome! Please follow the `set -euo pipefail` standard and use the `log_*` functions.

---
*v1.0.0 - "Get some coffee and chill"*
