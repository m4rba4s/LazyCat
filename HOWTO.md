# 📖 LazyCat Manual

## Usage
```bash
./lazycat.sh -t <target> [options]
```

### Flags
| Flag | Description | Required | Default |
|------|-------------|----------|---------|
| `-t` | Target domain (e.g., `example.com`) | **Yes** | - |
| `-p` | Scan Profile (`fast`, `default`, `full`) | No | `default` |
| `-o` | Custom output directory | No | `lazycat_<target>_<date>` |
| `-s` | Scope file (list of allowed subdomains) | No | - |
| `-c` | Custom config file | No | `config.yaml` |

## 🎭 Profiles

### 1. Fast (`-p fast`)
*   **Goal**: Quick triage.
*   **Tools**: `subfinder`, `httpx`, `nuclei` (critical/high only).
*   **Use Case**: Initial recon, "is it alive?" checks.

### 2. Default (`-p default`)
*   **Goal**: Standard assessment.
*   **Tools**: `subfinder`, `httpx`, `katana` (depth 3), `nuclei` (crit/high/med).
*   **Use Case**: Typical pentest or bug bounty run.

### 3. Full (`-p full`)
*   **Goal**: Deep dive.
*   **Tools**: `subfinder`, `httpx`, `katana` (deep), `nuclei` (all severities), `dalfox`, `ffuf`.
*   **Use Case**: Overnight scans, thorough audits.

## ⚙️ Configuration
Edit `config.yaml` to tweak performance:

```yaml
threads: 4          # Global threads (auto-detects cores if not set)
timeout: "300"      # Global timeout in seconds

tools:
  nuclei:
    rate_limit: 150
    concurrency: 25
```

## 📦 Installation
Ensure you have the required tools in your `$PATH` or `~/go/bin`:
```bash
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
go install -v github.com/hahwul/dalfox/v2@latest
```
