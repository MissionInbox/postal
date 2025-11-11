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

---

### IP Allocation

**URL:** `/api/v1/organizations/ip_allocation`
**Method:** POST

Retrieves the complete email sending IP allocation mapping for an organization, showing which IP addresses are assigned to which IP pools, which servers (customers) are using which IP pools, and the total number of emails sent through each IP, pool, and server.

This endpoint provides a comprehensive view of your organization's email sending infrastructure and is particularly useful for understanding IP allocation, tracking email volume distribution, and monitoring IP reputation across different servers.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| uuid | String | Yes | The UUID of the organization to retrieve IP allocation for |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/organizations/ip_allocation \
  -H 'Content-Type: application/json' \
  -d '{
    "uuid": "org-uuid-123"
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.245,
  "flags": {},
  "data": {
    "organization": {
      "uuid": "org-uuid-123",
      "name": "ACME Inc"
    },
    "ip_addresses": [
      {
        "ipv4": "192.168.1.10",
        "ipv6": "2001:db8::1",
        "hostname": "mail1.example.com",
        "priority": 100,
        "ip_pools": ["Marketing Pool", "Transactional Pool"],
        "emails_sent": 125340
      },
      {
        "ipv4": "192.168.1.11",
        "ipv6": null,
        "hostname": "mail2.example.com",
        "priority": 90,
        "ip_pools": ["Marketing Pool"],
        "emails_sent": 89250
      }
    ],
    "ip_pools": [
      {
        "name": "Marketing Pool",
        "uuid": "pool-uuid-1",
        "default": false,
        "servers": ["Marketing Server", "Newsletter Server"],
        "emails_sent": 214590
      },
      {
        "name": "Transactional Pool",
        "uuid": "pool-uuid-2",
        "default": true,
        "servers": ["Transactional Server"],
        "emails_sent": 125340
      }
    ],
    "servers": [
      {
        "name": "Marketing Server",
        "uuid": "server-uuid-1",
        "ip_pool": "Marketing Pool",
        "ip_addresses": ["192.168.1.10", "192.168.1.11"],
        "emails_sent": 156780
      },
      {
        "name": "Newsletter Server",
        "uuid": "server-uuid-2",
        "ip_pool": "Marketing Pool",
        "ip_addresses": ["192.168.1.10", "192.168.1.11"],
        "emails_sent": 57810
      },
      {
        "name": "Transactional Server",
        "uuid": "server-uuid-3",
        "ip_pool": "Transactional Pool",
        "ip_addresses": ["192.168.1.10"],
        "emails_sent": 125340
      },
      {
        "name": "Development Server",
        "uuid": "server-uuid-4",
        "ip_pool": null,
        "ip_addresses": [],
        "emails_sent": 0
      }
    ]
  }
}
```

#### Response Fields

**Organization Information:**

| Field | Type | Description |
|-------|------|-------------|
| uuid | String | The organization's unique identifier |
| name | String | The organization's name |

**IP Addresses Array:**

Each IP address object contains:

| Field | Type | Description |
|-------|------|-------------|
| ipv4 | String | The IPv4 address |
| ipv6 | String/null | The IPv6 address (if configured) |
| hostname | String | The hostname associated with this IP |
| priority | Integer | The priority of this IP (0-100, higher = more preferred) |
| ip_pools | Array | List of IP pool names this IP belongs to |
| emails_sent | Integer | Total number of emails sent through this IP address |

**IP Pools Array:**

Each IP pool object contains:

| Field | Type | Description |
|-------|------|-------------|
| name | String | The name of the IP pool |
| uuid | String | The pool's unique identifier |
| default | Boolean | Whether this is the default pool for the organization |
| servers | Array | List of server names using this IP pool |
| emails_sent | Integer | Total number of emails sent through this IP pool |

**Servers Array:**

Each server object contains:

| Field | Type | Description |
|-------|------|-------------|
| name | String | The server's name |
| uuid | String | The server's unique identifier |
| ip_pool | String/null | The name of the IP pool assigned to this server (null if none) |
| ip_addresses | Array | List of IPv4 addresses available to this server through its IP pool |
| emails_sent | Integer | Total number of outgoing emails sent from this server |

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

#### Use Cases

This endpoint is particularly useful for:

- **IP Allocation Visibility**: Understand which IPs are assigned to which pools and which servers use those pools
- **Email Volume Tracking**: Monitor email sending volumes across different IPs, pools, and servers
- **IP Reputation Management**: Track which IPs are sending the most emails to manage reputation
- **Infrastructure Auditing**: Get a complete view of your email sending infrastructure setup
- **Capacity Planning**: Identify underutilized or overutilized IPs and pools
- **Troubleshooting**: Quickly identify which servers are using which IPs when investigating delivery issues
- **Compliance & Reporting**: Generate reports on email sending infrastructure and volume distribution

#### Understanding the Relationships

The data shows three key relationships:

1. **IP Addresses → IP Pools**: One IP address can belong to multiple IP pools
2. **IP Pools → Servers**: One IP pool can be used by multiple servers (customers)
3. **Servers → IP Addresses**: Servers inherit all IP addresses from their assigned IP pool

This hierarchical structure allows for flexible IP management where:
- Organizations can group IPs into logical pools (e.g., "Marketing", "Transactional")
- Servers can be assigned to pools to use those IPs for sending
- Email sending volumes can be tracked at each level for monitoring and optimization