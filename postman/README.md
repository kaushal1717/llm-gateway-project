# Postman Collection for LLM Gateway

This folder contains Postman collection and environment files for testing the LLM Gateway API.

## Files

| File | Description |
|------|-------------|
| `LLM_Gateway.postman_collection.json` | API collection with all endpoints |
| `LLM_Gateway_Dev.postman_environment.json` | Dev environment with actual values (DO NOT COMMIT) |
| `LLM_Gateway_Template.postman_environment.json` | Template environment for new setups |

## Setup

### 1. Import Collection

1. Open Postman
2. Click **Import** button
3. Select `LLM_Gateway.postman_collection.json`

### 2. Import Environment

1. Click **Import** button
2. Select `LLM_Gateway_Template.postman_environment.json`
3. Go to **Environments** tab
4. Update the values with your actual credentials

### 3. Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `LITELLM_URL` | Gateway URL (ALB endpoint) | `http://llm-gateway-dev-alb-xxx.ap-south-1.elb.amazonaws.com` |
| `MASTER_KEY` | Admin master key | `sk-EgywpHl...` |
| `API_KEY` | User API key for testing | `sk-QsyIUt...` |
| `DRAFTING_TEAM_ID` | Drafting team UUID | `44d83a1b-...` |
| `CODING_TEAM_ID` | Coding team UUID | `d8dcbb3f-...` |
| `ARCHITECT_TEAM_ID` | Architect team UUID | `91296991-...` |

## Collection Structure

```
LLM Gateway API
├── Health & Info
│   ├── Health Check
│   ├── List Models
│   └── Model Info (Detailed)
├── Chat Completions
│   ├── Chat - model-cheap (Nova Micro)
│   ├── Chat - model-balanced (Nova Lite)
│   ├── Chat - model-reasoning (Nova Pro)
│   ├── Chat - With System Message
│   ├── Chat - Streaming
│   └── Chat - With Max Tokens
├── Model Management (Admin)
│   ├── Add Model
│   └── Delete Model
├── Team Management (Admin)
│   ├── List Teams
│   ├── Create Team - Drafting
│   ├── Create Team - Coding
│   ├── Create Team - Architect
│   └── Delete Team
├── Key Management (Admin)
│   ├── List Keys
│   ├── Generate Key
│   ├── Key Info
│   └── Delete Key
├── User & Spend (Admin)
│   ├── User Info
│   ├── Global Spend
│   └── Spend Logs
└── Rate Limit Testing
    └── Rate Limit Test
```

## Usage Tips

### Testing Rate Limits

1. Select the "Rate Limit Test" request
2. Make sure you're using a user API key (not master key)
3. Run the request multiple times quickly
4. The 3rd request within a minute should return a rate limit error

### Admin vs User Requests

- **Admin requests** (Model, Team, Key management): Use `{{MASTER_KEY}}`
- **User requests** (Chat completions): Use `{{API_KEY}}`

The collection is pre-configured with the correct auth for each request.

## Security Note

Never commit the `LLM_Gateway_Dev.postman_environment.json` file with real credentials to version control. It's included in `.gitignore`.
