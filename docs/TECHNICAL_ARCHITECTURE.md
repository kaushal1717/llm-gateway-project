# Technical Architecture - How Everything Works

## The Key Insight: LiteLLM Does the Heavy Lifting

**We are NOT writing the API server, rate limiter, or database logic.**

LiteLLM is a pre-built, production-ready proxy that provides:
- OpenAI-compatible API endpoints
- Built-in rate limiting
- Built-in budget tracking
- Built-in API key management
- Automatic PostgreSQL schema creation
- Automatic usage logging

**Our job is only to:**
1. Deploy the infrastructure (Terraform)
2. Configure LiteLLM (config.yaml)
3. Provision users (onboard_users.py)

---

## Component Breakdown

### 1. LiteLLM Container (ghcr.io/berriai/litellm:main-latest)

This Docker image contains a complete Python application that:

```
┌─────────────────────────────────────────────────────────────────┐
│                    LiteLLM Container                            │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   FastAPI Server                         │   │
│  │                                                          │   │
│  │  Endpoints (Pre-built, we don't write these):            │   │
│  │  ├── GET  /health           → Health check               │   │
│  │  ├── GET  /v1/models        → List models                │   │
│  │  ├── POST /v1/chat/completions → Chat API               │   │
│  │  ├── POST /v1/completions   → Completion API             │   │
│  │  ├── POST /v1/embeddings    → Embeddings API             │   │
│  │  │                                                       │   │
│  │  │  Admin Endpoints (used by onboard_users.py):          │   │
│  │  ├── POST /key/generate     → Create API key             │   │
│  │  ├── GET  /key/info         → Get key details            │   │
│  │  ├── POST /key/delete       → Delete key                 │   │
│  │  ├── POST /team/new         → Create team                │   │
│  │  ├── GET  /team/list        → List teams                 │   │
│  │  └── GET  /user/info        → User spend info            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│  ┌───────────────────────────┴───────────────────────────┐     │
│  │              Internal Components                       │     │
│  │                                                        │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │     │
│  │  │ Auth/Key     │  │ Rate         │  │ Budget      │  │     │
│  │  │ Validator    │  │ Limiter      │  │ Tracker     │  │     │
│  │  └──────────────┘  └──────────────┘  └─────────────┘  │     │
│  │                                                        │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │     │
│  │  │ Model        │  │ Provider     │  │ Callback    │  │     │
│  │  │ Router       │  │ Handler      │  │ Manager     │  │     │
│  │  └──────────────┘  └──────────────┘  └─────────────┘  │     │
│  └────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

### 2. How Our Config Controls LiteLLM

```yaml
# config.yaml - This configures LiteLLM's behavior

model_list:                          # ← Tells LiteLLM which models to expose
  - model_name: model-cheap          # ← User requests this name
    litellm_params:
      model: bedrock/anthropic...    # ← LiteLLM calls this actual model

general_settings:
  database_url: os.environ/DATABASE_URL    # ← Where to store everything
  master_key: os.environ/LITELLM_MASTER_KEY # ← Admin authentication

litellm_settings:
  success_callback: ["postgres"]     # ← Auto-log every request to DB
  failure_callback: ["postgres"]     # ← Auto-log failures too
```

### 3. How API Key Creation Works

When we run `onboard_users.py --add-user`:

```
┌─────────────────┐      HTTP POST /key/generate       ┌─────────────────┐
│                 │ ──────────────────────────────────>│                 │
│  onboard_users  │     {                              │    LiteLLM      │
│     .py         │       "user_id": "user@email.com", │    Proxy        │
│                 │       "max_budget": 20.00,         │                 │
│                 │       "rpm_limit": 50,             │                 │
│                 │       "models": ["model-balanced"] │                 │
│                 │     }                              │                 │
│                 │ <──────────────────────────────────│                 │
│                 │     {"key": "sk-abc123..."}        │                 │
└─────────────────┘                                    └────────┬────────┘
                                                                │
                                                                │ INSERT INTO
                                                                │ LiteLLM_KeyTable
                                                                ▼
                                                       ┌─────────────────┐
                                                       │   PostgreSQL    │
                                                       │                 │
                                                       │ Keys stored     │
                                                       │ with limits     │
                                                       └─────────────────┘
```

### 4. How a User Request is Processed

```
Step-by-step flow when user calls /v1/chat/completions:

