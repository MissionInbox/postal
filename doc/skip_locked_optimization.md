# SKIP LOCKED Optimization for Queue Processing

## Date
January 13, 2026

## Problem
The queries that select emails to deliver for workers were creating lock contention where multiple threads wanted the same message. When multiple workers tried to grab messages from the `queued_messages` table simultaneously, they would wait for locks on the same rows, reducing throughput and efficiency.

## Solution
Implemented `SKIP LOCKED` in the queue processing queries to allow concurrent workers to select different messages without waiting for locks.

## Implementation

### Code Changes

Two key queries were optimized with `FOR UPDATE SKIP LOCKED`:

1. **`app/lib/worker/jobs/process_queued_messages_job.rb`** - `lock_message_for_processing` method
2. **`app/models/queued_message.rb`** - `batchable_messages` method

Both implementations use a **two-step approach**:
1. `SELECT ... FOR UPDATE SKIP LOCKED` - Find and lock available rows, skipping any already locked by other workers
2. `UPDATE` - Update the selected rows with lock information

This approach is compatible with MariaDB and avoids the "LIMIT & IN/ALL/ANY/SOME subquery" limitation.

### Generated SQL Queries

#### Query 1: Lock Message for Processing
```sql
-- Step 1: Select with SKIP LOCKED
SELECT `queued_messages`.*
FROM `queued_messages`
WHERE (`queued_messages`.`ip_address_id` IN (1, 2, 3, ...) OR `queued_messages`.`ip_address_id` IS NULL)
  AND `queued_messages`.`locked_by` IS NULL
  AND `queued_messages`.`locked_at` IS NULL
  AND (retry_after IS NULL OR retry_after < NOW())
ORDER BY `queued_messages`.`priority` DESC, `queued_messages`.`created_at` ASC
LIMIT 1
FOR UPDATE SKIP LOCKED;

-- Step 2: Update the selected row
UPDATE `queued_messages`
SET `locked_by` = 'host:hostname pid:X thread:Y uuid',
    `locked_at` = NOW()
WHERE `queued_messages`.`id` = ?;
```

#### Query 2: Batch Messages
```sql
-- Step 1: Select batch with SKIP LOCKED
SELECT `queued_messages`.*
FROM `queued_messages`
WHERE (retry_after IS NULL OR retry_after < NOW())
  AND `queued_messages`.`batch_key` = ?
  AND `queued_messages`.`ip_address_id` = ?
  AND `queued_messages`.`locked_by` IS NULL
  AND `queued_messages`.`locked_at` IS NULL
ORDER BY `queued_messages`.`priority` DESC, `queued_messages`.`created_at` ASC
LIMIT 10
FOR UPDATE SKIP LOCKED;

-- Step 2: Update each selected row
UPDATE `queued_messages`
SET `locked_by` = 'host:hostname pid:X thread:Y uuid',
    `locked_at` = NOW()
WHERE `queued_messages`.`id` = ?;
```

## How SKIP LOCKED Works

- **Without SKIP LOCKED**: When Worker A locks a row, Worker B waits for that lock to be released before it can proceed.
- **With SKIP LOCKED**: When Worker A locks a row, Worker B automatically skips that row and selects the next available unlocked row.

This eliminates lock contention and allows multiple workers to process different messages concurrently without blocking each other.

## Benefits

1. **Reduced Lock Contention**: Workers no longer wait for each other when selecting messages
2. **Improved Throughput**: Multiple workers can process messages in parallel without blocking
3. **Better Resource Utilization**: CPU and database connections are used more efficiently
4. **Scalability**: System can handle more concurrent workers without performance degradation

## MariaDB Compatibility

The implementation uses a two-step approach (SELECT + UPDATE) rather than UPDATE with a subquery because MariaDB has a limitation: "This version of MariaDB doesn't yet support 'LIMIT & IN/ALL/ANY/SOME subquery'".

The chosen approach:
- ✅ Compatible with MariaDB
- ✅ Provides the same lock contention benefits
- ✅ Atomic per-message locking
- ✅ No race conditions

## Testing

To manually test these queries against a MariaDB database:

1. Run the SELECT query with `FOR UPDATE SKIP LOCKED` in multiple sessions simultaneously
2. Verify that each session selects a different row
3. Confirm no sessions are waiting for locks
4. Verify the UPDATE queries succeed on the selected rows

Example test:
```sql
-- Session 1
SELECT id FROM queued_messages 
WHERE locked_by IS NULL 
ORDER BY priority DESC 
LIMIT 1 
FOR UPDATE SKIP LOCKED;

-- Session 2 (run immediately after Session 1, before commit)
SELECT id FROM queued_messages 
WHERE locked_by IS NULL 
ORDER BY priority DESC 
LIMIT 1 
FOR UPDATE SKIP LOCKED;
```

Both sessions should return different IDs without waiting.

