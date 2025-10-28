# Message API

The Message API allows you to retrieve information about messages, including their status, delivery details, and content.

## Authentication

All API requests require authentication using a Server API key. This should be provided in the `X-Server-API-Key` header.

## Content Types

The API supports two content types:

1. `application/json` - Parameters should be provided as JSON in the request body.
2. `application/x-www-form-urlencoded` - Parameters should be provided as URL-encoded form data with a `params` parameter containing a JSON string.

## Endpoints

### Get Message Details

**URL:** `/api/v1/messages/message`  
**Method:** POST  

Returns details about a specific message including status, content, and metadata.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| id | String | Yes | The internal ID of the message |
| _expansions | Array/Boolean | No | Types of details to include (status, details, inspection, plain_body, html_body, attachments, headers, raw_message, activity_entries) |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/messages/message \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "id": "12345",
    "_expansions": ["status", "details"]
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.045,
  "flags": {},
  "data": {
    "id": 12345,
    "token": "abc123def456",
    "status": {
      "status": "Sent",
      "last_delivery_attempt": 1642766400.0,
      "held": false,
      "hold_expiry": null
    },
    "details": {
      "rcpt_to": "recipient@example.com",
      "mail_from": "sender@yourdomain.com",
      "subject": "Test Message",
      "message_id": "59656a26-efc4-49fa-add5-47c2868405aa@rp.postal.mymissioninbox.com",
      "timestamp": 1642766400.0,
      "direction": "outgoing",
      "size": 1024,
      "bounce": false,
      "bounce_for_id": null,
      "tag": "newsletter",
      "received_with_ssl": true
    }
  }
}
```

### Get Message Deliveries

**URL:** `/api/v1/messages/deliveries`  
**Method:** POST  

Returns delivery information for a specific message.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| id | String | Yes | The internal ID of the message |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/messages/deliveries \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "id": "12345"
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.032,
  "flags": {},
  "data": [
    {
      "id": 67890,
      "status": "Sent",
      "details": "Message sent successfully",
      "output": "250 2.0.0 OK",
      "sent_with_ssl": true,
      "log_id": "log123",
      "time": 1642766400.0,
      "timestamp": 1642766400.0
    }
  ]
}
```

### Get Message Status

**URL:** `/api/v1/messages/status`  
**Method:** POST  

Returns the status of a message by its Message-ID header.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| messageId | String | Yes | The Message-ID header value of the message to look up |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/messages/status \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "messageId": "59656a26-efc4-49fa-add5-47c2868405aa@rp.postal.mymissioninbox.com"
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.028,
  "flags": {},
  "data": {
    "id": 12345,
    "token": "abc123def456",
    "message_id": "59656a26-efc4-49fa-add5-47c2868405aa@rp.postal.mymissioninbox.com",
    "status": "Sent",
    "last_delivery_attempt": 1642766400.0,
    "held": false,
    "hold_expiry": null,
    "timestamp": 1642766400.0,
    "rcpt_to": "recipient@example.com",
    "mail_from": "sender@yourdomain.com",
    "subject": "Test Message"
  }
}
```

#### Example Error Response

```json
{
  "status": "error",
  "time": 0.015,
  "flags": {},
  "data": {
    "code": "MessageNotFound",
    "message": "No message found matching provided message ID",
    "message_id": "nonexistent-message-id@example.com"
  }
}
```

### Get Bulk Message Status

**URL:** `/api/v1/messages/bulk_status`  
**Method:** POST  

Returns the status of multiple messages by their Message-ID headers. The response array will have the same length as the input array, with `null` values for messages that are not found.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| messageIds | Array | Yes | Array of Message-ID header values to look up |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/messages/bulk_status \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "messageIds": [
      "59656a26-efc4-49fa-add5-47c2868405aa@rp.postal.mymissioninbox.com",
      "12345678-abcd-efgh-ijkl-123456789012@rp.postal.mymissioninbox.com",
      "nonexistent-message-id@example.com"
    ]
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.085,
  "flags": {},
  "data": [
    {
      "id": 12345,
      "token": "abc123def456",
      "message_id": "59656a26-efc4-49fa-add5-47c2868405aa@rp.postal.mymissioninbox.com",
      "status": "Sent",
      "last_delivery_attempt": 1642766400.0,
      "held": false,
      "hold_expiry": null,
      "timestamp": 1642766400.0,
      "rcpt_to": "recipient@example.com",
      "mail_from": "sender@yourdomain.com",
      "subject": "Test Message"
    },
    {
      "id": 67890,
      "token": "def789ghi012",
      "message_id": "12345678-abcd-efgh-ijkl-123456789012@rp.postal.mymissioninbox.com",
      "status": "Bounced",
      "last_delivery_attempt": 1642766500.0,
      "held": false,
      "hold_expiry": null,
      "timestamp": 1642766450.0,
      "rcpt_to": "bounced@example.com",
      "mail_from": "sender@yourdomain.com",
      "subject": "Another Test Message"
    },
    null
  ]
}
```

