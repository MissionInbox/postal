# IP Addresses API

This document describes the endpoints related to IP addresses.

## Getting IP addresses assigned to a server

```
GET /api/v1/servers/ip_addresses
```

This endpoint requires a server API key for authentication using the `X-Server-API-Key` header. Organization API keys are not supported.

### Authentication

- Provide the server API key in the `X-Server-API-Key` HTTP header.

### Parameters

* No additional parameters required. The server is identified by the API key.

### Example Request

```
curl -X GET https://postal.example.com/api/v1/servers/ip_addresses \
  -H "X-Server-API-Key: xxxxx"
```

Where `xxxxx` is a valid server API key.

### Example Response

```json
{
  "status": "success",
  "time": 0.123,
  "flags": {},
  "data": {
    "ip_addresses": [
      {
        "ipv4": "192.168.0.1",
        "ipv6": null,
        "hostname": "server1.example.com",
        "priority": 10
      },
      {
        "ipv4": "192.168.0.3",
        "ipv6": null,
        "hostname": "server3.example.com",
        "priority": 20
      }
    ]
  }
}
```

The response includes IP addresses that could be used by the server from:
- The server's default IP pool
- IP pool rules assigned to the server

Note: Email-to-IP mappings are deliberately excluded from this API.