┌──────────┐                    ┌─────────────────────────────────────────────┐
│          │  1. API Request    │              LiteLLM Proxy                  │
│   User   │ ─────────────────> │                                             │
│          │  Authorization:    │  ┌─────────────────────────────────────┐    │
│          │  Bearer sk-abc123  │  │ 2. Key Validation                   │    │
└──────────┘                    │  │    - Look up sk-abc123 in DB        │    │
                                │  │    - Get user_id, budget, rpm, models│    │
                                │  └──────────────────┬──────────────────┘    │
                                │                     │                        │
                                │  ┌──────────────────▼──────────────────┐    │
                                │  │ 3. Rate Limit Check                 │    │
                                │  │    - Count requests in last minute  │    │
                                │  │    - Compare to rpm_limit (50)      │    │
                                │  │    - If exceeded → 429 Error        │    │
                                │  └──────────────────┬──────────────────┘    │
                                │                     │                        │
                                │  ┌──────────────────▼──────────────────┐    │
                                │  │ 4. Budget Check                     │    │
                                │  │    - Get current spend from DB      │    │
                                │  │    - Compare to max_budget ($20)    │    │
                                │  │    - If exceeded → 402 Error        │    │
                                │  └──────────────────┬──────────────────┘    │
                                │                     │                        │
                                │  ┌──────────────────▼──────────────────┐    │
                                │  │ 5. Model Access Check               │    │
                                │  │    - User requested: model-balanced │    │
                                │  │    - Key allows: ["model-balanced"] │    │
                                │  │    - If not allowed → 403 Error     │    │
                                │  └──────────────────┬──────────────────┘    │
                                │                     │                        │
                                │                     │ All checks passed!     │
                                └─────────────────────┼────────────────────────┘
                                                      │
                                                      ▼
                                ┌─────────────────────────────────────────────┐
                                │              AWS Bedrock                     │
                                │                                              │
                                │  6. Route to actual model:                   │
                                │     model-balanced →                         │
                                │     bedrock/anthropic.claude-sonnet...       │
                                │                                              │
                                │  7. Get LLM response                         │
                                └──────────────────────┬──────────────────────┘
                                                       │
                                                       ▼
                                ┌─────────────────────────────────────────────┐
                                │              LiteLLM Proxy                   │
                                │                                              │
                                │  8. Calculate cost (tokens × price)          │
                                │  9. Update user spend in PostgreSQL          │
                                │  10. Log request to LiteLLM_SpendLogs        │
                                │  11. Return response to user                 │
                                └─────────────────────────────────────────────┘
```

### 5. Database Tables (Auto-Created by LiteLLM)

LiteLLM automatically creates and manages these tables:

```sql
-- We don't create these - LiteLLM does it on startup!

