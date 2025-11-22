# 😼 LazyCat
**The APT Recon Suite**

> *Minimum Effort. Maximum Impact.*

LazyCat is a modular, configurable, and stealthy reconnaissance framework designed for Red Teams and Bug Bounty hunters. It automates the boring stuff so you can focus on the hacking.

## 🚀 Features
*   **Modular Architecture**: Split into Discovery, Crawling, Vuln Scanning, and Reporting.
*   **Smart Profiles**: Choose your intensity (`fast`, `default`, `full`).
*   **YAML Configuration**: Tune threads, timeouts, and rate limits without touching code.
*   **Cross-Platform**: Runs smoothly on Linux and macOS.
*   **Stealthy**: Randomized User-Agents and smart rate limiting.

## ⚡ Quick Start
```bash
# 1. Clone & Enter
git clone https://github.com/yourusername/LazyCat.git
cd LazyCat

# 2. Run a Fast Scan
./lazycat.sh -t target.com -p fast
```

## 🛠️ Requirements
*   `bash`, `curl`, `sed`, `awk`
*   **Go Tools**: `subfinder`, `httpx`, `katana`, `nuclei`, `dalfox`

## 📂 Output
Results are saved in `lazycat_<target>_<date>/`:
*   `content/`: Crawled endpoints.
*   `vulns/`: Nuclei and Dalfox findings.
*   `REPORT.md`: Consolidated summary.

---
*By 0utspoken & metal gear*
# LazyCat
