# Engineering receipt — Sprints 07C, 08, 10 and stability follow-up

Status: committed to `main`, **source implementation only**. The Roblox Studio project has not been launched or typechecked by this assistant.

## 07C: versioned owned garage
- V2 player profile stores up to 8 cars, selected car ID, inventory and bounded recent operation journal.
- Old V1 profiles are decoded to V2; future/unknown schemas and unknown catalog references are rejected, not overwritten.
- Selected car spawns using its saved engine, transmission and tires, with separate active car instance and driver-only seat permissions.
- One active personal car per account; the selection terminal now reconfigures the same parked, unoccupied prototype chassis in place. Spawning replaces only a missing instance. Distinct vehicle meshes remain a future sprint.
- Up to 12 fixed parking slots per Roblox server. Parking and obstruction still need real Studio playtesting.
- The game keeps the free shared development car **only in an unpublished Studio session**.

## 08: spare parts and vehicles
- Store catalogs with in-game-credit prices; fixed-price new/used part entries.
- PurchaseVehicle, PurchasePart, InstallPart and SelectVehicle use the same validated profile in one DataStore UpdateAsync transform.
- Server generates operation identifiers outside the transaction callback, so callback retries cannot generate new IDs.
- Duplicate operation IDs are rejected within a bounded rolling journal (40 entries). Not a complete commerce-ledger solution; paid Robux receipts are intentionally deferred.
- Only a parked, unoccupied car may be respawned after installing a part. Replaced parts are discarded in this prototype; no trade/resale.
- No client-submitted prices, car IDs for purchases, or credit amounts are trusted.
- The shop is currently physical ProximityPrompt stands, not final UI.

## 10: player-vs-course prototype
- Solo timed race has ordered checkpoints, speed/displacement plausibility tests, minimum segment times and a cooldown.
- Actual server-position measurements determine race completion; client does not submit elapsed time, rewards or checkpoint passes.
- Confirmed finish awards **650 in-game credits** through the same profile transaction service.
- Does not implement NPC opponents, leaderboards, PvP matches, true speed-run anti-cheat, or competitive ranking.

## Network / UX and local sandbox
- Client sends throttle/steer at ~10 Hz while seated. Server verifies actual seat occupant and owned vehicle, clamps input, rate-limits updates and stops acceleration after 0.45s without valid input.
- Vehicle spec recalculates only when parts change; replicated RPM/gear telemetry is throttled.
- Compact status notices and wallet / car-count HUD.
- Unpublished Roblox Studio runs with **temporary, memory-only profiles**, never production DataStore. Studio game reset wipes those profiles.
- Permanent profiles only in published/staging Roblox experiences; those must be tested separately.

## Acceptance checklist — MUST be completed before public release
- [ ] Run `rojo build default.project.json -o StreetCity.rbxlx`; open built place.
- [ ] Run Studio Server & Clients with 2+ clients; drive and change headlights. RemoteEvent handles keyboard and touch.
- [ ] Spawn distinct owned cars for 2 accounts; verify only owner can enter each.
- [ ] Studio sandbox: finish complete time-trial and receive 650 credits; buy and install an approved item.
- [ ] Negative tests: unknown item, insufficient credits, repeated operation ID, duplicate car ID and non-owned seat.
- [ ] Verify no rewards for teleporting to checkpoints, bypassing route, changing cars or disconnecting.
- [ ] Staging published place: test old V1 profile migration, restart, competing sessions, DataStore outage and uncertain UpdateAsync response.
- [ ] Test character rejoin and personal car selection, particularly while another client is near the garage.
- [ ] Profile mobile RAM/FPS and server frame time with 12 occupied cars.
- [ ] Validate that 7 regions are reachable; known generated blockouts and cosmetic-only chassis are unfinished.
- [ ] Test rollback against V2 records; old V1 code cannot safely write newly migrated V2 data.

No CI/GitHub Actions. Not published to Roblox. No Robux payments accepted.
