# Part 8 — Premium + Play Billing (COMPLETE)

## Limits (enforced)
| Tier | Docs | Pages/doc |
|------|------|-----------|
| Free | 5 | 15 |
| Pro ($2.75/mo) | unlimited | 150 |
| Elite ($5.75/mo) | unlimited | unlimited |

## Play Console product IDs
- `pro_monthly`
- `elite_monthly`

## App behavior
- Tries Google Play Billing first
- On success → local tier + profiles.is_premium
- Sideload: offers **Test unlock** only (not a real payment)
- Restore purchases supported via BillingService.restore()

## Not yet
- Live money requires app on Play + products active + license testers
