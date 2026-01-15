# Postal Message Injection Scripts

Scripts for bulk injecting test messages into Postal via the API for load testing and queue verification.

## Overview

These scripts allow you to inject thousands of test messages into a Postal server's queue using the official `/api/v1/send/message` API endpoint. Messages are properly processed through Postal's pipeline, including validation, queueing, and statistics tracking.

## Files

- **inject_messages.rb** - Primary Ruby script with concurrent processing (recommended)
- **inject_messages.sh** - Simple Bash/cURL alternative for sequential processing
- **inject_messages.yml.example** - Configuration file template
- **README_INJECT.md** - This file

## Prerequisites

### Ruby Script
- Ruby 2.7+ (standard library only, no gems required)
- Network access to Postal server

### Bash Script
- Bash 4.0+
- `curl` command-line tool
- Network access to Postal server

## Getting API Key

You need a server API key from the Postal server you want to test against.

### Via Postal UI
1. Log into Postal web interface
2. Navigate to your server
3. Go to Settings → Credentials
4. View or create an API key

### Via Database (on server)
```bash
# Connect to Postal MariaDB container
docker exec postal-mariadb mysql -u postal -ppostal postal -e \
  "SELECT key FROM credentials WHERE server_id = 18 LIMIT 1"
```

## Usage

### Ruby Script (Recommended)

**Basic usage with command-line arguments:**
```bash
./script/inject_messages.rb \
  --api-url https://cobalt.obmengine.com \
  --api-key YOUR_API_KEY \
  --from test@apple.missioninbox.tech \
  --to lin@beta.obmengine.com \
  --count 10000
```

**Using environment variables:**
```bash
export POSTAL_API_URL=https://cobalt.obmengine.com
export POSTAL_API_KEY=YOUR_API_KEY

./script/inject_messages.rb --count 10000
```

**With custom concurrency and rate limiting:**
```bash
./script/inject_messages.rb \
  --api-url https://cobalt.obmengine.com \
  --api-key YOUR_KEY \
  --count 10000 \
  --concurrency 20 \
  --rate-limit 200 \
  --tag stress-test
```

**All options:**
```bash
./script/inject_messages.rb \
  --api-url URL              # Postal API URL (required)
  --api-key KEY              # Server API key (required)
  --count N                  # Number of messages (default: 10000)
  --from EMAIL               # From address (default: test@apple.missioninbox.tech)
  --to EMAIL                 # To address (default: lin@beta.obmengine.com)
  --subject PREFIX           # Subject prefix (default: "Test Message")
  --body TEMPLATE            # Custom body template
  --no-randomize             # Disable body text randomization
  --concurrency N            # Parallel threads (default: 10)
  --rate-limit N             # Max requests/sec (default: 100)
  --priority N               # Message priority (optional)
  --tag TAG                  # Custom tag (optional)
  --help                     # Show help
```

### Bash Script

**Sequential (slow but simple):**
```bash
./script/inject_messages.sh \
  --api-url https://cobalt.obmengine.com \
  --api-key YOUR_API_KEY \
  --count 1000
```

**Parallel with 50 threads (FAST - recommended for 10k+):**
```bash
./script/inject_messages.sh \
  --api-url https://cobalt.obmengine.com \
  --api-key YOUR_API_KEY \
  --count 10000 \
  --threads 50
```

**With environment variables:**
```bash
export POSTAL_API_URL=https://cobalt.obmengine.com
export POSTAL_API_KEY=YOUR_KEY
./script/inject_messages.sh --count 10000 --threads 50
```

## Performance

### Expected Throughput (Tested on obm-cobalt)

- **Bash (sequential)**: ~2-5 messages/second
- **Bash (50 threads)**: ~400-500 messages/second ⚡
- **Ruby (10 threads)**: ~100-500 messages/second (requires Ruby)
- **Ruby (50 threads)**: ~500-2000 messages/second (requires Ruby)

### Time Estimates for 10,000 Messages

- **Bash (sequential)**: 30-80 minutes ⏳
- **Bash (50 threads)**: ~20-30 seconds ⚡ **RECOMMENDED**
- **Ruby (10 threads)**: 20-100 seconds
- **Ruby (50 threads)**: 5-20 seconds

### Real-World Test Results (obm-cobalt, Jan 2026)

Successfully injected **10,041 messages** in approximately 20 seconds using:
```bash
./script/inject_messages.sh --threads 50 --count 10000
```

**Performance**: ~500 msg/s with 50 parallel threads

## Testing Workflow

### 1. Start Small
Always start with a small test to verify configuration:
```bash
./script/inject_messages.rb \
  --api-url https://cobalt.obmengine.com \
  --api-key YOUR_KEY \
  --count 10
```

### 2. Stop Workers (Optional)
If you want messages to queue without being delivered:
```bash
# On the Postal server
cd /opt/postal && postal stop worker
```

### 3. Run Injection
```bash
./script/inject_messages.rb \
  --api-url https://cobalt.obmengine.com \
  --api-key YOUR_KEY \
  --count 10000
```

### 4. Verify Queue
```bash
# On the Postal server
docker exec postal-mariadb mysql -u postal -ppostal postal -e \
  "SELECT COUNT(*) as queued FROM queued_messages WHERE server_id = 18"
```

### 5. Start Workers (If Stopped)
```bash
cd /opt/postal && postal start worker
```

## Verification

After injection, verify messages were created correctly:

