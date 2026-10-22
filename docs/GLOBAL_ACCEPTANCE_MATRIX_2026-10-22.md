# STREET CITY ONLINE — global acceptance contract and failure catalogue

Audit baseline: main as of 2026-10-22. This checklist is a **release specification**, not a statement that all tests passed.

## Release rule
A sprint is DONE only when source implementation, static checks, executable Luau tests, Studio gameplay, negative cases, client UX, cross-server DataStore and performance are all PASS where applicable. Any unexecuted mandatory stage is BLOCKED, not PASS.

## System and sprint matrix

| Sprint | Domain | Positive contracts | Negative / malicious cases | Mandatory acceptance |
|---|---|---|---|---|
| 00-02 | Bootstrap, player, input | join/quit/rejoin, 2 players, GUI, safe remotes | nil character, character removed mid-callback, malicious remote flood | Studio 2+ clients |
| 03-05 | Vehicle physics and world | walk full grid, low/high speed drive, bridge, slope, tunnel, checkpoint | terrain void, thin-part tunneling, 180-degree rollover, enter car midair, car falls to Y<-40, car launched to space | Studio physics + profiler |
| 06 | Assets and map detail | mesh LOD, 7 districts, occlusion, no duplicated colliders | bad mesh pivot, 200MB avatar/client, misplaced model, no streaming child | Studio device testing |
| 07 | Home and garage | different home on same server, own spawn, owned car recall | two players same slot, no slots, car abandoned, destroyed, respawn inside home, garaged car teleported to roof | Studio multi-client |
| 08 | Shop and tuning | buy car, exact part selection, install, reload | insufficient credits, duplicate operation, capacity, simultaneous UpdateAsync, disconnect before receipt | published staging datastore |
| 09 | NPC pedestrians and traffic | traffic lights, cars move on road, residents react | vehicle-pedestrian collision, traffic spawn overlap, stolen police car, lane blockage, NPC pileup | Studio 8+ NPC cars |
| 10 | Races | start automatically in owned vehicle, checkpoints, award once | teleport between checks, jump off cliff, reset car, reconnect on payout, 2 simultaneous races | real multiplayer tests |
| 11 | Economy and bank | cash, bank, home safe, goods, salaries, rent | negative values, huge credits, double payment, bank branch closed, same receipt claimed twice | 2-server staging |
| 12 | UX and mobile | phone drive, aim/weapon, waypoints, mission UI | small screen, rotation, dropped FPS, focus, keyboard/gamepad conflict | low-end Android |
| 13 | Safety and persistence | owner auth, profile V1-4 migrate, session lease, decline invalid state | timeout-after-commit, ownership stolen, crash on shutdown, corrupt record, DataStore budget | real staged DataStore |
| 14 | Streaming/load | world terrain, spawn home, NPC LOD, 30Hz vehicle checks | travel 300 studs/s, fast teleport, chunk unloaded, 30 vehicles, leaks on despawn | MicroProfiler + devices |
| 15 | Launch/cross-server | session matchmaking, moderation, private QA | malicious strangers, repeated exploit input, exploit wallet, purchases real-money receipts | closed live launch |
| 16 | Damage and rescue | scratch, crash, 0 health, free owned replacement, medical bills | fall from cliff, air crash, false high-speed impacts, reset at speed, explosion loops | Studio collision scenarios |
| 17 | Police, jail, emergency | crime report, wanted, dispatcher, patrol, arrest, sentence, escape and ambulance | false report, police stuck, jail camping, free bounty exploit, death during arrest | mostly NOT BUILT |
| 18 | Combat | item equip, range, server hit, NPC vs player, vehicle armour, raycast | walls, friendly fire, aim spoof, rate-limit, lag compensation, headshots and damage caps | server hitscan prototype |
| 19 | Social city | crews, district evolution, tenancy, security investment, residents | crew grief, district ownership race, bankruptcy, wrong player's title, cross-server divergence | partial; NOT GLOBAL |
| 20 | Jobs/nature | 21 shifts, fishing, sports, wildlife, food | two shifts, afk wage, unload stop, repeat fish sale, athlete dies, missing path | Studio + economy regression |
| 21 | Monetization | Robux optional, paid credits claim exactly once, refund policy | repeat receipt, charge but crash, P2W revive lock, refund economy abuse | not confirmed; keep disabled |

## Fatal high-priority end-to-end traces