-- Stores API keys with their limits
CREATE TABLE "LiteLLM_VerificationToken" (
    token VARCHAR PRIMARY KEY,        -- The sk-xxx key (hashed)
    key_name VARCHAR,
    key_alias VARCHAR,
    user_id VARCHAR,
    team_id VARCHAR,
    models TEXT[],                    -- Allowed models array
    max_budget DECIMAL,               -- Monthly budget limit
    spend DECIMAL DEFAULT 0,          -- Current spend
    rpm_limit INTEGER,                -- Requests per minute
    tpm_limit INTEGER,                -- Tokens per minute
    budget_duration VARCHAR,          -- "1mo", "1d", etc.
    expires TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Logs every API call for auditing
CREATE TABLE "LiteLLM_SpendLogs" (
    id SERIAL PRIMARY KEY,
    request_id VARCHAR,
    api_key VARCHAR,                  -- Which key was used
    user_id VARCHAR,
    team_id VARCHAR,
    model VARCHAR,                    -- Which model was called
    spend DECIMAL,                    -- Cost of this request
    total_tokens INTEGER,
    prompt_tokens INTEGER,
    completion_tokens INTEGER,
    startTime TIMESTAMP,
    endTime TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Team configurations
CREATE TABLE "LiteLLM_TeamTable" (
    team_id VARCHAR PRIMARY KEY,
    team_alias VARCHAR,
    models TEXT[],
    max_budget DECIMAL,
    spend DECIMAL DEFAULT 0,
    budget_duration VARCHAR,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### 6. How Budget Tracking Works

```
                    Token Pricing (from Bedrock)
                    ┌────────────────────────────────┐
                    │ Claude Haiku:                  │
                    │   Input:  $0.00025 / 1K tokens │
                    │   Output: $0.00125 / 1K tokens │
                    │                                │
                    │ Claude Sonnet:                 │
                    │   Input:  $0.003 / 1K tokens   │
                    │   Output: $0.015 / 1K tokens   │
                    └────────────────────────────────┘

Request comes in:
┌─────────────────────────────────────────────────────────────┐
│ User: "Explain quantum computing" (15 tokens)               │
│ Model: model-balanced (Sonnet)                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ LLM Response: 500 tokens                                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ LiteLLM calculates cost:                                    │
│                                                             │
│   Input:  15 tokens × $0.003/1K  = $0.000045                │
│   Output: 500 tokens × $0.015/1K = $0.0075                  │
│   Total:                         = $0.007545                │
│                                                             │
│ UPDATE LiteLLM_VerificationToken                            │
│ SET spend = spend + 0.007545                                │
│ WHERE token = 'sk-abc123';                                  │
│                                                             │
│ Before: spend = $5.50                                       │
│ After:  spend = $5.507545                                   │
│                                                             │
│ Budget check: $5.51 < $20.00 ✓ OK                           │
└─────────────────────────────────────────────────────────────┘
```

---

## What Each Component Does

### Our Terraform (Infrastructure)

```
terraform/
├── modules/
│   ├── vpc/          → Network isolation
│   ├── security-groups/ → Firewall rules (who can talk to whom)
│   ├── rds/          → PostgreSQL database (LiteLLM stores data here)
│   ├── ecs/          → Runs LiteLLM container
│   ├── alb/          → Public endpoint (users connect here)
│   └── secrets/      → Stores passwords securely
```

### Our Config (config.yaml)

```yaml
# This file tells LiteLLM:
# 1. What models to expose (model_list)
# 2. Where to store data (database_url)
# 3. How to log (success_callback)
# 4. Connection limits (database_connection_pool_limit)
```

### Our Script (onboard_users.py)

```python
# This script calls LiteLLM's Admin API:
# 1. POST /team/new     → Create Drafting, Coding, Architect teams
# 2. POST /key/generate → Create API keys with limits per user
# 3. GET /key/list      → Show all users
```

---

## API Flow Summary

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           COMPLETE FLOW                                  │
└─────────────────────────────────────────────────────────────────────────┘

1. DEPLOYMENT (One-time)
   terraform apply
        │
        ├── Creates VPC, RDS, ECS, ALB
        ├── Deploys LiteLLM container
        └── LiteLLM auto-creates DB tables on startup

2. USER PROVISIONING (Admin task)
   python onboard_users.py --create-teams
   python onboard_users.py --add-user --email dev@co.com --tier coding
        │
        ├── Calls LiteLLM Admin API
        └── LiteLLM stores keys in PostgreSQL

3. USER MAKES REQUEST (Runtime)
   curl -X POST http://ALB_DNS/v1/chat/completions \
     -H "Authorization: Bearer sk-user-key" \
     -d '{"model": "model-balanced", "messages": [...]}'
        │
        ├── ALB routes to ECS
        ├── LiteLLM validates key (from PostgreSQL)
        ├── LiteLLM checks rate limit
        ├── LiteLLM checks budget
        ├── LiteLLM checks model access
        ├── LiteLLM calls AWS Bedrock
        ├── LiteLLM logs to PostgreSQL
        ├── LiteLLM updates spend
        └── Returns response to user

```

---

## Why This Architecture?

| Decision | Reason |
|----------|--------|
| **Use LiteLLM** | Production-ready proxy, don't reinvent the wheel |
| **PostgreSQL** | LiteLLM's native storage, reliable, queryable |
| **ECS Fargate** | Serverless containers, no EC2 management |
| **Spot Capacity** | 70%+ cost savings for stateless workloads |
| **ALB** | Handle HTTPS, health checks, load balancing |
| **Secrets Manager** | Secure credential storage, auto-rotation ready |

---

## Key Takeaways

1. **LiteLLM is the brain** - It handles API, auth, rate limiting, budgets, logging
2. **PostgreSQL is the memory** - Stores keys, usage, teams, logs
3. **AWS Bedrock is the muscle** - Actual LLM inference
4. **Terraform is the builder** - Creates all AWS infrastructure
5. **onboard_users.py is the admin tool** - Provisions users via LiteLLM API

**We write zero application code** - only configuration and infrastructure!
