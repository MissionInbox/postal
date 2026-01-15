#!/bin/bash
# Postal Message Injection Script (Bash/cURL version)
# Supports both sequential and parallel (multi-threaded) injection

set -e

# Default values
COUNT=10000
FROM="test@apple.missioninbox.tech"
TO="lin@beta.obmengine.com"
SUBJECT_PREFIX="Test Message"
THREADS=1  # Default to sequential, use --threads for parallel

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --api-url URL       Postal API URL (required, or set POSTAL_API_URL)"
    echo "  --api-key KEY       API Key (required, or set POSTAL_API_KEY)"
    echo "  --from EMAIL        From address (default: test@apple.missioninbox.tech)"
    echo "  --to EMAIL          To address (default: lin@beta.obmengine.com)"
    echo "  --count N           Number of messages (default: 10000)"
    echo "  --threads N         Number of parallel threads (default: 1, use 50 for fast)"
    echo "  --subject PREFIX    Subject prefix (default: 'Test Message')"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Sequential (slow but simple)"
    echo "  $0 --api-url https://cobalt.obmengine.com --api-key YOUR_KEY --count 100"
    echo ""
    echo "  # Parallel with 50 threads (fast)"
    echo "  $0 --api-url https://cobalt.obmengine.com --api-key YOUR_KEY --count 10000 --threads 50"
    echo ""
    echo "  # With environment variables"
    echo "  export POSTAL_API_URL=https://cobalt.obmengine.com"
    echo "  export POSTAL_API_KEY=YOUR_KEY"
    echo "  $0 --count 1000 --threads 50"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --api-url)
            API_URL="$2"
            shift 2
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --from)
            FROM="$2"
            shift 2
            ;;
        --to)
            TO="$2"
            shift 2
            ;;
        --count)
            COUNT="$2"
            shift 2
            ;;
        --threads)
            THREADS="$2"
            shift 2
            ;;
        --subject)
            SUBJECT_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Use environment variables if not set
API_URL="${API_URL:-${POSTAL_API_URL}}"
API_KEY="${API_KEY:-${POSTAL_API_KEY}}"

# Validate required parameters
if [ -z "$API_URL" ] || [ -z "$API_KEY" ]; then
    echo "Error: --api-url and --api-key are required (or set POSTAL_API_URL and POSTAL_API_KEY)"
    echo ""
    usage
fi

echo "Injecting $COUNT messages with $THREADS thread(s)..."
echo "From: $FROM"
echo "To: $TO"
echo "API URL: $API_URL"
echo ""

SUCCESS=0
FAILED=0
START=$(date +%s)

# Function to send a single message
send_message() {
    local i=$1
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    RANDOM_NUM=$RANDOM

    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/api/v1/send/message" \
        -H "X-Server-API-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"to\":[\"$TO\"],\"from\":\"$FROM\",\"subject\":\"$SUBJECT_PREFIX #$i - $TIMESTAMP\",\"plain_body\":\"Test message $i with random: $RANDOM_NUM\"}" 2>/dev/null)

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

    if [ "$HTTP_CODE" = "200" ]; then
        echo "SUCCESS"
    else
        echo "FAILED:$HTTP_CODE"
    fi
}

if [ "$THREADS" -eq 1 ]; then
    # Sequential processing
    for i in $(seq 1 "$COUNT"); do
        RESULT=$(send_message $i)

        if [[ $RESULT == "SUCCESS" ]]; then
            ((SUCCESS++))
            if [ $((i % 100)) -eq 0 ]; then
                ELAPSED=$(($(date +%s) - START))
                RATE=$((SUCCESS / ELAPSED))
                echo "✓ Sent $i messages... ($RATE msg/s)"
            fi
        else
            ((FAILED++))
            echo "✗ Failed message $i: $RESULT"
        fi
    done
else
    # Parallel processing using background jobs
    FIFO="/tmp/injection_fifo_$$"
    mkfifo "$FIFO"
    exec 3<>"$FIFO"
    rm "$FIFO"

    # Fill FIFO with tokens (one per thread)
    for ((i=0; i<THREADS; i++)); do
        echo >&3
    done

    for ((i=1; i<=COUNT; i++)); do
        read -u 3  # Wait for available thread
        {
            RESULT=$(send_message $i)
            if [[ $RESULT == "SUCCESS" ]]; then
                ((SUCCESS++))
            else
                ((FAILED++))
            fi

            if [ $((i % 100)) -eq 0 ]; then
                ELAPSED=$(($(date +%s) - START))
                if [ $ELAPSED -gt 0 ]; then
                    RATE=$((SUCCESS / ELAPSED))
                    echo "✓ Progress: $i/$COUNT messages... (~$RATE msg/s)"
                fi
            fi

            echo >&3  # Return token
        } &
    done

    # Wait for all background jobs
    wait
    exec 3>&-
fi

END=$(date +%s)
ELAPSED=$((END - START))

if [ $ELAPSED -gt 0 ]; then
    RATE=$((SUCCESS / ELAPSED))
else
    RATE=0
fi

echo ""
echo "=================================================="
echo "Injection Complete"
echo "=================================================="
echo "Total messages: $COUNT"
echo "Successful: $SUCCESS"
echo "Failed: $FAILED"
echo "Time elapsed: ${ELAPSED}s"
echo "Rate: $RATE msg/s"
echo "=================================================="
