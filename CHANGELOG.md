# Changelog

## [Unreleased] - 2026-02-01

### Changed
- **Rate Limiting**: Switched from RPM (Requests Per Minute) to **Daily Budget Limits**
  - More accurate cost control based on actual spend
  - Better alignment with LLM pricing models
  - Prevents cost spikes while allowing flexible usage patterns

### Updated Tier Limits

| Tier | Old Limit | New Limit |
|------|-----------|-----------|
| Drafting | 2 requests/min | $0.017/day (resets daily) |
| Coding | 3 requests/min | $0.033/day (resets daily) |
| Architect | 5 requests/min | $0.067/day (resets daily) |

### Why Daily Budget Limits?

**Problems with RPM limits:**
- A 10-word request counts the same as a 10,000-word request
- Users could exhaust monthly budget in minutes with large requests
- Doesn't align with actual API costs (which are token-based)

**Problems with TPM limits:**
- TPM = Tokens Per Minute (not per day!)
- 50,000 TPM = 50k tokens/min × 60 mins × 24 hours = 72M tokens/day
- Would blow past budget immediately

**Benefits of daily budget limits:**
- Fair usage based on actual dollar cost
- Automatic reset every 24 hours
- Perfect cost predictability
- Flexible request patterns (any size, anytime)
- Aligns perfectly with how LLM APIs charge

### Daily Budget Calculations

Daily budgets are calculated to stay within monthly caps:
- **Drafting**: $0.50/month ÷ 30 days = $0.017/day
- **Coding**: $1.00/month ÷ 30 days = $0.033/day
- **Architect**: $2.00/month ÷ 30 days = $0.067/day

Budget resets automatically every 24 hours at midnight UTC.

### Migration Guide

**Delete old teams and recreate with new budget structure:**

```bash
# Delete old teams (if they exist)
curl -X POST "$LITELLM_URL/team/delete" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"team_ids": ["drafting-team-uuid", "coding-team-uuid", "architect-team-uuid"]}'
```

Or simply recreate teams with the new limits:

```bash
cd scripts
python onboard_users.py --create-teams
```

### Files Modified

- `config/tiers.yaml` - Updated tier definitions
- `scripts/onboard_users.py` - Updated to use TPM limits
- `README.md` - Updated documentation
- `postman/` - Collection remains compatible (token limits are transparent to API)

