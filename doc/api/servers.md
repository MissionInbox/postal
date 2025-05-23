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

Creates a new server in the specified organization.

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

If a server with the same name already exists in the organization, the API will return the existing server's details with a flag indicating `"already_exists": true`.

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
          },
          // ... more hourly entries
        ]
      }
    }
  }
}
```