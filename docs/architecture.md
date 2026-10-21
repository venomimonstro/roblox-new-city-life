# Street City Online — architecture (ADR-001)

## Goal
Create a modular Roblox **open-world life-simulator platform**. Driving is the first vertical slice, not the final genre boundary. Future property, social, job, business, and other gameplay loops must reuse player identity, interaction, ownership and economy primitives.

## Boundaries
- Roblox Studio / Luau / Rojo. One Roblox place initially, multiple server instances managed by Roblox.
- \`ReplicatedStorage.Shared\`: configuration, data contracts and **pure** functions safe for client and server.
- \`ServerScriptService.Server\`: server-authoritative world/game rules, validation and ownership.
- \`StarterPlayerScripts.Client\`: presentation, responsive controls and UI.
- No custom database, web API, backend cluster, paid 3D service or production publishing in Sprint 00–02.
- Scripts do not live inside arbitrary downloaded Marketplace models.

## Current implemented slice
\`bootstrap.server.luau\` creates a deterministic **temporary** world and then starts \`VehicleService\`.
\`WorldService\` builds one small city grid, a coarse coast and hills as blocking geometry. It is NOT the planned seven-district production map.
\`VehicleFactory\` builds one provisional open-top coupe entirely from Roblox parts; wheels are cosmetic, chassis physics is intentionally **arcade-level**. Cube 4D integration, wheel constraints, transmission tuning, shops and persistence do not exist yet.
\`VehicleService\` samples VehicleSeat input, applies server-side force and yaw, validates headlight toggling by occupant and rate limits that event. This physics must be validated with 2 clients and mobile touch controls before scaling.
\`bootstrap.client.luau\` renders speed in km/h and exposes a mobile/keyboard headlight action.

## Planned stable services
- \`PlayerService\`: identity and session lifecycle, not arbitrary client input.
- \`ProfileService\`: DataStore UpdateAsync, session coordination, schema migrations, explicit degraded-mode handling.
- \`InteractionService\`: common interaction declarations; ownership and distance rechecked server-side.
- \`VehicleService\` and \`TuningService\`: catalog-driven bodies/chassis/parts, deterministic vehicle math, safe server checks.
- \`EconomyService\` and \`InventoryService\`: serialize changes per profile; purchase transaction must atomically debit and grant.
- \`RaceService\`: checkpoints/time validation and idempotent rewards.
- \`WorldService\`, \`TrafficService\`, \`ActivityService\`: world, AI traffic, and extensible non-driving activities.

Do not implement future services as empty placeholder shells. Add them when there is a real use case with types, tests, and a migration story.

## Trust / networking
1. A player can request an action; the server decides whether it is allowed.
2. Inventory, credits, race results, vehicle ownership, paid receipts and progression are never client-authoritative.
3. Every RemoteEvent has server-side type/range/access validation, a rate limit and a bounded payload.
4. VehicleSeat input is only used for a provisional locally replicated driving prototype; high-stakes races require independent movement plausibility checking and network ownership design.
5. Store persistent profile state via a single serialized transaction owner; retain idempotency keys for awards/purchases.
6. Never save every physics frame. Never generate models per-player at runtime.

## Content pipeline (later)
Authored/approved source -> Roblox Cube 4D or module assembly -> validate mesh budget and scripts -> attach universal chassis -> staged 2-client drive test -> publish catalog asset.
Assets receive a stable catalog ID and version. References and licenses must be tracked; new 3D assets are not trusted executable code.

## Versioning & releases
\`main\` is the sole code branch unless the owner changes policy; **no GitHub Actions**. Manual local checks -> Staging Roblox experience -> human acceptance -> Production publish. Keep a rollback-capable backup of place files. Code rollback and player-profile migration rollback are different problems.
