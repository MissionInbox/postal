# Domain API

The Domain API allows you to programmatically add and verify domains in Postal.

## Authentication

All API requests require authentication using a Server API key. This should be provided in the `X-Server-API-Key` header.

## Content Types

The API supports two content types:

1. `application/json` - Parameters should be provided as JSON in the request body.
2. `application/x-www-form-urlencoded` - Parameters should be provided as URL-encoded form data with a `params` parameter containing a JSON string.

## Endpoints

### List Domains

**URL:** `/api/v1/domains/list`  
**Method:** POST  

Returns a paginated list of domains associated with the server.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| page | Integer | No | The page number to retrieve (defaults to 1) |
| per_page | Integer | No | The number of domains per page (defaults to 30, max 100) |
| verified | Boolean | No | Filter domains by verification status |
| search | String | No | Search for domains by name |
| order_by | String | No | Field to order by (name, created_at, verified_at) |
| order_direction | String | No | Direction to order (ASC or DESC) |
| include_stats | Boolean | No | Whether to include message statistics for each domain (defaults to false) |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/domains/list \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "page": 1,
    "per_page": 10,
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
    "domains": [
      {
        "uuid": "domain-uuid-1",
        "name": "example.com",
        "verified": true,
        "verified_at": "2023-01-01T12:00:00.000Z",
        "verification_method": "DNS",
        "dns_checked_at": "2023-01-10T15:30:00.000Z",
        "spf_status": "OK",
        "dkim_status": "OK",
        "mx_status": "OK",
        "return_path_status": "OK",
        "outgoing": true,
        "incoming": true,
        "created_at": "2023-01-01T12:00:00.000Z",
        "updated_at": "2023-01-10T15:30:00.000Z",
        "stats": {
          "messages_sent_today": 523,
          "messages_sent_this_month": 15834
        }
      },
      {
        "uuid": "domain-uuid-2",
        "name": "mail.example.org",
        "verified": true,
        "verified_at": "2023-01-05T09:15:00.000Z",
        "verification_method": "DNS",
        "dns_checked_at": "2023-01-10T15:30:00.000Z",
        "spf_status": "OK",
        "dkim_status": "OK",
        "mx_status": "OK",
        "return_path_status": "OK",
        "outgoing": true,
        "incoming": true,
        "created_at": "2023-01-05T09:15:00.000Z",
        "updated_at": "2023-01-10T15:30:00.000Z",
        "stats": {
          "messages_sent_today": 312,
          "messages_sent_this_month": 8721
        }
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 10,
      "total_pages": 1,
      "total_count": 2
    }
  }
}
```

### Create Domain

**URL:** `/api/v1/domains/create`  
**Method:** POST  

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| name | String | Yes | The domain name to add |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/domains/create \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "name": "example.com"
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.055,
  "flags": {},
  "data": {
    "domain": {
      "uuid": "domain-uuid",
      "name": "example.com",
      "verification_method": "DNS",
      "verified": false,
      "verification_token": "verification-token",
      "dns_verification_string": "postal-verify verification-token",
      "created_at": "2023-01-01T12:00:00.000Z",
      "updated_at": "2023-01-01T12:00:00.000Z"
    }
  }
}
```

### Delete Domain

**URL:** `/api/v1/domains/delete/{name}`  
**Method:** DELETE  

Alternatively, you can provide the domain name in the request body:

**URL:** `/api/v1/domains/delete`  
**Method:** POST  

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| name | String | Yes | The name of the domain to delete |

#### Example Request (URL parameter)

```bash
curl -X DELETE \
  https://postal.example.com/api/v1/domains/delete/example.com \
  -H 'X-Server-API-Key: YOUR_API_KEY'
```

#### Example Request (Request body)

```bash
curl -X POST \
  https://postal.example.com/api/v1/domains/delete \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "name": "example.com"
  }'
```

#### Example Success Response

```json
{
  "status": "success",
  "time": 0.055,
  "flags": {},
  "data": {
    "deleted": true,
    "domain": {
      "uuid": "domain-uuid",
      "name": "example.com"
    }
  }
}
```

#### Example Error Response

```json
{
  "status": "error",
  "time": 0.055,
  "flags": {},
  "data": {
    "code": "InvalidDomain",
    "message": "The domain could not be found with the provided name",
    "name": "nonexistent-domain.com"
  }
}
```

### Verify Domain

**URL:** `/api/v1/domains/verify`  
**Method:** POST  

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| domain_id | String | Yes | The UUID of the domain to verify |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/domains/verify \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "domain_id": "domain-uuid"
  }'
```

#### Example Success Response

```json
{
  "status": "success",
  "time": 0.055,
  "flags": {},
  "data": {
    "domain": {
      "uuid": "domain-uuid",
      "name": "example.com",
      "verified": true,
      "verified_at": "2023-01-01T12:00:00.000Z"
    }
  }
}
```

#### Example Error Response

```json
{
  "status": "error",
  "time": 0.055,
  "flags": {},
  "data": {
    "code": "VerificationFailed",
    "message": "We couldn't verify your domain. Please double check you've added the TXT record correctly.",
    "dns_verification_string": "postal-verify verification-token"
  }
}
```

### Get DNS Records

**URL:** `/api/v1/domains/dns_records`  
**Method:** POST  

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| domain_id | String | Yes | The UUID of the domain to get DNS records for |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/domains/dns_records \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "domain_id": "domain-uuid"
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.055,
  "flags": {},
  "data": {
    "domain": {
      "uuid": "domain-uuid",
      "name": "example.com",
      "verified": true
    },
    "dns_records": [
      {
        "type": "TXT",
        "name": "example.com",
        "value": "v=spf1 a mx include:spf.postal.example.com ~all",
        "purpose": "spf"
      },
      {
        "type": "TXT",
        "name": "postal-abc123._domainkey.example.com",
        "short_name": "postal-abc123._domainkey",
        "value": "v=DKIM1; t=s; h=sha256; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCuGbIaO4c5rhYkHPMYMH/Cg8zRW...",
        "purpose": "dkim"
      },
      {
        "type": "CNAME",
        "name": "rp.example.com",
        "short_name": "rp",
        "value": "return.postal.example.com",
        "purpose": "return_path"
      },
      {
        "type": "MX",
        "name": "example.com",
        "priority": 10,
        "value": "mx.postal.example.com",
        "purpose": "mx"
      }
    ]
  }
}
```

## DNS Verification

To verify your domain via DNS, add a TXT record to your domain with the following content:

```
postal-verify YOUR_VERIFICATION_TOKEN
```

The verification token and full verification string are provided in the response when you create a domain.

## DNS Record Types

When setting up a domain with Postal, you'll need to configure several DNS records:

1. **Verification Record (TXT)** - Used to verify domain ownership
2. **SPF Record (TXT)** - Specifies which servers are allowed to send email for your domain
3. **DKIM Record (TXT)** - Enables cryptographic signing of messages
4. **Return Path Record (CNAME)** - Used for return path/bounce handling
5. **MX Records** - Required if you want to receive inbound email
6. **Tracking Domain Records (CNAME)** - For open/click tracking

The `dns_records` endpoint provides all the necessary records for proper configuration.