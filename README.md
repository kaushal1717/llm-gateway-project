# Enterprise LLM Gateway

A cost-efficient, secure Generative AI Gateway on AWS using LiteLLM as a proxy to AWS Bedrock. This system centralizes API access for users with strict monthly budgets and role-based model access.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                                   │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                         VPC (10.0.0.0/16)                        │   │
│  │                                                                   │   │
│  │   ┌─────────────────┐         ┌─────────────────┐                │   │
│  │   │  Public Subnet  │         │  Public Subnet  │                │   │
│  │   │   10.0.101.0/24 │         │   10.0.102.0/24 │                │   │
│  │   │                 │         │                 │                │   │
│  │   │  ┌───────────┐  │         │                 │                │   │
│  │   │  │    ALB    │  │         │                 │                │   │
│  │   │  └─────┬─────┘  │         │                 │                │   │
│  │   └────────┼────────┘         └─────────────────┘                │   │
│  │            │                                                      │   │
│  │   ┌────────┼────────┐         ┌─────────────────┐                │   │
│  │   │ Private Subnet  │         │  Private Subnet │                │   │
│  │   │   10.0.1.0/24   │         │   10.0.2.0/24   │                │   │
│  │   │                 │         │                 │                │   │
│  │   │  ┌───────────┐  │         │  ┌───────────┐  │                │   │
│  │   │  │    ECS    │  │         │  │    RDS    │  │                │   │
│  │   │  │  Fargate  │◄─┼─────────┼──►│ PostgreSQL│  │                │   │
│  │   │  │ (LiteLLM) │  │         │  │           │  │                │   │
│  │   │  └─────┬─────┘  │         │  └───────────┘  │                │   │
│  │   └────────┼────────┘         └─────────────────┘                │   │
│  │            │                                                      │   │
│  └────────────┼──────────────────────────────────────────────────────┘   │
│               │                                                          │
│               ▼                                                          │
│      ┌─────────────────┐                                                │
│      │   AWS Bedrock   │                                                │
│      │  (US Region)    │                                                │
│      │  - Nova Micro   │                                                │
│      │  - Nova Lite    │                                                │
│      │  - Nova Pro     │                                                │
│      └─────────────────┘                                                │
└─────────────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Purpose |
|-----------|---------|
| **LiteLLM** | OpenAI-compatible proxy that handles authentication, rate limiting, budgets, and usage tracking |
| **AWS ECS Fargate** | Serverless container hosting (Spot instances for cost savings) |
| **AWS RDS PostgreSQL** | Stores API keys, teams, usage data, and spend tracking |
| **AWS ALB** | Load balancer for HTTP traffic |
| **AWS Bedrock** | LLM inference (Amazon Nova models via US cross-region inference) |

## User Governance Tiers

| Tier | Daily Budget | Monthly Cap | Allowed Models |
|------|--------------|-------------|----------------|
| **Drafting** | $0.017/day | $0.50/month | model-cheap (Nova Micro) |
| **Coding** | $0.033/day | $1.00/month | model-balanced (Nova Lite) |
| **Architect** | $0.067/day | $2.00/month | model-reasoning (Nova Pro) |

**Budget Strategy:**
- **Daily Budget**: Hard limit that resets every 24 hours - prevents sudden cost spikes
- **Monthly Cap**: Safety limit tracked separately - backstop protection
- LiteLLM tracks spend in real-time and blocks requests when daily budget is exceeded

## Model Mapping

| Logical Name | AWS Bedrock Model | Description |
|--------------|-------------------|-------------|
| model-cheap | us.amazon.nova-micro-v1:0 | Fast, cost-effective for simple tasks |
| model-balanced | us.amazon.nova-lite-v1:0 | Balanced performance and cost |
| model-reasoning | us.amazon.nova-pro-v1:0 | Advanced reasoning capabilities |

---

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Python 3.8+ with pip
- An AWS account with Bedrock access

## Quick Start

### 1. Clone and Setup

```bash
cd /path/to/aws-LLM-rate-limiter
```

### 2. Configure Terraform Variables

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
# AWS Configuration
aws_region   = "ap-south-1"
aws_profile  = "your-aws-profile"
project_name = "llm-gateway"
environment  = "dev"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["ap-south-1a", "ap-south-1b"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]

# RDS Configuration
db_instance_class    = "db.t4g.micro"
db_allocated_storage = 20
db_engine_version    = "16"
db_name              = "litellm"
db_username          = "litellm"

# ECS Configuration
container_image = "ghcr.io/berriai/litellm:main-latest"
container_port  = 4000
task_cpu        = 512   # 0.5 vCPU
task_memory     = 1024  # 1 GB
desired_count   = 1
min_capacity    = 1
max_capacity    = 3