```bash
# Count queued messages
docker exec postal-mariadb mysql -u postal -ppostal postal <<EOF
SELECT COUNT(*) as queued_count
FROM queued_messages
WHERE server_id = 18
  AND created_at > NOW() - INTERVAL 1 HOUR;
EOF

# Check message status distribution
docker exec postal-mariadb mysql -u postal -ppostal postal <<EOF
SELECT m.status, COUNT(*) as count
FROM queued_messages qm
JOIN \`postal-server-18\`.messages m ON qm.message_id = m.id
WHERE qm.server_id = 18
  AND qm.created_at > NOW() - INTERVAL 1 HOUR
GROUP BY m.status;
EOF

# Check batch_key distribution (should be consistent)
docker exec postal-mariadb mysql -u postal -ppostal postal <<EOF
SELECT batch_key, COUNT(*) as count
FROM queued_messages
WHERE server_id = 18
  AND created_at > NOW() - INTERVAL 1 HOUR
GROUP BY batch_key;
EOF

# Check total message size
docker exec postal-mariadb mysql -u postal -ppostal 'postal-server-18' -e \
  "SELECT COUNT(*) as total,
          SUM(size) as total_bytes,
          AVG(size) as avg_bytes
   FROM messages
   WHERE scope = 'outgoing'
   AND timestamp > UNIX_TIMESTAMP(NOW() - INTERVAL 1 HOUR)"
```

## Security

### API Key Management

1. **Never commit API keys** to version control
2. **Use environment variables** or secure config files
3. **Rotate keys** after testing if exposed
4. **Limit key permissions** if possible

### Git Ignore

Add to `.gitignore`:
```
script/inject_messages.yml
script/inject_messages_*.log
```

### File Permissions

Restrict access to config files containing keys:
```bash
chmod 600 script/inject_messages.yml
```

## Troubleshooting

### Authentication Errors (401)
- Verify API key is correct
- Check key belongs to the correct server
- Ensure key is active (not expired/revoked)

### Validation Errors (422)
- Verify from address is authenticated domain on server
- Check domain exists and is verified
- Ensure to address is valid email format

### Rate Limiting (429)
- Reduce `--concurrency` value
- Reduce `--rate-limit` value
- Add delays between batches

### Network Errors
- Check network connectivity to Postal server
- Verify HTTPS certificate is valid
- Check firewall rules

### Slow Performance
- Increase `--concurrency` (Ruby only)
- Increase `--rate-limit`
- Check server load and database performance
- Verify network latency

## Advanced Usage

### Variable Message Content

Create messages with different subjects and bodies:
```bash
for i in {1..1000}; do
  ./script/inject_messages.rb \
    --api-url https://cobalt.obmengine.com \
    --api-key YOUR_KEY \
    --count 10 \
    --subject "Campaign $i" \
    --tag "campaign-$i"
done
```

### Multiple Recipients

Inject to multiple recipients:
```bash
for recipient in alice@example.com bob@example.com charlie@example.com; do
  ./script/inject_messages.rb \
    --api-url https://cobalt.obmengine.com \
    --api-key YOUR_KEY \
    --to "$recipient" \
    --count 1000 \
    --tag "recipient-$(echo $recipient | cut -d@ -f1)"
done
```

### Priority Distribution

Inject with different priorities:
```bash
# High priority batch
./script/inject_messages.rb \
  --api-url https://cobalt.obmengine.com \
  --api-key YOUR_KEY \
  --count 1000 \
  --priority 10 \
  --tag high-priority

# Normal priority batch
./script/inject_messages.rb \
  --api-url https://cobalt.obmengine.com \
  --api-key YOUR_KEY \
  --count 5000 \
  --priority 0 \
  --tag normal-priority
```

## Cleanup

To remove test messages after testing:

```bash
# Delete queued messages for server 18 with specific tag
docker exec postal-mariadb mysql -u postal -ppostal postal <<EOF
DELETE qm FROM queued_messages qm
JOIN \`postal-server-18\`.messages m ON qm.message_id = m.id
WHERE qm.server_id = 18
  AND m.tag = 'load-test';
EOF

# Delete messages from message database
docker exec postal-mariadb mysql -u postal -ppostal 'postal-server-18' <<EOF
DELETE FROM messages
WHERE tag = 'load-test';
EOF
```

**Note:** Be very careful with DELETE operations in production!

## Examples

### Load Test Scenario
```bash
# Inject 10k messages with moderate concurrency
./script/inject_messages.rb \
  --api-url https://cobalt.obmengine.com \
  --api-key YOUR_KEY \
  --count 10000 \
  --concurrency 20 \
  --rate-limit 200 \
  --tag load-test-$(date +%Y%m%d)
```

### Slow Gradual Injection
```bash
# Inject slowly over time (10 msg/s)
./script/inject_messages.rb \
  --api-url https://cobalt.obmengine.com \
  --api-key YOUR_KEY \
  --count 1000 \
  --concurrency 2 \
  --rate-limit 10 \
  --tag gradual-injection
```

### Maximum Throughput Test
```bash
# Push as fast as possible
./script/inject_messages.rb \
  --api-url https://cobalt.obmengine.com \
  --api-key YOUR_KEY \
  --count 10000 \
  --concurrency 50 \
  --rate-limit 0 \
  --tag stress-test
```

## Support

For issues or questions:
1. Check Postal logs: `docker logs postal-web-server`
2. Check database connectivity and status
3. Verify API endpoint is accessible
4. Review error messages from script output

## License

Same as Postal (MIT License)
