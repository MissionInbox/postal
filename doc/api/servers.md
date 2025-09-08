# Servers API

The Servers API allows you to programmatically retrieve information about and manage your Postal servers.

## Authentication

All API requests require authentication using a Server API key. This should be provided in the `X-Server-API-Key` header.

## Content Types

The API supports two content types:

1. `application/json` - Parameters should be provided as JSON in the request body.
2. `application/x-www-form-urlencoded` - Parameters should be provided as URL-encoded form data with a `params` parameter containing a JSON string.

## Endpoints

### Create Server

**URL:** `/api/v1/servers/create`  
**Method:** POST  

Creates a new server in the specified organization. The server will be created with default API and SMTP credentials.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| organization_uuid | String | Yes | The UUID of the organization to create the server in |
| name | String | Yes | The name of the new server |
| mode | String | No | Server mode, either "Live" or "Development" (defaults to "Live") |
| ip_pool_id | Integer | No | The ID of the IP pool to assign to this server |
| auto_assign_ip_pool | Boolean | No | Automatically assigns an IP pool to the server when no `ip_pool_id` is provided using a round-robin approach among the least used pools (defaults to `true`, set to `false` to disable) |
| top_pools_limit | Integer | No | When auto-assigning, specifies how many of the least used pools to consider for round-robin selection (defaults to 5) |
| privacy_mode | Boolean | No | Whether to enable privacy mode for this server (defaults to `false`) |
| skip_provision_database | Boolean | No | If set to `true`, skips provisioning a message database (advanced usage only) |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/servers/create \
  -H 'Content-Type: application/json' \
  -d '{
    "organization_uuid": "org-uuid-123",
    "name": "New Transactional Server",
    "mode": "Live"
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 1.255,
  "flags": {},
  "data": {
    "server": {
      "uuid": "server-uuid-123",
      "name": "New Transactional Server",
      "permalink": "new-transactional-server",
      "mode": "Live",
      "created_at": "2025-05-13T14:30:00.000Z",
      "organization": {
        "uuid": "org-uuid-123",
        "name": "ACME Inc",
        "permalink": "acme"
      },
      "api_key": "abcdef123456789",
      "smtp_key": "zyxwvutsrq987654321",
      "smtp_user": "acme/new-transactional-server",
      "already_exists": false,
      "ip_pool": {
        "id": 1,
        "uuid": "ip-pool-uuid-123",
        "name": "Main Pool",
        "auto_assigned": true
      }
    }
  }
}
```

If a server with the same name already exists in the organization, the API will return the existing server's details with a flag indicating `"already_exists": true`. If the existing server lacks default API or SMTP credentials, they will be automatically created.

#### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| uuid | String | The server's unique identifier |
| name | String | The server's name |
| permalink | String | The server's URL-friendly permalink |
| mode | String | Server mode ("Live" or "Development") |
| created_at | String | Server creation timestamp |
| organization | Object | Organization details (uuid, name, permalink) |
| api_key | String | The default API credential key for this server |
| smtp_key | String | The default SMTP credential key for this server |
| smtp_user | String | The SMTP username in format `organization_permalink/server_permalink` |
| already_exists | Boolean | Whether the server already existed |
| ip_pool | Object | IP pool information (if assigned) |

### List Servers

**URL:** `/api/v1/servers/list`  
**Method:** POST  

Returns a list of all servers in the organization that the authenticated server belongs to.

#### Parameters

None required.

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/servers/list \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{}'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.055,
  "flags": {},
  "data": {
    "servers": [
      {
        "uuid": "server-uuid-1",
        "name": "Marketing Server",
        "permalink": "marketing-server",
        "mode": "Live",
        "suspended": false,
        "privacy_mode": false,
        "ip_pool_id": "ip-pool-id",
        "created_at": "2023-01-01T12:00:00.000Z",
        "updated_at": "2023-01-01T12:00:00.000Z",
        "domains_count": 3,
        "credentials_count": 2,
        "webhooks_count": 1,
        "routes_count": 5
      },
      {
        "uuid": "server-uuid-2",
        "name": "Transactional Server",
        "permalink": "transactional-server",
        "mode": "Live",
        "suspended": false,
        "privacy_mode": false,
        "ip_pool_id": "ip-pool-id",
        "created_at": "2023-01-01T12:00:00.000Z",
        "updated_at": "2023-01-01T12:00:00.000Z",
        "domains_count": 5,
        "credentials_count": 3,
        "webhooks_count": 2,
        "routes_count": 8
      }
    ]
  }
}
```