# SSL Certificate (leave empty for HTTP)
certificate_arn = ""
```

### 3. Deploy Infrastructure

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (this takes ~10-15 minutes)
terraform apply
```

### 4. Get the Gateway URL and Master Key

After deployment, note these outputs:
- **ALB URL**: `http://llm-gateway-dev-alb-XXXXXXXXX.ap-south-1.elb.amazonaws.com`
- **Master Key**: Found in AWS Secrets Manager or Terraform output

### 5. Configure Environment

Create `scripts/.env`:

```bash
LITELLM_URL=http://llm-gateway-dev-alb-XXXXXXXXX.ap-south-1.elb.amazonaws.com
LITELLM_MASTER_KEY=sk-your-master-key-here
```

### 6. Add Models to LiteLLM

Since ap-south-1 doesn't have direct Bedrock access, we use US cross-region inference profiles:

```bash
# Add model-cheap (Nova Micro)
curl -X POST "$LITELLM_URL/model/new" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "model-cheap",
    "litellm_params": {
      "model": "bedrock/converse/us.amazon.nova-micro-v1:0",
      "aws_region_name": "us-east-1"
    }
  }'

# Add model-balanced (Nova Lite)
curl -X POST "$LITELLM_URL/model/new" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "model-balanced",
    "litellm_params": {
      "model": "bedrock/converse/us.amazon.nova-lite-v1:0",
      "aws_region_name": "us-east-1"
    }
  }'

# Add model-reasoning (Nova Pro)
curl -X POST "$LITELLM_URL/model/new" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "model-reasoning",
    "litellm_params": {
      "model": "bedrock/converse/us.amazon.nova-pro-v1:0",
      "aws_region_name": "us-east-1"
    }
  }'
```

### 7. Create Teams

```bash
cd scripts
pip install pyyaml python-dotenv requests

# Create teams from tiers.yaml
python onboard_users.py --create-teams
```

Or manually:

```bash
# Create Drafting team
curl -X POST "$LITELLM_URL/team/new" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "team_alias": "drafting",
    "models": ["model-cheap"],
    "max_budget": 0.017,
    "budget_duration": "1d"
  }'

# Create Coding team
curl -X POST "$LITELLM_URL/team/new" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "team_alias": "coding",
    "models": ["model-balanced"],
    "max_budget": 0.033,
    "budget_duration": "1d"
  }'

# Create Architect team
curl -X POST "$LITELLM_URL/team/new" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "team_alias": "architect",
    "models": ["model-reasoning"],
    "max_budget": 0.067,
    "budget_duration": "1d"
  }'
```

### 8. Onboard Users

Add users to `scripts/users_to_onboard.csv`:

```csv
email,tier,alias,budget,rpm
user1@example.com,drafting,User One,,
user2@example.com,coding,User Two,,
user3@example.com,architect,User Three,,
```

Then run:

```bash
python onboard_users.py --bulk-onboard users_to_onboard.csv
```

Or generate keys manually:

```bash
curl -X POST "$LITELLM_URL/key/generate" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user@example.com",
    "team_id": "drafting",
    "key_alias": "User Name"
  }'
```

---

## Accessing the LiteLLM UI

The LiteLLM Admin UI is enabled and accessible via your ALB URL.

### UI Access

```bash
# Open in browser
http://llm-gateway-dev-alb-XXXXXXXXX.ap-south-1.elb.amazonaws.com/ui
```

**Authentication:**
- **Username:** `admin`
- **Password:** `admin123`
- Once logged in, use your Master Key for API operations

**The UI provides:**
- Visual interface to view and manage models
- Monitor API keys and teams
- Track usage and spending in real-time
- View logs and metrics
- Test API endpoints directly

### Swagger/OpenAPI Docs

```bash
# API documentation
http://llm-gateway-dev-alb-XXXXXXXXX.ap-south-1.elb.amazonaws.com/
```

The root URL provides interactive API documentation powered by Swagger UI.

---

## API Usage

### Chat Completions (OpenAI-Compatible)

```bash
curl -X POST "$LITELLM_URL/chat/completions" \
  -H "Authorization: Bearer $USER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "model-cheap",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Python SDK

```python
from openai import OpenAI

client = OpenAI(
    api_key="sk-user-api-key",
    base_url="http://llm-gateway-dev-alb-XXXXX.ap-south-1.elb.amazonaws.com"
)

