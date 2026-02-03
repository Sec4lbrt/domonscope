#!/bin/bash

# ====== CONFIG ======
OUTPUT_FILE="matched_domains.txt"
VERBOSE=0
INPUT_FILE=""
BLOCKLIST_FILE=""

# ====== HELP MESSAGE ======
show_help() {
    cat << EOF
Usage: $0 --domains <file> --ips <file> [options]

Required:
  -d, --domains <file>    Input file containing domain names (one per line)
  -i, --ips <file>        Input file containing blocklisted IP addresses

Optional:
  -o, --output <file>     Output file for matched domains (default: matched_domains.txt)
  -v, --verbose           Enable verbose output
  -h, --help              Show this help message

Example:
  $0 -d domains.txt -i blocklist.txt -o results.txt -v
EOF
    exit 0
}

# ====== LOG FUNCTION ======
log() {
    [[ $VERBOSE -eq 1 ]] && echo -e "$1"
}

# ====== ARGUMENT PARSER ======
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--domains)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "ERROR: No domains file specified after -d / --domains."
                echo ""
                echo "Correct usage: -d <file>"
                exit 1
            fi
            INPUT_FILE="$2"
            shift 2
            ;;
        -i|--ips)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "ERROR: No IP blocklist file specified after -i / --ips."
                echo ""
                echo "Correct usage: -i <file>"
                exit 1
            fi
            BLOCKLIST_FILE="$2"
            shift 2
            ;;
        -o|--output)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "ERROR: No output file specified after -o / --output."
                echo ""
                echo "Correct usage: -o <file>"
                exit 1
            fi
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo ""
            show_help
            ;;
    esac
done

# ====== CHECK REQUIRED FLAGS ======
if [[ -z "$INPUT_FILE" || -z "$BLOCKLIST_FILE" ]]; then
    echo "ERROR: You must provide BOTH --domains and --ips files."
    echo ""
    echo "Correct usage:"
    echo "  $0 -d domains.txt -i blocklist.txt"
    echo ""
    echo "See --help for more info."
    exit 1
fi

# ====== SCRIPT START ======

# Reset output file
> "$OUTPUT_FILE"

# Validate files
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "ERROR: Domain file '$INPUT_FILE' not found."
    exit 1
fi

if [[ ! -f "$BLOCKLIST_FILE" ]]; then
    echo "ERROR: IP blocklist file '$BLOCKLIST_FILE' not found."
    exit 1
fi

log "[*] Verbose mode ON"
log "[*] Using domain file: $INPUT_FILE"
log "[*] Using blocklist file: $BLOCKLIST_FILE"
log "[*] Output file: $OUTPUT_FILE"

# Load blocklist into associative array
declare -A BL
while read -r ip; do
    [[ -z "$ip" ]] && continue
    BL["$ip"]=1
done < "$BLOCKLIST_FILE"

log "[*] Loaded $(printf "%s\n" "${!BL[@]}" | wc -l) blocklisted IPs."
log "[*] Starting domain analysis..."

MATCH_COUNT=0

while read -r domain; do
    [[ -z "$domain" ]] && continue

    log "\n[*] Checking $domain ..."

    IPS=$(nslookup "$domain" 2>/dev/null | awk '/Address: / {print $2}')

    if [[ -z "$IPS" ]]; then
        log "    No DNS result."
        continue
    fi

    log "    Resolved IPs: $(echo "$IPS" | tr '\n' ' ')"

    MATCHED=0
    while read -r ip; do
        if [[ ${BL["$ip"]+exists} ]]; then
            MATCHED=1
            break
        fi
    done <<< "$IPS"

    if [[ $MATCHED -eq 1 ]]; then
        log "    MATCH FOUND → $domain"
        echo "$domain" >> "$OUTPUT_FILE"
        ((MATCH_COUNT++))
    else
        log "    No match."
    fi

done < "$INPUT_FILE"

# ====== FINAL OUTPUT ======
echo "=== MATCHING DOMAINS (${MATCH_COUNT} found) ==="
cat "$OUTPUT_FILE"
echo "==============================================="
echo "Results saved to: $OUTPUT_FILE"

