# Project Context: Enterprise LLM Gateway (MVP)

## 1. Mission Statement

Build a cost-efficient, secure Generative AI Gateway on AWS to centralize API access for 100 users. The system must enforce strict monthly budgets and role-based model access using AWS Bedrock as the sole provider.

## 2. Technical Stack

- **Proxy Software:** LiteLLM (Python/Docker).
- **Cloud Provider:** AWS (Region: ap-south-1).
- **IaC:** Terraform (Modular architecture).
- **Compute:** AWS ECS Fargate (Spot Capacity preferred for cost).
- **Database:** AWS RDS PostgreSQL (db.t4g.micro).
- **Secrets:** AWS Secrets Manager.

## 3. User Governance Tiers

The application must enforce these exact tiers via Virtual Keys:

| **Tier Name** | **Budget (Monthly)** | **Rate Limit** | **Allowed Models (Logical)** |
| :-----------: | :------------------: | :------------: | :--------------------------: |
| **Drafting**  |        $2.00         |     10 RPM     |         model-cheap          |
|  **Coding**   |        $20.00        |     50 RPM     |        model-balanced        |
| **Architect** |       $500.00        |    100 RPM     |       model-reasoning        |

## 4. Model Mapping (AWS Bedrock)

Map the logical aliases above to these physical AWS Bedrock IDs:

- model-cheap -> anthropic.claude-4-5-haiku-20241022-v1:0
- model-balanced -> us.anthropic.claude-4-5-sonnet-20241022-v2:0 (Use Cross-Region Inference)
- model-reasoning -> us.deepseek.r1-v1:0 (DeepSeek R1 on Bedrock) OR anthropic.claude-opus-4-5-20251101-v1:0

## 5. Critical Operational Constraints

1. **Database Fragility:** We are using a db.t4g.micro instance. It has very limited connection slots (~80). - **Requirement:** The LiteLLM configuration must set `database_connection_pool_limit` to 5 to prevent crashing the DB during auto-scaling.
2. **Statelessness:** The container must not store local state. All config is environment variables; all state is in RDS.
3. **Security:** No hardcoded secrets in `config.yaml`. Use `os.environ`.

## 6. AI Persona

Act as a Senior DevSecOps Engineer. Prioritize valid Terraform syntax, security group isolation, and robust error handling.