response = client.chat.completions.create(
    model="model-cheap",
    messages=[{"role": "user", "content": "Hello!"}]
)
print(response.choices[0].message.content)
```

### Streaming

```python
stream = client.chat.completions.create(
    model="model-cheap",
    messages=[{"role": "user", "content": "Tell me a story"}],
    stream=True
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

---

## Admin Operations

### List All Models

```bash
curl -s "$LITELLM_URL/models" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq
```

### List All Keys

```bash
curl -s "$LITELLM_URL/key/list" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq
```

### List All Teams

```bash
curl -s "$LITELLM_URL/team/list" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq
```

### Check User Spend

```bash
curl -s "$LITELLM_URL/user/info" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_ids": ["user@example.com"]}' | jq
```

### Health Check

```bash
curl -s "$LITELLM_URL/health" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq
```

### Delete a Model

```bash
curl -X POST "$LITELLM_URL/model/delete" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id": "model-id-here"}'
```

### Delete a Key

```bash
curl -X POST "$LITELLM_URL/key/delete" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"keys": ["sk-key-to-delete"]}'
```

---

## Tear Down & Rebuild

This infrastructure is designed for cost-efficiency. You can destroy and recreate it as needed:

### Destroy Infrastructure

```bash
cd terraform/environments/dev
terraform destroy
```

**Note:** RDS has `skip_final_snapshot = true` and `deletion_protection = false` for easy teardown. Change these for production.

### Rebuild

```bash
terraform apply
```

After rebuilding, you'll need to:
1. Re-add models (Step 6)
2. Re-create teams (Step 7)
3. Re-generate user API keys (Step 8)

---

## Configuration Files

### Tiers Configuration (`config/tiers.yaml`)

```yaml
tiers:
  drafting:
    name: "Drafting"
    budget_daily: 0.017     # ~$0.50/month ÷ 30 days
    budget_monthly: 0.50
    allowed_models:
      - model-cheap

  coding:
    name: "Coding"
    budget_daily: 0.033     # ~$1.00/month ÷ 30 days
    budget_monthly: 1.00
    allowed_models:
      - model-balanced

  architect:
    name: "Architect"
    budget_daily: 0.067     # ~$2.00/month ÷ 30 days
    budget_monthly: 2.00
    allowed_models:
      - model-reasoning
```

### Environment Variables (`scripts/.env`)

```bash
LITELLM_URL=http://your-alb-url.elb.amazonaws.com
LITELLM_MASTER_KEY=sk-your-master-key
```

---

## Troubleshooting

### 502 Bad Gateway

The LiteLLM container may be restarting. Wait 30 seconds and retry. Check ECS service health in AWS Console.

### Model "Invalid Identifier" Error

Ensure you're using the correct model format with US cross-region inference:
- Use `bedrock/converse/us.amazon.nova-micro-v1:0` (not `apac.` or direct model IDs)
- Set `aws_region_name: "us-east-1"`

### IAM Permission Denied

The ECS task role needs Bedrock permissions. Verify the IAM policy includes:
```
arn:aws:bedrock:*:<account_id>:inference-profile/us.*
```

### Database Connection Issues

The db.t4g.micro has limited connections (~80). LiteLLM is configured with `DATABASE_CONNECTION_POOL_LIMIT=5` to prevent exhaustion.

### Health Check Shows Unhealthy Models

Cross-region inference profiles have known issues with LiteLLM health checks. Test with actual chat completions instead:
```bash
curl -X POST "$LITELLM_URL/chat/completions" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "model-cheap", "messages": [{"role": "user", "content": "test"}]}'
```

---

## Cost Optimization

1. **ECS Fargate Spot**: Uses Spot instances (up to 70% savings)
2. **db.t4g.micro**: Smallest RDS instance for MVP
3. **Single AZ**: No multi-AZ redundancy for dev
4. **Destroy when not in use**: `terraform destroy` to stop all costs

---

## Security Notes

- Master key is stored in AWS Secrets Manager
- RDS is not publicly accessible
- ECS tasks run in private subnets
- All secrets are passed via environment variables (not config files)
- User API keys are hashed in the database

---

## Project Structure

```
aws-LLM-rate-limiter/
├── terraform/
│   ├── environments/
│   │   └── dev/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── terraform.tfvars
│   └── modules/
│       ├── vpc/
│       ├── rds/
│       ├── ecs/
│       ├── alb/
│       ├── security-groups/
│       └── secrets/
├── config/
│   └── tiers.yaml
├── scripts/
│   ├── onboard_users.py
│   ├── users_to_onboard.csv
│   ├── .env
│   └── .env.example
└── README.md
```

---

## References

- [LiteLLM Documentation](https://docs.litellm.ai/)
- [AWS Bedrock Models](https://docs.aws.amazon.com/bedrock/latest/userguide/models-supported.html)
- [AWS Bedrock Cross-Region Inference](https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html)
