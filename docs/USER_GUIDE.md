# Enterprise LLM Gateway - User Guide

## Overview

This is a cost-efficient, secure Generative AI Gateway built on AWS that provides centralized API access to Large Language Models (LLMs) via AWS Bedrock. The system enforces strict monthly budgets and role-based model access.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ARCHITECTURE OVERVIEW                              │
└─────────────────────────────────────────────────────────────────────────────┘

                                    ┌──────────────┐
                                    │    Users     │
                                    │  (API Keys)  │
                                    └──────┬───────┘
                                           │
                                           ▼
                              ┌────────────────────────┐
                              │   Application Load     │
                              │      Balancer (ALB)    │
                              │   (Public Endpoint)    │
                              └────────────┬───────────┘
                                           │
                                           ▼
                              ┌────────────────────────┐
                              │     ECS Fargate        │
                              │    (LiteLLM Proxy)     │
                              │                        │
                              │  • Rate Limiting       │
                              │  • Budget Enforcement  │
                              │  • Model Access Control│
                              │  • Usage Logging       │
                              └─────┬──────────┬───────┘
                                    │          │
                         ┌──────────┘          └──────────┐
                         ▼                                ▼
              ┌──────────────────┐            ┌──────────────────┐
              │  RDS PostgreSQL  │            │   AWS Bedrock    │
              │                  │            │                  │
              │  • User Keys     │            │  • Claude Haiku  │
              │  • Usage Logs    │            │  • Claude Sonnet │
              │  • Budgets       │            │  • DeepSeek R1   │
              │  • Teams         │            │  • Claude Opus   │
              └──────────────────┘            └──────────────────┘
```

---

## How It Works

### 1. Request Flow

```
User Request                    LiteLLM Proxy                      AWS Bedrock
     │                               │                                  │
     │  POST /v1/chat/completions    │                                  │
     │  Authorization: Bearer sk-... │                                  │
     │──────────────────────────────>│                                  │
     │                               │                                  │
     │                    ┌──────────┴──────────┐                       │
     │                    │  1. Validate API Key │                       │
     │                    │  2. Check Budget     │                       │
     │                    │  3. Check Rate Limit │                       │
     │                    │  4. Check Model Access│                      │
     │                    └──────────┬──────────┘                       │
     │                               │                                  │
     │                               │  If all checks pass:             │
     │                               │──────────────────────────────────>│
     │                               │                                  │
     │                               │<──────────────────────────────────│
     │                               │  LLM Response                    │
     │                               │                                  │
     │                    ┌──────────┴──────────┐                       │
     │                    │  5. Log Usage       │                       │
     │                    │  6. Update Budget   │                       │
     │                    └──────────┬──────────┘                       │
     │                               │                                  │
     │<──────────────────────────────│                                  │
     │  Response                     │                                  │
```

### 2. User Governance Tiers

Users are assigned to one of three tiers, each with specific limits:

| Tier | Monthly Budget | Rate Limit | Allowed Models | Use Case |
|------|----------------|------------|----------------|----------|
| **Drafting** | $2.00 | 10 RPM | `model-cheap` | Simple drafting, summaries |
| **Coding** | $20.00 | 50 RPM | `model-balanced` | Code assistance, debugging |
| **Architect** | $500.00 | 100 RPM | `model-reasoning`, `model-reasoning-opus` | Complex reasoning, architecture |

### 3. Model Mapping

Logical model names map to AWS Bedrock models:

| Logical Name | AWS Bedrock Model | Description |
|--------------|-------------------|-------------|
| `model-cheap` | Claude 3.5 Haiku | Fast, cost-effective |
| `model-balanced` | Claude 3.5 Sonnet | Balanced performance |
| `model-reasoning` | DeepSeek R1 | Advanced reasoning |
| `model-reasoning-opus` | Claude Opus 4 | Premium reasoning |

---

## For Administrators

### Deployment

```bash
# 1. Navigate to terraform directory
cd terraform/environments/dev

# 2. Initialize Terraform
terraform init

# 3. Deploy infrastructure
terraform apply

# 4. Get important outputs
terraform output alb_dns_name         # API endpoint
terraform output litellm_master_key   # Admin key (sensitive)
```

### Post-Deployment Setup

```bash
# Set environment variables
export LITELLM_URL="http://$(terraform output -raw alb_dns_name)"
export LITELLM_MASTER_KEY="$(terraform output -raw litellm_master_key)"

# Create governance tier teams (run once)
python scripts/onboard_users.py --create-teams

# Verify health
python scripts/onboard_users.py --health
```

### User Provisioning

```bash
# Add a single user
python scripts/onboard_users.py --add-user \
  --email developer@company.com \
  --tier coding

