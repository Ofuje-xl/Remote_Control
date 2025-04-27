#!/bin/bash

# === Colors for pretty output ===
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# === Function to install a package ===
install_package() {
    local package="$1"
    echo -e "${YELLOW}Installing $package...${RESET}"
    
    if [ -x "$(command -v apt)" ]; then
        sudo apt update && sudo apt install -y "$package"
    elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install -y "$package"
    elif [ -x "$(command -v pacman)" ]; then
        sudo pacman -Sy "$package" --noconfirm
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y "$package"
    else
        echo -e "${RED}Unsupported package manager. Please install $package manually.${RESET}"
        exit 1
    fi

    echo -e "${GREEN}$package installed successfully!${RESET}"
}

# === Install Nipe if not installed ===
install_nipe() {
    if [ -d "nipe" ]; then
        echo -e "${GREEN}Nipe is already installed!${RESET}"
    else
        echo -e "${YELLOW}Installing Nipe...${RESET}"
        git clone https://github.com/htrgouvea/nipe.git
        cd nipe || exit
        sudo perl nipe.pl install
        cd .. || exit
        echo -e "${GREEN}Nipe installed successfully!${RESET}"
    fi
}

# === Resolve domain to IP ===
resolve_domain_to_ip() {
    local domain="$1"
    dig +short "$domain" | head -n 1
}

# === Check if Tor service is running ===
ensure_tor_running() {
    if ! systemctl is-active --quiet tor; then
        echo -e "${YELLOW}Tor service is not running. Starting Tor...${RESET}"
        sudo systemctl start tor
        sleep 10
        echo -e "${GREEN}Tor service started!${RESET}"
    fi
}

# === Check if Nipe is running ===
ensure_nipe_running() {
    if [ -d "nipe" ]; then
        cd nipe || exit
        if ! perl nipe.pl status | grep -q "Status: activated"; then
            echo -e "${YELLOW}Nipe is not running. Starting Nipe...${RESET}"
            sudo perl nipe.pl restart
            sleep 10
            echo -e "${GREEN}Nipe started!${RESET}"
        fi
        cd .. || exit
    fi
}

# === Get public IP without Tor ===
get_public_ip() {
    curl -s https://api64.ipify.org
}

# === Get public IP with Tor ===
get_tor_ip() {
    torify curl -s https://api64.ipify.org
}

# === Get country of an IP ===
get_ip_country() {
    local ip="$1"
    curl -s "https://ipinfo.io/$ip/country"
}

# === Check if anonymous ===
check_anonymity() {
    local real_ip
    real_ip=$(get_public_ip)
    local tor_ip
    tor_ip=$(get_tor_ip)

    if [ -z "$real_ip" ]; then
        echo -e "${RED}Error retrieving real IP.${RESET}"
        exit 1
    fi

    echo -e "${BLUE}Real IP:${RESET} $real_ip"
    echo -e "${BLUE}Tor IP:${RESET} $tor_ip"

    if torify curl -s https://check.torproject.org/api/ip | grep -q '"IsTor":true'; then
        local country
        country=$(get_ip_country "$tor_ip")
        echo -e "${GREEN}✅ Connected through Tor! Country: ${country:-Unknown}${RESET}"
    else
        echo -e "${RED}❌ NOT anonymous over Tor.${RESET}"
        ensure_tor_running
    fi
}

# === Function to save scan results locally with info summary ===
save_results() {
    local domain="$1"
    local temp_file="$2"

    mkdir -p "scans/$domain"
    INFO_FILE="scans/$domain/info_summary.txt"
    LOG_FILE="scans/$domain/scan_log.txt"

    # Extract important WHOIS fields
    registrar=$(grep -iE 'Registrar:' "$temp_file" | head -1 | awk -F: '{print $2}' | xargs)
    country=$(grep -iE 'Registrant Country|Country:' "$temp_file" | head -1 | awk -F: '{print $2}' | xargs)
    org=$(grep -iE 'Registrant Organization|Organization:' "$temp_file" | head -1 | awk -F: '{print $2}' | xargs)
    creation_date=$(grep -iE 'Creation Date:' "$temp_file" | head -1 | awk -F: '{print $2}' | xargs)
    expiry_date=$(grep -iE 'Expiry Date|Expiration Date:' "$temp_file" | head -1 | awk -F: '{print $2}' | xargs)

    # Extract open ports
    open_ports=$(grep -oP '\d+/tcp\s+open\s+\S+' "$temp_file" | sed 's/^/    /')

    # Save a clean report
    {
        echo "🔎 Domain: $domain"
        echo "🌐 IP Address: $(resolve_domain_to_ip "$domain")"
        echo
        echo "=== WHOIS Information ==="
        echo "Registrar: ${registrar:-Unknown}"
        echo "Registrant Country: ${country:-Unknown}"
        echo "Registrant Organization: ${org:-Unknown}"
        echo "Creation Date: ${creation_date:-Unknown}"
        echo "Expiry Date: ${expiry_date:-Unknown}"
        echo
        echo "=== Open Ports and Services (Nmap) ==="
        if [[ -z "$open_ports" ]]; then
            echo "No open ports found."
        else
            echo "$open_ports"
        fi
        echo
        echo "Scan Date: $(date)"
    } > "$INFO_FILE"

    echo "✅ Key findings saved to: $INFO_FILE"

    # Update log
    echo "[$(date)] Domain: $domain | Summary: $INFO_FILE" >> "$LOG_FILE"
}

# === Install required packages ===
packages=("nmap" "sshpass" "tor" "torify" "whois" "curl" "dig" "git" "perl")

for package in "${packages[@]}"; do
    if ! command -v "$package" &>/dev/null; then
        install_package "$package"
    else
        echo -e "${GREEN}$package is already installed.${RESET}"
    fi
done

# === Install Nipe if missing ===
if ! command -v nipe.pl &>/dev/null; then
    install_nipe
else
    echo -e "${GREEN}Nipe is already installed.${RESET}"
fi

# === Check anonymity ===
ensure_nipe_running
check_anonymity

# === Securely ask for SSH credentials ===
read -p "Enter remote server IP: " IP
read -p "Enter SSH username: " USER
read -sp "Enter SSH password: " PASSWORD
echo
echo

# === Main remote scanning function ===
RMT() {
    read -p "[*] Enter a Domain to scan: " DMN
    DOMAIN_IP=$(resolve_domain_to_ip "$DMN")

    echo -e "${YELLOW}Connecting to $IP...${RESET}"
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USER@$IP" << EOF
    {
        echo "WHOIS lookup"
        whois "$DMN"
        echo "Scanning open ports"
        nmap -Pn -p- --min-rate=5000 --open -T4 "$DMN"
    } > ~/remote_scan.txt
EOF

    echo -e "${YELLOW}Copying results back to local machine...${RESET}"
    sshpass -p "$PASSWORD" scp "$USER@$IP:~/remote_scan.txt" temp_scan_output.txt

    if [[ -f "temp_scan_output.txt" ]]; then
        save_results "$DMN" "temp_scan_output.txt"
        rm temp_scan_output.txt
    else
        echo -e "${RED}❌ Error: Scan output not found!${RESET}"
    fi
}

# === Execute main ===
RMT

echo -e "${GREEN}All done! Results are saved in the scans/ directory.${RESET}"
