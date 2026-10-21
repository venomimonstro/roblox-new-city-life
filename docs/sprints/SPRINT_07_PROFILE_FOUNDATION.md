# Sprint 07 — Profile persistence foundation

Implemented:
- Versioned profile schema with bounds and catalog validation; rejects unknown schema revisions and corrupted build references.
- Roblox DataStore UpdateAsync acquisition with session token and expiring lease, 60-second renewal, best-effort release on leaving/closing.
- Fail-closed behavior for unavailable/locked/corrupt user profiles; avoids rewriting corrupt profiles as new.
- Studio unpublished place continues prototype without persistence (logs explicit warning).
- Schema assertions in SmokeTests.

NOT implemented or certified:
- Garage test presets are still shared and ephemeral; no player-owned car linked to the profile.
- No property/shop/transactional economy, purchase confirmations or vehicle save UI.
- Roblox Studio/DataStore live access, simulated disconnect, cross-server lease race, shutdown failures and API throttling tests have NOT been run.
- Lease and save logic must be reviewed for production: a successful confirmation after every economic mutation, safe idempotency and bounded retry/backoff are mandatory before enabling currency.

Manual acceptance required:
1. Publish a private Studio test place and enable API access only for dedicated test data.
2. Fresh profile load, reconnect and schema validation.
3. Open two server sessions for same account; second must not acquire a live lease.
4. Disable API / simulate errors: no blank profile overwrite.
5. Test timeout/restart and competing lease recovery.
6. Verify game still loads in unpublished Baseplate Studio with persistence explicitly disabled.

Do not advertise commercial-ready persistence or enable real purchases on this code.
