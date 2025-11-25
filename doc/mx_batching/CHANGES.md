# MX-Based Message Batching Implementation

## Overview

This document describes the implementation of MX-based batch key generation for outgoing messages in Postal. This enhancement allows messages destined for different domains that share the same mail servers to be batched together, improving delivery efficiency.

## Problem Statement

Previously, messages were batched by recipient domain:
- `outgoing-gmail.com`
- `outgoing-googlemail.com`
- `outgoing-yahoo.com`

This meant that messages to `gmail.com` and `googlemail.com` (which use the same MX servers) would be processed separately, missing opportunities for connection reuse.

## Solution

The new implementation resolves MX records for each recipient domain and creates a hash of the sorted MX hostnames. Messages to domains with identical MX records receive the same batch key, enabling batching across domain boundaries.

## Implementation Details

### 1. MX Hash Generation (`lib/postal/message_db/message.rb`)

**New Method: `Postal::MessageDB::Message.mx_hash_for_domain(domain)`**

```ruby
def self.mx_hash_for_domain(domain)
  # 1. Check cache (5-minute TTL)
  # 2. Resolve MX records via DNSResolver.local.mx(domain)
  # 3. Sort MX hostnames for consistency
  # 4. Generate SHA256 hash (first 16 chars)
  # 5. Cache and return
end
```

**Key Features:**
- Returns `nil` on errors or missing MX records (falls back to domain-based batching)
- Thread-safe caching with 5-minute TTL
- Automatic cache cleanup every 100 accesses
- Ignores MX priority for batching purposes (only hostname matters)

### 2. Updated Batch Key Logic

**Modified Method: `Postal::MessageDB::Message#batch_key`**

```ruby
def batch_key
  case scope
  when "outgoing"
    key = "outgoing-"
    mx_hash = self.class.mx_hash_for_domain(recipient_domain)
    key += mx_hash || recipient_domain.to_s  # Fallback to domain
  when "incoming"
    # Unchanged: uses route and endpoint
    key = "incoming-rt:#{route_id}-ep:#{endpoint_id}-#{endpoint_type}"
  else
    key = nil
  end
  key
end
```

## Benefits

### 1. **Improved Batching Efficiency**
- Messages to `gmail.com`, `googlemail.com`, and any Google Workspace domains share the same MX servers
- All will receive the same batch_key and be processed together
- Reuses SMTP connections, DNS lookups, and other resources

### 2. **Graceful Degradation**
- DNS resolution failures → falls back to domain-based batching
- No MX records → falls back to domain-based batching
- Maintains backward compatibility

### 3. **Performance Optimization**
- 5-minute cache prevents excessive DNS lookups
- Cache cleanup prevents memory bloat
- Thread-safe implementation for multi-worker deployments

## Examples

### Example 1: Google Mail Services

```ruby
# All resolve to the same Google MX servers
domains = ["gmail.com", "googlemail.com", "google.com"]

# All receive the same hash (e.g., "a1b2c3d4e5f6g7h8")
batch_keys = domains.map { |d|
  hash = Postal::MessageDB::Message.mx_hash_for_domain(d)
  "outgoing-#{hash}"
}

# Result: All messages batch together
# batch_keys => ["outgoing-a1b2c3d4e5f6g7h8", "outgoing-a1b2c3d4e5f6g7h8", "outgoing-a1b2c3d4e5f6g7h8"]
```

### Example 2: Different Providers

```ruby
domains = ["gmail.com", "yahoo.com", "outlook.com"]

# Each has different MX servers, gets different hash
# "outgoing-a1b2c3d4e5f6g7h8" (Gmail)
# "outgoing-x9y8z7w6v5u4t3s2" (Yahoo)
# "outgoing-m5n6o7p8q9r0s1t2" (Outlook)
```

### Example 3: Custom Domains with Google Workspace

```ruby
domains = ["company1.com", "company2.com", "gmail.com"]

# If company1.com and company2.com use Google Workspace:
# MX records: [aspmx.l.google.com, alt1.aspmx.l.google.com, ...]
# All three domains will batch together!
```

## Testing

### Unit Tests
**File:** `spec/lib/postal/message_db/message_mx_batching_spec.rb`

Tests cover:
- ✅ Hash generation for domains with MX records
- ✅ Consistent hashing for same MX records
- ✅ Different hashes for different MX records
- ✅ Priority ignored (only hostname matters)
- ✅ Fallback to domain when no MX records
- ✅ Error handling (DNS failures)
- ✅ Caching behavior and TTL
- ✅ Incoming messages unchanged
- ✅ Integration with batch_key method

### Manual Testing
**File:** `test_mx_batching.rb`

Interactive script that:
1. Resolves MX records for common domains
2. Shows which domains will batch together
3. Demonstrates cache performance
4. Simulates batch_key generation

## Configuration

No configuration required. The feature is enabled by default and:
- Uses existing `DNSResolver` infrastructure
- Respects `Postal::Config.dns.timeout` settings
- Works with `Postal::Config.postal.batch_queued_messages` flag

## Migration Notes

### Backward Compatibility
- ✅ Existing batch_key behavior preserved for incoming messages
- ✅ Graceful fallback ensures no breaking changes
- ✅ Cache is transient (no database changes required)

### Performance Impact
- Minimal: DNS lookups cached for 5 minutes
- Positive: Better batching = fewer SMTP connections
- Memory: Negligible (cache auto-cleans)

## Monitoring

The existing batching metrics will show improved efficiency:
- `postal_message_queue_latency` - Should remain similar or improve
- Connection reuse in `SMTPSender` - Should increase
- Batch sizes in logs - Should show larger batches

Look for log entries like:
```
found 15 associated messages to process at the same time batch_key=outgoing-a1b2c3d4e5f6g7h8
```

## Files Modified

1. **`lib/postal/message_db/message.rb`**
   - Added `self.mx_hash_for_domain(domain)` class method
   - Added `self.mx_cache` class method for thread-safe caching
   - Modified `batch_key` instance method to use MX hashing

2. **`spec/lib/postal/message_db/message_mx_batching_spec.rb`** (NEW)
   - Comprehensive RSpec tests for MX batching functionality

3. **`test_mx_batching.rb`** (NEW)
   - Manual testing script for verification

## Future Enhancements

Potential improvements:
1. Make cache TTL configurable via `Postal::Config`
2. Add Prometheus metrics for cache hit/miss rates
3. Consider Redis-based cache for multi-server deployments
4. Add admin UI to view current MX hash mappings
5. Implement A/B testing to measure delivery time improvements

## Rollback

If issues arise, revert changes to `lib/postal/message_db/message.rb`:
- Restore original `batch_key` method
- Remove `mx_hash_for_domain` and `mx_cache` methods

The fallback behavior ensures partial failures won't break message delivery.