### Walk and drive everywhere
1. Walk or sprint across each district's east/west/north/south boundary; jump repeatedly at every terrain/road seam. **Never** stand on unloaded collision, fall through terrain or spawn under an obstacle.
2. Drive every block at 10/40/90/145 studs/s with 1–8 occupants near NPC and corners. At each transition, collision remains stable; underflow rescue is a *fallback*, not an excuse for broken ground.
3. Drive over hills, down slopes, off ramps and into obstacles. Small impacts should not destroy the car. Hard grounded impacts should reduce health deterministically. Free fall alone should not damage until impact.
4. Use exploit-style velocities, NaN/Infinity inputs, racing while seated in stolen car, car switch during movement, seat-stealing and NPC car destruction. Server must reject/recover without minting rewards.
5. Drive 30 min at night, in rain, with streaming and AI traffic. Check all physics budgets, memory, client pop-in and FPS.

### Vehicle condition acceptance
- 100–56 HP: operational, cosmetic damage potential
- 55–21 HP: damaged; degraded drive
- 20–1 HP: critical; low power, should offer repair/tow
- 0 HP: wrecked; engine force must be zero; personal owned vehicle remains purchasable/recallable, street car may despawn with delayed safe replacement
- Explosion: **currently NOT implemented**; never claim it is, and do not make high-speed collision automatically fatal until tested
- For the first crash rules implementation, server observes speed discontinuity and limits hit effects; it does **not** prove contact with a solid collider and may misclassify sharp changes. Fix before production.
- No evidence that true independent wheel suspension or tire destruction is done. Keep feature statuses honest.

### Weapons and firefights
1. Tool load and on-foot use, cooldown, range, line of sight, eligible player vs NPC; clients cannot choose damage, star count, victim or awarded currency.
2. Walls and opaque cover block raycast. Dynamic parts, decals and transparent decorations must not block incorrectly. Friendly fire, safe zones, assists, PvP consent and anti-spawn-camping require product decisions.
3. Bullet object speed, weapon dispersion, magazine/reload, ammo inventory, limb hitboxes, armour, body/vehicle material penetration and vehicle-specific damage are **NOT fully implemented**.
4. Explosive/vehicle-fire and NPC death effects are **NOT complete**; avoid launching persistent PvP bounties before anti-collusion and damage attribution pass.

### Crimes, NPC dispatch and prison
Proposed state machine:
`incident -> report -> severity/location -> local responder allocation -> travel with safe nav -> de-escalation or arrest -> handcuffs/custody -> jail timer -> release at police station`.
Negative flows: no route, responder killed, player disconnects in custody, player dies under arrest, suspect steals police car, unrelated bystander hit, dispatcher spam. For escape: secure jail trigger with authorisation, objective route and heightened wanted status; player cannot bypass the sentence by character Reset or server hopping. **Not presently a complete state machine.**

### Economy as double-entry invariants
- Real purchased property/vehicle is a persistent entitlement, not lost by deleting its current world model.
- Bank/home/wallet transfers preserve total value exactly; robbery is a separate, server-authorized debit and credit or destruction event.
- Bounty, rewards, salaries and rents have stable IDs created outside UpdateAsync transforms. Timeout-after-commit -> show uncertain and reconcile; never unconditionally retry with a new ID.
- Server-to-server reservation leases must reject dual owners. Test budget throttling, shutdown while writing, and corrupted profile fail-closed recovery.
- Robux developer products require `MarketplaceService.ProcessReceipt` and durable per-purchase receipt idempotency, not 40-item rolling history. Do not promise or enable unless proven.
- Being poor never forces Robux payment for respawn. Free public clinic leaves debt rather than blocking play.

## Non-happy-path dependency explosion matrix
Run pairwise instead of naïve combinatorial thousands:
- actor: solo player / 2 rivals / bounty hunter / group member / NPC / moderator
- avatar: alive / low health / dead / jailed / seated / falling / respawning
- car: owned / stolen / public NPC / police / wrecked / airborne / unloaded
- network: 20ms / 200ms / 800ms / 10% packet loss / reconnect / server shutdown
- state: loaded / update pending / lease contested / invalid data / 40-op history full
- cash: zero / exact price / max balance / medical debt / bank closed / safe balance
- location: home / downtown / boundary / hill / sea / streamed-out / building interior
- session: fresh / longtime / server transfer / hot update
For every pair test server invariant, visual response and recovery, not just a string match.

## Release gates
P0 fail: data loss, real-money error, duplicate credits, exploited RemoteEvent, under-map death during ordinary traversal, stuck home spawn, global ownership inconsistency, illegitimate wanted payout, perpetual respawn loop.
P1 fail: game-breaking NPC blockade, career impossible to finish, inaccessible home or business, mobile controls non-functional, major 30fps drop, player trapped in jail without time expiry.
P2: cosmetic pop-in, minor VFX, rare NPC turn stalls, balance changes.

## Evidence / honest status
- Files were fetched and code reviewed directly from current main.
- DamageRules and its Studio-only tests added; actual Studio runtime and Rojo build were **not performed** in this assistant runtime.
- This matrix is the acceptance backlog for the thousands of scenarios requested. No claim of comprehensive execution or commercial launch readiness.