#### Example Error Response

```json
{
  "status": "parameter-error",
  "time": 0.005,
  "flags": {},
  "data": {
    "message": "`messageIds` parameter is required and must be an array"
  }
}
```

### Get Suppressions List

**URL:** `/api/v1/suppressions/list`
**Method:** POST, GET, PUT, PATCH

Returns a paginated list of suppressed email addresses. Suppressed addresses are blocked from receiving messages through the server.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| page | Integer | No | The page number (default: 1) |
| per_page | Integer | No | Number of items per page (default: 30, max: 100) |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/suppressions/list \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "page": 1,
    "per_page": 30
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.042,
  "flags": {},
  "data": {
    "suppressions": [
      {
        "email": "bounced@example.com",
        "reason": "HardFail",
        "createdAt": "2025-10-15T14:30:00Z",
        "expireAt": "2025-11-14T14:30:00Z"
      },
      {
        "email": "complaint@example.com",
        "reason": "ManualSuppression",
        "createdAt": "2025-10-20T09:15:00Z",
        "expireAt": "2025-11-19T09:15:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "per_page": 30,
      "total": 150,
      "total_pages": 5
    }
  }
}
```

#### Suppression Fields

- **email** - The suppressed email address (string)
- **reason** - Reason for suppression (string)
- **createdAt** - When the suppression was created (ISO 8601 timestamp or null)
- **expireAt** - When the suppression will expire (ISO 8601 timestamp or null)

#### Common Suppression Reasons

- **HardFail** - Message bounced with a permanent failure
- **ManualSuppression** - Manually added to the suppression list
- **Complaint** - Recipient marked the message as spam

## Message Status Values

Messages can have the following status values:

- **Pending** - Message is queued for delivery
- **Held** - Message is being held (quarantined) and will not be delivered
- **Sent** - Message has been successfully delivered
- **Bounced** - Message delivery failed permanently
- **Deferred** - Message delivery is temporarily deferred
- **Processing** - Message is currently being processed

## Message Fields

### Basic Fields

- **id** - Internal database ID (integer)
- **token** - Unique token for the message (string)
- **message_id** - Email Message-ID header value (string)
- **status** - Current delivery status (string)
- **timestamp** - Message creation timestamp (float, Unix timestamp)

### Status Fields

- **last_delivery_attempt** - Last delivery attempt timestamp (float, Unix timestamp or null)
- **held** - Whether the message is currently held (boolean)
- **hold_expiry** - When the hold expires (float, Unix timestamp or null)

### Message Details

- **rcpt_to** - Recipient email address (string)
- **mail_from** - Sender email address (string)
- **subject** - Message subject line (string)
- **size** - Message size in bytes (integer)
- **bounce** - Whether this is a bounce message (boolean)
- **tag** - Message tag for categorization (string or null)

## Error Codes

Common error codes you may encounter:

- **MessageNotFound** - The requested message could not be found
- **ParameterError** - Required parameters are missing or invalid
- **AuthenticationError** - Invalid or missing API key
- **ServerError** - Internal server error

## Rate Limiting

API requests are subject to rate limiting. If you exceed the rate limit, you will receive a `429 Too Many Requests` response. Please implement appropriate retry logic with exponential backoff.

## Best Practices

1. **Use bulk operations** when possible to reduce API calls
2. **Cache results** appropriately to avoid unnecessary requests
3. **Handle errors gracefully** and implement retry logic
4. **Use appropriate expansions** to get only the data you need
5. **Monitor rate limits** and implement backoff strategies