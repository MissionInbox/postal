# Organizations API

The Organizations API allows you to programmatically retrieve statistics and information about your Postal organizations.

## Authentication

Organization-specific API requests require authentication using an Organization UUID. This should be provided as a parameter in the request.

## Content Types

The API supports two content types:

1. `application/json` - Parameters should be provided as JSON in the request body.
2. `application/x-www-form-urlencoded` - Parameters should be provided as URL-encoded form data with a `params` parameter containing a JSON string.

## Endpoints

### Organization Statistics

**URL:** `/api/v1/organizations/statistics`  
**Method:** POST  

Retrieves comprehensive statistics for a specific organization, including message rates, queue counts, server information, and IP address assignments.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| uuid | String | Yes | The UUID of the organization to retrieve statistics for |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/organizations/statistics \
  -H 'Content-Type: application/json' \
  -d '{
    "uuid": "org-uuid-123"
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.125,
  "flags": {},
  "data": {
    "statistics": {
      "uuid": "org-uuid-123",
      "name": "ACME Inc",
      "overall_message_rate": 15.7,
      "total_queued_count": 342,
      "total_sent": 945,
      "servers_count": 3,
      "ip_addresses_count": 5,
      "ip_addresses": [
        {
          "id": 1,
          "ipv4": "192.168.1.10",
          "ipv6": "2001:db8::1",
          "hostname": "mail1.example.com",
          "priority": 100
        },
        {
          "id": 2,
          "ipv4": "192.168.1.11",
          "ipv6": null,
          "hostname": "mail2.example.com",
          "priority": 90
        }
      ],
      "servers": [
        {
          "uuid": "server-uuid-1",
          "name": "Marketing Server",
          "queued_count": 125,
          "message_rate": 8.3,
          "sent_count": 420
        },
        {
          "uuid": "server-uuid-2",
          "name": "Transactional Server",
          "queued_count": 217,
          "message_rate": 7.4,
          "sent_count": 525
        }
      ]
    }
  }
}
```

#### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| uuid | String | The organization's unique identifier |
| name | String | The organization's name |
| overall_message_rate | Float | Total message rate across all servers (messages per second over last 60 seconds) |
| total_queued_count | Integer | Total number of queued messages across all servers |
| total_sent | Integer | Total messages sent in the last 60 seconds across all servers |
| servers_count | Integer | Number of servers in the organization |
| ip_addresses_count | Integer | Number of IP addresses assigned to the organization |
| ip_addresses | Array | List of IP addresses with details (id, ipv4, ipv6, hostname, priority) |
| servers | Array | List of servers with individual statistics |

#### Server Statistics Fields

Each server in the `servers` array contains:

| Field | Type | Description |
|-------|------|-------------|
| uuid | String | The server's unique identifier |
| name | String | The server's name |
| queued_count | Integer | Number of queued messages for this server |
| message_rate | Float | Message rate for this server (messages per second over last 60 seconds) |
| sent_count | Integer | Messages sent by this server in the last 60 seconds |

#### Error Responses

**Missing UUID Parameter:**

```json
{
  "status": "parameter-error",
  "time": 0.001,
  "flags": {},
  "data": {
    "message": "organization_uuid is required"
  }
}
```

**Invalid Organization UUID:**

```json
{
  "status": "error",
  "time": 0.023,
  "flags": {},
  "data": {
    "code": "InvalidOrganization",
    "message": "The organization could not be found with the provided UUID"
  }
}
```

## Use Cases

This endpoint is particularly useful for:

- **Monitoring dashboards**: Get real-time statistics for organization-level monitoring
- **Load balancing**: Understand message rates and queue depths across servers
- **Capacity planning**: Monitor IP address utilization and server performance
- **Operations monitoring**: Track overall organization health and performance metrics

The statistics provide a comprehensive view of your organization's email infrastructure performance and can be used to make informed decisions about scaling, load distribution, and resource allocation.