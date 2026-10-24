# Product roadmap — Street City Online

> **Актуализация аудита: 24 октября 2026.** Эта дорожная карта начиналась
> как описание автомобильного прототипа. Сейчас в `main` реализованы
> исходные модули профессий, NPC, преступности, жилья, банков, охраны,
> природного мира и метро. Поэтому ранние пометки «planned» и раздел
> «Explicit exclusions from first release» ниже отражают первоначальный
> замысел, а не текущую фактическую сборку.
>
> **Единый источник статуса коммерческого выпуска:**
> [Commercial whole-game audit](COMMERCIAL_RELEASE_AUDIT_2026-10-24.md).
> Наличие кода, 16 тестовых модулей и Studio runner НЕ означает выполненный
> runtime-прогон. Без реального отчёта Studio, опубликованного staging DataStore,
> проверенной покупки Robux и профилирования Android — **RELEASE HOLD**.
>
> **Путь проверок:** `python3 tools/run_full_acceptance.py` на машине
> с установленными Rojo и Roblox Studio запускает исходные проверки, сборку,
> 16 Suite в движке и два настоящих Studio-клиента. Это лишь *core gate*:
> отдельные staging/платежи/нагрузка также обязательны. Никакого GitHub Actions.
>

## Release definition
Open world **life simulator**, first release focuses on free exploration + cars + tuning + racing, while future gameplay modules remain possible. A public release is **not** permitted just because code is committed.

## Status
| Sprint | Scope | Status | Release gate |
| --- | --- | --- | --- |
| 00 | Repository, Rojo, Luau boundaries, docs, smoke checks | **Implemented in source** | Studio sync + local build not yet verified |
| 01 | Character spawn, interaction, camera, 2-player session | **Partial prototype** | Studio dual-client + mobile walk |
| 02 | Prototype car, headlights, validated 10Hz server vehicle inputs | **Source implemented / not playtested** | Dual-client and mobile input handling |
| 03 | Engine RPM, torque curve, gearbox; integration with provisional chassis | **Partial source implementation** | Studio driving/dynamics test, then clutch/differential |
| 04 | Road-graph connectivity math | **Partial source implementation** | Render/connect roads, route testing |
| 05 | Seven district procedural blockouts and connector roads | **Source prototype** | Studio traversal, streaming and visual refinement |
| 06 | Cube 4D creator tool, asset checker and car catalog | Planned | New car accepted only after validation |
| 07 | Versioned personal garages, selected owned car, safe profile writes | **Source implemented / not playtested** | Dual-server DataStore leases, car lifecycle |
| 08 | Server credit shop, new/used parts, install, garage selection | **Working-source prototype** | Real session purchase tests, improved shop UI |
| 09 | Road graph, nearby traffic and NPC racers | Planned | Bounded perf budget |
| 10 | Server-verified solo time trial and credit reward | **Partial source implementation** | Studio checkpoints, abuse tests; PvP/NPC later |
| 11 | In-game credit transactions and short operation journal | **Partial source implementation** | Receipt handling and Robux cosmetics deferred |
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

## Current cross-cutting blockers (not optional)
- Luau compilation / Rojo build not run in this environment; runtime may contain errors.
- Staging DataStore migration V1->V2, lease contention and crash recovery unverified.
- Vehicle physics remains arcade chassis with cosmetic wheels; true suspension is unfinished.
- Server driving inputs and race waypoints require real two-client/mobile tests.
- Published experience, developer products and Robux payout paths remain unverified.
- Seven districts are placeholders; not production-ready scenic map.
