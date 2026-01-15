#!/bin/bash
# Automated message injection for obm-cobalt staging server
# This script uses Ansible to retrieve configuration and runs the injection

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
SERVER_NAME="obm-cobalt"
SERVER_ID=18
INVENTORY_FILE="${MI_ANSIBLE_DIR:-../mi-ansible}/inventories/staging/hosts.yml"
FROM_ADDRESS="test@apple.missioninbox.tech"
TO_ADDRESS="lin@beta.obmengine.com"
COUNT="${1:-10000}"

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}Postal Message Injection - obm-cobalt${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# Check if Ansible inventory exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo -e "${RED}Error: Ansible inventory not found at $INVENTORY_FILE${NC}"
    echo "Please set MI_ANSIBLE_DIR environment variable or ensure ../mi-ansible exists"
    exit 1
fi

echo -e "${YELLOW}Step 1: Retrieving configuration from $SERVER_NAME...${NC}"

# Get server hostname (API URL)
API_HOST=$(ansible -i "$INVENTORY_FILE" "$SERVER_NAME" -m debug -a "var=server_domain" 2>/dev/null | grep -oP '"server_domain": "\K[^"]+' || echo "")

if [ -z "$API_HOST" ]; then
    echo -e "${RED}Error: Could not retrieve server domain from Ansible inventory${NC}"
    exit 1
fi

API_URL="https://$API_HOST"
echo -e "${GREEN}✓ API URL: $API_URL${NC}"

# Get API key from database
echo ""
echo -e "${YELLOW}Step 2: Retrieving API key from database...${NC}"

API_KEY=$(ansible -i "$INVENTORY_FILE" "$SERVER_NAME" -m shell \
    -a "docker exec postal-mariadb mysql -u postal -ppostal postal -sN -e \"SELECT key FROM credentials WHERE server_id = $SERVER_ID LIMIT 1\"" \
    2>/dev/null | tail -n1 || echo "")

if [ -z "$API_KEY" ] || [ "$API_KEY" = "CHANGED" ] || [ "$API_KEY" = "FAILED" ]; then
    echo -e "${RED}Error: Could not retrieve API key from database${NC}"
    echo "Manual command to get API key:"
    echo "  ansible -i $INVENTORY_FILE $SERVER_NAME -m shell -a \"docker exec postal-mariadb mysql -u postal -ppostal postal -e 'SELECT key FROM credentials WHERE server_id = $SERVER_ID LIMIT 1'\""
    exit 1
fi

echo -e "${GREEN}✓ API Key: ${API_KEY:0:20}...${NC}"

# Verify from domain exists
echo ""
echo -e "${YELLOW}Step 3: Verifying from domain...${NC}"

DOMAIN_CHECK=$(ansible -i "$INVENTORY_FILE" "$SERVER_NAME" -m shell \
    -a "docker exec postal-mariadb mysql -u postal -ppostal postal -sN -e \"SELECT COUNT(*) FROM domains WHERE server_id = $SERVER_ID AND name = '${FROM_ADDRESS##*@}'\"" \
    2>/dev/null | tail -n1 || echo "0")

if [ "$DOMAIN_CHECK" = "0" ]; then
    echo -e "${RED}Error: Domain ${FROM_ADDRESS##*@} not found for server $SERVER_ID${NC}"
    echo "Please verify the from address domain is configured in Postal"
    exit 1
fi

echo -e "${GREEN}✓ From domain verified: ${FROM_ADDRESS##*@}${NC}"

# Check if worker is running
echo ""
echo -e "${YELLOW}Step 4: Checking worker status...${NC}"

WORKER_STATUS=$(ansible -i "$INVENTORY_FILE" "$SERVER_NAME" -m shell \
    -a "docker ps --filter name=postal-worker --format '{{.Status}}'" \
    2>/dev/null | grep -c "Up" || echo "0")

if [ "$WORKER_STATUS" -gt "0" ]; then
    echo -e "${YELLOW}⚠ Warning: Workers are running - messages will be delivered!${NC}"
    read -p "Do you want to stop workers before injection? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping workers..."
        ansible -i "$INVENTORY_FILE" "$SERVER_NAME" -m shell \
            -a "cd /opt/postal && postal stop worker" 2>/dev/null
        echo -e "${GREEN}✓ Workers stopped${NC}"
    fi
else
    echo -e "${GREEN}✓ Workers are stopped - messages will queue${NC}"
fi

# Display injection plan
echo ""
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}Injection Plan${NC}"
echo -e "${BLUE}==================================================${NC}"
echo "Server: $SERVER_NAME ($API_HOST)"
echo "From: $FROM_ADDRESS"
echo "To: $TO_ADDRESS"
echo "Count: $COUNT messages"
echo "Script: Ruby (concurrent)"
echo ""

read -p "Proceed with injection? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Run injection
echo ""
echo -e "${YELLOW}Step 5: Running injection...${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/inject_messages.rb" \
    --api-url "$API_URL" \
    --api-key "$API_KEY" \
    --from "$FROM_ADDRESS" \
    --to "$TO_ADDRESS" \
    --count "$COUNT" \
    --concurrency 10 \
    --rate-limit 100 \
    --tag "load-test-$(date +%Y%m%d-%H%M%S)"

# Verify injection
echo ""
echo -e "${YELLOW}Step 6: Verifying injection...${NC}"

QUEUED_COUNT=$(ansible -i "$INVENTORY_FILE" "$SERVER_NAME" -m shell \
    -a "docker exec postal-mariadb mysql -u postal -ppostal postal -sN -e \"SELECT COUNT(*) FROM queued_messages WHERE server_id = $SERVER_ID AND created_at > NOW() - INTERVAL 5 MINUTE\"" \
    2>/dev/null | tail -n1 || echo "0")

echo -e "${GREEN}✓ Queued messages: $QUEUED_COUNT${NC}"

MESSAGE_COUNT=$(ansible -i "$INVENTORY_FILE" "$SERVER_NAME" -m shell \
    -a "docker exec postal-mariadb mysql -u postal -ppostal 'postal-server-$SERVER_ID' -sN -e \"SELECT COUNT(*) FROM messages WHERE scope = 'outgoing' AND timestamp > UNIX_TIMESTAMP(NOW() - INTERVAL 5 MINUTE)\"" \
    2>/dev/null | tail -n1 || echo "0")

echo -e "${GREEN}✓ Messages created: $MESSAGE_COUNT${NC}"

# Optional: Start workers
echo ""
if [ "$WORKER_STATUS" = "0" ]; then
    read -p "Start workers to process messages? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ansible -i "$INVENTORY_FILE" "$SERVER_NAME" -m shell \
            -a "cd /opt/postal && postal start worker" 2>/dev/null
        echo -e "${GREEN}✓ Workers started${NC}"
    fi
fi

echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}Injection Complete!${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo "To monitor queue processing:"
echo "  ansible -i $INVENTORY_FILE $SERVER_NAME -m shell -a \"docker exec postal-mariadb mysql -u postal -ppostal postal -e 'SELECT COUNT(*) FROM queued_messages WHERE server_id = $SERVER_ID'\""
echo ""
echo "To check worker logs:"
echo "  ansible -i $INVENTORY_FILE $SERVER_NAME -m shell -a \"docker logs postal-worker-1 --tail 50\""
