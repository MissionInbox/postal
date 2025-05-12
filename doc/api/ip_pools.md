# IP Pools API

## Getting IP Pools

IP pools are groups of IP addresses that can be used for sending mail. Each IP address can be in multiple pools, and pools can be assigned to servers or used in IP pool rules.

```
GET /api/v1/servers/ip_pools
```

### Parameters

There are no additional parameters for this endpoint.

### Example

```
curl -X GET \
  https://postal.example.com/api/v1/servers/ip_pools \
  -H 'x-server-api-key: EXAMPLE-API-KEY'
```

### Success Response

```json
{
  "status": "success",
  "data": {
    "ip_pools": [
      {
        "id": 1,
        "uuid": "abc123",
        "name": "Main Pool",
        "default": true,
        "created_at": "2025-05-13T12:00:00.000Z",
        "ip_addresses": [
          {
            "id": 1,
            "ipv4": "1.2.3.4",
            "ipv6": "2001:0db8:85a3:0000:0000:8a2e:0370:7334",
            "hostname": "mail1.example.com",
            "priority": 100
          },
          {
            "id": 2,
            "ipv4": "5.6.7.8",
            "ipv6": null,
            "hostname": "mail2.example.com",
            "priority": 50
          }
        ]
      },
      {
        "id": 2,
        "uuid": "def456",
        "name": "Secondary Pool",
        "default": false,
        "created_at": "2025-05-13T12:00:00.000Z",
        "ip_addresses": [
          {
            "id": 1,
            "ipv4": "1.2.3.4",
            "ipv6": "2001:0db8:85a3:0000:0000:8a2e:0370:7334",
            "hostname": "mail1.example.com",
            "priority": 100
          }
        ]
      }
    ]
  }
}
```

Note that the same IP address can appear in multiple pools as shown in the example above, where IP address with id 1 appears in both pools.

## Creating an IP Pool

This endpoint allows you to create a new IP pool and add IP addresses to it in a single operation. If any of the IP addresses already exist, they will be reused and added to the new pool.

```
POST /api/v1/servers/ip_pools/create
```

### Parameters

| Name | Type | Description |
|------|------|-------------|
| name | string | **Required**. The name of the new IP pool. |
| ips | array | **Required**. An array of IP addresses (as strings) to add to the pool. |

### Example

```
curl -X POST \
  https://postal.example.com/api/v1/servers/ip_pools/create \
  -H 'x-server-api-key: EXAMPLE-API-KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Apple",
    "ips": ["1.1.1.1", "2.2.2.2"]
  }'
```

### Success Response

```json
{
  "status": "success",
  "data": {
    "ip_pool": {
      "id": 3,
      "uuid": "ghi789",
      "name": "Apple",
      "created_at": "2025-05-13T14:30:00.000Z",
      "ip_addresses": [
        {
          "id": 5,
          "ipv4": "1.1.1.1",
          "hostname": "1-1-1-1.example.postal"
        },
        {
          "id": 6,
          "ipv4": "2.2.2.2",
          "hostname": "2-2-2-2.example.postal"
        }
      ]
    }
  }
}
```

If any IP addresses could not be added (for example, due to validation errors), they will be listed in the `warnings` field:

```json
{
  "status": "success",
  "data": {
    "ip_pool": {
      "id": 3,
      "uuid": "ghi789",
      "name": "Apple",
      "created_at": "2025-05-13T14:30:00.000Z",
      "ip_addresses": [
        {
          "id": 5,
          "ipv4": "1.1.1.1",
          "hostname": "1-1-1-1.example.postal"
        }
      ]
    },
    "warnings": [
      "not-a-valid-ip: Ipv4 is not a valid IPv4 address"
    ]
  }
}
```

### Error Response

If there's an error creating the IP pool:

```json
{
  "status": "error",
  "data": {
    "code": "ValidationError",
    "message": "Name has already been taken"
  }
}
```

For missing or invalid parameters:

```json
{
  "status": "error",
  "data": {
    "code": "ParameterError",
    "message": "Missing required parameter 'name'"
  }
}
```

For permission issues:

```json
{
  "status": "error",
  "data": {
    "code": "AccessDenied",
    "message": "You don't have permission to create IP pools"
  }
}
```