### Show Server

**URL:** `/api/v1/servers/show`  
**Method:** POST  

Returns detailed information about a specific server.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| server_id | String | No | The UUID of the server to retrieve. If not provided, the server associated with the API key will be used. |
| include_domains | Boolean | No | Set to `true` to include domains associated with the server |
| include_stats | Boolean | No | Set to `false` to exclude basic stats from the response (defaults to `true` for backward compatibility) |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/servers/show \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "include_domains": true,
    "include_stats": true
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.055,
  "flags": {},
  "data": {
    "server": {
      "uuid": "server-uuid",
      "name": "Transactional Server",
      "permalink": "transactional-server",
      "mode": "Live",
      "suspended": false,
      "suspension_reason": null,
      "privacy_mode": false,
      "ip_pool_id": "ip-pool-id",
      "created_at": "2023-01-01T12:00:00.000Z",
      "updated_at": "2023-01-01T12:00:00.000Z",
      "domains_count": 3,
      "credentials_count": 2,
      "webhooks_count": 1,
      "routes_count": 5,
      "organization": {
        "uuid": "org-uuid",
        "name": "ACME Inc",
        "permalink": "acme"
      },
      "stats": {
        "messages_sent_today": 1524,
        "messages_sent_this_month": 45789
      },
      "domains": [
        {
          "uuid": "domain-uuid-1",
          "name": "example.com",
          "verified": true,
          "spf_status": "OK",
          "dkim_status": "OK",
          "mx_status": "OK",
          "return_path_status": "OK",
          "outgoing": true,
          "incoming": true,
          "stats": {
            "messages_sent_today": 523,
            "messages_sent_this_month": 15834
          }
        },
        {
          "uuid": "domain-uuid-2",
          "name": "mail.example.org",
          "verified": true
        }
      ]
    }
  }
}
```

#### Optional Parameters

- **include_domains**: If set to `true`, the response will include an array of domains associated with the server. The `verified` flag in the domains indicates whether the domain's DNS records have been validated successfully - it will be `true` when the DNS record values match the expected values required for proper domain verification. Each domain will also include its DNS status fields (`spf_status`, `dkim_status`, `mx_status`, `return_path_status`) and usage flags (`outgoing`, `incoming`).
- **include_stats**: Defaults to `true`. If set to `false`, the response will not include the basic stats section (messages sent today and this month). When domains are included with `include_domains: true`, each domain will also include its own stats with message counts specific to that domain.

#### Example with Detailed Statistics

```json
{
  "status": "success",
  "time": 0.155,
  "flags": {},
  "data": {
    "server": {
      "uuid": "server-uuid",
      "name": "Transactional Server",
      "permalink": "transactional-server",
      "mode": "Live",
      "suspended": false,
      "suspension_reason": null,
      "privacy_mode": false,
      "ip_pool_id": "ip-pool-id",
      "created_at": "2023-01-01T12:00:00.000Z",
      "updated_at": "2023-01-01T12:00:00.000Z",
      "domains_count": 3,
      "credentials_count": 2,
      "webhooks_count": 1,
      "routes_count": 5,
      "organization": {
        "uuid": "org-uuid",
        "name": "ACME Inc",
        "permalink": "acme"
      },
      "stats": {
        "messages_sent_today": 1524,
        "messages_sent_this_month": 45789
      },
      "detailed_stats": {
        "daily": [
          {
            "date": "2023-04-14T00:00:00Z",
            "stats": {
              "incoming": 582,
              "outgoing": 1467,
              "bounces": 35,
              "spam": 12,
              "held": 5
            }
          },
          // ... more daily entries
        ],
        "hourly": [
          {
            "date": "2023-04-14T15:00:00Z",
            "stats": {
              "incoming": 62,
              "outgoing": 143,
              "bounces": 3,
              "spam": 1,
              "held": 0
            }
          }
          // ... more hourly entries
        ]
      }
    }
  }
}
```

### Get Email Statistics

**URL:** `/api/v1/servers/email-stats`  
**Method:** POST  

Returns the amount of emails sent within a specified date range for the authenticated server. This endpoint provides aggregated statistics for sent (outgoing) emails for the server associated with the API key.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| start_date | String | Yes | The start date for the range in ISO 8601 format (e.g., "2025-01-01T00:00:00Z") |
| end_date | String | Yes | The end date for the range in ISO 8601 format (e.g., "2025-01-31T23:59:59Z") |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/servers/email-stats \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "start_date": "2025-01-01T00:00:00Z",
    "end_date": "2025-01-31T23:59:59Z"
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.145,
  "flags": {},
  "data": {
    "start_date": "2025-01-01T00:00:00Z",
    "end_date": "2025-01-31T23:59:59Z",
    "server": {
      "uuid": "server-uuid-1",
      "name": "Marketing Server",
      "permalink": "marketing-server",
      "sent_emails": 89432
    }
  }
}
```

#### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| start_date | String | The start date of the range in ISO 8601 format |
| end_date | String | The end date of the range in ISO 8601 format |
| server | Object | Server object with email statistics |
| server.uuid | String | The server's unique identifier |
| server.name | String | The server's name |
| server.permalink | String | The server's URL-friendly permalink |
| server.sent_emails | Integer | Number of emails sent by this server in the date range |

#### Error Responses

**Missing Parameters:**
```json
{
  "status": "parameter-error",
  "time": 0.012,
  "flags": {},
  "data": {
    "message": "start_date is required"
  }
}
```

**Invalid Date Format:**
```json
{
  "status": "parameter-error", 
  "time": 0.015,
  "flags": {},
  "data": {
    "message": "Invalid date format. Use ISO 8601 format (e.g., 2025-01-01T00:00:00Z)"
  }
}
```

**Invalid Date Range:**
```json
{
  "status": "parameter-error",
  "time": 0.018,
  "flags": {},
  "data": {
    "message": "start_date must be before end_date"
  }
}
```

#### Notes

- The endpoint requires authentication using a Server API key in the `X-Server-API-Key` header
- Statistics are retrieved only for the server associated with the API key used for authentication
- Date range is inclusive of both start and end dates
- The system aggregates daily statistics to calculate totals for the specified range
- If statistics cannot be retrieved for the server, it will be included with `sent_emails: 0` and may include an `error` field

### Update Server Mode

**URL:** `/api/v1/servers/update-mode`  
**Method:** POST  

Updates the mode of the authenticated server (switches between Live and Development environments).

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| mode | String | Yes | The server mode, either "Live" or "Development" |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/servers/update-mode \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "mode": "Development"
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.085,
  "flags": {},
  "data": {
    "server": {
      "uuid": "server-uuid-1",
      "name": "Marketing Server", 
      "permalink": "marketing-server",
      "mode": "Development",
      "updated_at": "2025-09-04T14:30:00.000Z"
    }
  }
}
```

#### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| server | Object | Updated server object |
| server.uuid | String | The server's unique identifier |
| server.name | String | The server's name |
| server.permalink | String | The server's URL-friendly permalink |
| server.mode | String | The updated server mode ("Live" or "Development") |
| server.updated_at | String | Server update timestamp |

#### Error Responses

**Missing Mode Parameter:**
```json
{
  "status": "parameter-error",
  "time": 0.012,
  "flags": {},
  "data": {
    "message": "mode is required"
  }
}
```

**Invalid Mode Value:**
```json
{
  "status": "parameter-error",
  "time": 0.015,
  "flags": {},
  "data": {
    "message": "mode must be either 'Live' or 'Development'"
  }
}
```

#### Notes

- The endpoint requires authentication using a Server API key in the `X-Server-API-Key` header
- Only the server associated with the API key can be updated
- "Live" mode is for production environments, "Development" mode is for testing/development

### Delete Server

**URL:** `/api/v1/servers/delete`  
**Method:** POST/DELETE  

Deletes the authenticated server (soft delete).

#### Parameters

None required.

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/servers/delete \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{}'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.125,
  "flags": {},
  "data": {
    "deleted": true,
    "server": {
      "uuid": "server-uuid-1",
      "name": "Marketing Server",
      "permalink": "marketing-server"
    }
  }
}
```

#### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| deleted | Boolean | Confirms the server was deleted (always true on success) |
| server | Object | Information about the deleted server |
| server.uuid | String | The deleted server's unique identifier |
| server.name | String | The deleted server's name |
| server.permalink | String | The deleted server's URL-friendly permalink |

#### Error Responses

**Deletion Failed:**
```json
{
  "status": "error",
  "time": 0.045,
  "flags": {},
  "data": {
    "code": "DeletionError",
    "message": "The server could not be deleted"
  }
}
```

#### Notes

- The endpoint requires authentication using a Server API key in the `X-Server-API-Key` header
- Only the server associated with the API key can be deleted
- This performs a soft delete - the server is marked as deleted but data is preserved
- After deletion, the API key will no longer be valid for authentication
```