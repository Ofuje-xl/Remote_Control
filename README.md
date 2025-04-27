# SilentRecon

**SilentRecon** is a Bash script for performing domain reconnaissance and security scanning. It extracts essential WHOIS information, scans for open ports using Nmap, and ensures anonymity by routing the operations through the Tor network.

## Features
- **WHOIS Information**: Extracts registrar, organization, country, and domain creation/expiry dates.
- **Open Port Scanning**: Uses Nmap to detect open ports and services on a domain.
- **Tor Anonymity**: Ensures all scans are done anonymously over Tor.
- **Remote Scanning**: Supports remote domain scanning via SSH.
- **Clean Reports**: Generates easy-to-read reports with all the important findings.

## Requirements
- Nmap
- Tor
- SSH access for remote scanning
- WHOIS and Curl for data gathering

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/ofuje-xl/SilentRecon.git
   
2. chmod +x SilentRecon.sh

## Usage 
1. Run the script to perform a domain scan:
   ./SilentRecon.sh

2. The script will generate a report with WHOIS details, open ports, and other relevant information.
