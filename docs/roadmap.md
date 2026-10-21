# Product roadmap — Street City Online

## Release definition
Open world **life simulator**, first release focuses on free exploration + cars + tuning + racing, while future gameplay modules remain possible. A public release is **not** permitted just because code is committed.

## Status
| Sprint | Scope | Status | Release gate |
| --- | --- | --- | --- |
| 00 | Repository, Rojo, Luau boundaries, docs, smoke checks | **Implemented in source** | Studio sync + local build not yet verified |
| 01 | Character spawn, interaction, camera, 2-player session | **Partial prototype** | Studio dual-client + mobile walk |
| 02 | Universal test car and secure headlights | **Partial prototype** | Car handling/collision/replication playtest |
| 03 | Engine RPM, torque curve, gearbox; integration with provisional chassis | **Partial source implementation** | Studio driving/dynamics test, then clutch/differential |
| 04 | Road-graph connectivity math | **Partial source implementation** | Render/connect roads, route testing |
| 05 | Seven district procedural blockouts and connector roads | **Source prototype** | Studio traversal, streaming and visual refinement |
| 06 | Cube 4D creator tool, asset checker and car catalog | Planned | New car accepted only after validation |
| 07 | Profile persistence + guarded test garage | **Partial source implementation** | Studio session-lock tests and personal vehicle spawning |
| 08 | Catalog-backed validated tuning builds | **Domain foundation only** | Server integration, garage UI, used-parts economy |
| 09 | Road graph, nearby traffic and NPC racers | Planned | Bounded perf budget |
| 10 | PvP/PvE race routes, anti-shortcut rewards | Planned | Safe race invitation/settlement |
| 11 | Credits, shop transactions and Robux cosmetics | Planned | No dupes, refund/receipt failure safety |
| 12 | Polish UI/UX on PC and touch, localized strings | Planned | Usable on small Android screens |
| 13 | Persistence failures, remote abuse, admin controls | Planned | Adversarial scenario suite |
| 14 | Streaming, meshes, lights and concurrency optimization | Planned | Device/server profiling targets |
| 15 | Closed player test, accessibility, launch decision | Planned | Product owner approval |

## Key milestone checkpoints
- **A / Technical prototype (00–03):** stand/walk, enter car, drive, headlights, multiplayer + reproducible physics outcomes.
- **B / World showcase (04–06):** connected regions and scenery, repeatable generation, tested asset pipeline.
- **C / Gameplay loop (07–10):** play races, gain credits, tune and save a car, explore with friends.
- **D / Closed beta (11–15):** quality, data protection, reliable purchase processing, playtest metrics.

## Explicit exclusions from first release
Property market, businesses, professions, player-to-player resale, full combat, boats, heavy NPC pedestrians and user-uploaded content. These are not deleted from product vision; they must not destabilize V1.

## Sprint working agreement
Every sprint must document objective, touched modules, schema changes, user-visible flow, negative scenarios and a release checklist. Stop a feature if it introduces silent data loss or exploitable rewards. No mass paid AI generation tests. No production credentials in Git.
