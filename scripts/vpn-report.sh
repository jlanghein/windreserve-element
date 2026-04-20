#!/bin/bash
#
# VPN Report Generator
# 
# Generates an Excel spreadsheet report of all WireGuard VPN clients and users
# from the wg-portal management system.
#
# Usage:
#   ./scripts/vpn-report.sh [output-file]
#
# Examples:
#   ./scripts/vpn-report.sh                    # Creates vpn-report.xlsx
#   ./scripts/vpn-report.sh report-2026.xlsx   # Creates report-2026.xlsx
#   ./scripts/vpn-report.sh --json             # Also exports JSON data
#
# Requirements:
#   - uvx (uv package manager)
#   - sshpass
#   - SSH access to caddy.helium (10.24.0.29)
#   - Valid secrets.env with wg-portal credentials
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default output file
OUTPUT_FILE="vpn-report.xlsx"
EXTRA_ARGS=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            EXTRA_ARGS="$EXTRA_ARGS --json"
            shift
            ;;
        -h|--help)
            echo "Usage: ./scripts/vpn-report.sh [options] [output-file]"
            echo ""
            echo "Options:"
            echo "  --json      Also export data as JSON"
            echo "  -h, --help  Show this help message"
            echo ""
            echo "Arguments:"
            echo "  output-file  Output Excel file (default: vpn-report.xlsx)"
            echo ""
            echo "Examples:"
            echo "  ./scripts/vpn-report.sh"
            echo "  ./scripts/vpn-report.sh vpn-audit-2026.xlsx"
            echo "  ./scripts/vpn-report.sh --json report.xlsx"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            OUTPUT_FILE="$1"
            shift
            ;;
    esac
done

# Check for required tools
if ! command -v uvx &> /dev/null; then
    echo "Error: uvx not found. Please install uv first."
    echo "See: https://docs.astral.sh/uv/getting-started/installation/"
    exit 1
fi

if ! command -v sshpass &> /dev/null; then
    echo "Error: sshpass not found. Please install it:"
    echo "  sudo apt install sshpass    # Debian/Ubuntu"
    echo "  brew install sshpass        # macOS"
    exit 1
fi

# Check for secrets file
if [[ ! -f "$PROJECT_DIR/secrets.env" ]]; then
    echo "Error: secrets.env not found in project root"
    exit 1
fi

# Run the Python script with uvx
cd "$PROJECT_DIR"
uvx --quiet --with openpyxl python3 scripts/vpn-report.py --output "$OUTPUT_FILE" $EXTRA_ARGS

echo ""
echo "Report generated: $OUTPUT_FILE"