# Bulk onboard from CSV
python scripts/onboard_users.py --bulk-onboard users.csv

# List all users
python scripts/onboard_users.py --list-users
```

### CSV Format for Bulk Onboarding

```csv
email,tier,alias
alice@company.com,architect,Alice Smith
bob@company.com,coding,Bob Jones
charlie@company.com,drafting,Charlie Brown
```

### Cost Management

```bash
# Destroy infrastructure when not in use
terraform destroy

# Re-deploy when needed
terraform apply
```

**Estimated Costs (while running):**
- RDS db.t4g.micro: ~$0.016/hr
- NAT Gateway: ~$0.045/hr
- ALB: ~$0.0225/hr
- ECS Fargate (Spot): ~$0.01/hr
- **Total: ~$2.16/day**

---

## For End Users

### Getting Your API Key

Contact your administrator to receive:
1. Your API key (starts with `sk-`)
2. Your assigned tier (Drafting, Coding, or Architect)
3. The API endpoint URL

### Making API Requests

The gateway is OpenAI-compatible. Use any OpenAI-compatible client:

#### Using cURL

```bash
curl http://<API_ENDPOINT>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-your-api-key" \
  -d '{
    "model": "model-balanced",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ]
  }'
```

#### Using Python (OpenAI SDK)

```python
from openai import OpenAI

client = OpenAI(
    api_key="sk-your-api-key",
    base_url="http://<API_ENDPOINT>/v1"
)

response = client.chat.completions.create(
    model="model-balanced",  # Use your tier's allowed model
    messages=[
        {"role": "user", "content": "Explain quantum computing"}
    ]
)

print(response.choices[0].message.content)
```

#### Using JavaScript/Node.js

```javascript
import OpenAI from 'openai';

const client = new OpenAI({
  apiKey: 'sk-your-api-key',
  baseURL: 'http://<API_ENDPOINT>/v1'
});

const response = await client.chat.completions.create({
  model: 'model-balanced',
  messages: [
    { role: 'user', content: 'Write a function to sort an array' }
  ]
});

console.log(response.choices[0].message.content);
```

### Available Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check (no auth required) |
| `/v1/models` | GET | List available models |
| `/v1/chat/completions` | POST | Chat completion |
| `/v1/completions` | POST | Text completion |
| `/v1/embeddings` | POST | Text embeddings |

### Understanding Your Limits

#### Budget
- Your monthly budget resets on the 1st of each month
- When you exceed your budget, requests will be rejected
- Check your usage via the `/user/info` endpoint

#### Rate Limits
- RPM (Requests Per Minute) limits are enforced per API key
- Exceeding rate limits returns HTTP 429 (Too Many Requests)
- Wait and retry after a short delay

### Error Responses

| HTTP Code | Meaning | Action |
|-----------|---------|--------|
| 200 | Success | Request completed |
| 400 | Bad Request | Check your request format |
| 401 | Unauthorized | Check your API key |
| 403 | Forbidden | Model not allowed for your tier |
| 429 | Rate Limited | Wait and retry |
| 402 | Budget Exceeded | Contact admin for budget increase |
| 500 | Server Error | Retry or contact admin |

### Example: Check Your Usage

```bash
curl http://<API_ENDPOINT>/user/info \
  -H "Authorization: Bearer sk-your-api-key"
```

Response:
```json
{
  "user_id": "developer@company.com",
  "max_budget": 20.0,
  "spend": 5.50,
  "rpm_limit": 50,
  "models": ["model-balanced"]
}
```

---

## Troubleshooting

### "Model not allowed" Error
You're trying to use a model outside your tier. Check which models your tier allows.

### "Budget exceeded" Error
You've used your monthly budget. Contact your administrator.

### "Rate limit exceeded" Error
You're making requests too quickly. Implement exponential backoff:

```python
import time

def make_request_with_retry(client, max_retries=3):
    for attempt in range(max_retries):
        try:
            return client.chat.completions.create(...)
        except Exception as e:
            if "rate limit" in str(e).lower():
                wait_time = 2 ** attempt  # 1, 2, 4 seconds
                time.sleep(wait_time)
            else:
                raise
    raise Exception("Max retries exceeded")
```

### Connection Errors
1. Verify the API endpoint URL is correct
2. Check if the service is healthy: `curl http://<API_ENDPOINT>/health`
3. Contact your administrator if issues persist

---

## Security Notes

1. **Never share your API key** - It's tied to your identity and budget
2. **Don't commit API keys to code** - Use environment variables
3. **All requests are logged** - Usage is tracked for billing and auditing
4. **HTTPS recommended** - For production, use HTTPS endpoint

---

## Support

- **Technical Issues**: Contact your system administrator
- **Budget Increases**: Request through your manager
- **New User Access**: Submit request to IT department
