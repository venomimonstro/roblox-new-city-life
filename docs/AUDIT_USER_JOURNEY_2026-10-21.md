# Street City Online — player-journey audit and regression receipt

Date: 2026-10-21. Branch: `main`. No CI or GitHub Actions.

## Verified in source and corrected this pass

| Player stage | Earlier failure / usability gap | Source correction | Studio acceptance |
|---|---|---|---|
| Join | Start location was not paired with guidance to the distant personal parking row | Player HUD now explains next action; turquoise FindMyCarTerminal is near PlayerSpawn | Spawn two fresh players; both can find their own car |
| Find own car | Walking ~180 studs without direction, potential teleport to unsafe position | Owner-checked prompt, cooldown, seating/stationary guard and downward raycast to walkable ground; missing car can respawn | Reach each owner's car; reject nonowner/moving/occupied and ledge cases |
| Drive | Personal chassis entered across east-west road before earlier fix | Explicit 90-degree spawn heading and factory smoke assertion | Keyboard + touch driving with latency |
| Solo time trial | Unclear route, competing settlement attempts | In-order CPs, server-only progress and reward; fixed marker set and safe settlement lock | Complete route, attempt shortcuts, verify 650 in-game credits |
| Buy parts | Multiple bought SKUs auto-selected the first during installation | Five individually labeled installation stands; no arbitrary client item arguments | Buy two tire choices; install precisely the one selected |
| Buy car | Starter and paid coupe looked identical in prototype | Catalog ID + distinct starter/coupe/sedan paint and prompt labels; current chassis geometry unchanged | Buy a coupe, select it, verify visible identity and different saved tuning |
| Test expensive purchase | QA needed ~19 races to afford 12,000-credit coupe | +25,000 memory-only dev credits stand guarded by Studio && GameId == 0 | Grant while unpublished; prove it is absent in published staging |
| Logout/rejoin | Account cannot rely on old cached vehicle or wallet | Existing V2 DataStore schema, ownership-guarded lease and garage reload, with confirmed persistence-only mutations | Two servers, new login, outage, lease takeover, V1 migration |

## Tests completed during this response

- **27/27 GitHub source integration invariant checks** passed (actual fetched production source at the time checked).
- **16/16 offline Python state-machine tests** passed upon rerun, 0 failures/errors. Models leases, purchases, duplicate operations, garage state, two users, parking and course geometry.
- Studio-only Luau `SmokeTests`, `ScenarioTests` and `SimulationTests` remain connected to bootstrap, and now cover explicit installation stands, safe car locator and appearance switching. **These Luau tests have not been executed by this assistant.**

## Next mandatory manual Roblox Studio run (test account, no actual purchases)

1. `python3 tools/validate_project.py`; `rojo build default.project.json -o StreetCity.rbxlx` and open it in Studio. Check all Luau diagnostics and server output.
2. Unpublished local Baseplate, press Play: look for visible `PlayerSpawn`, turquoise `FindMyCarTerminal`, HUD guide, owned starter and `PASS` messages from all three Studio suites.
3. Walk to turquoise terminal, press prompted key/button; verify character arrives on the street, close to their parked starter. Try while moving and while seated; no unsafe relocation.
4. Enter driver's seat, drive with keyboard, Xbox and Android touch. Headlights work, input ceases after exit/connection loss; another account cannot drive your owned car.
5. Reach green `TimeTrialStart`, drive checkpoint sequence. Receive precisely 650 credits for a legitimate run; no reward on shortcut, character death, car switch or forced teleport.
6. For faster purchases **only in unpublished Studio**, use the labeled debug credit stand. Observe its absence in published staging. Buy a street coupe, select it at the blue garage stand. Model color and `VehicleCatalogId` update.
7. Buy two different parts, choose one specific `Install <SKU>` stand. Verify exactly one inventory item is consumed and only that part changes; no second deduction/reward on duplicate operations.
8. Leave and rejoin **published private staging**: restore vehicle, installed parts and wallet. Simulate DataStore outage/timeout, cross-server session contention and player leave during saving.
9. Measure memory/FPS/frame spikes at 2, 8 and target-max active cars on low-end Android; profile 30Hz vehicle force update and world streaming.

## Known blockers / residual risks

- **No Studio/Rojo compilation or live DataStore integration run performed here.** The 27 static checks are not Luau execution, and the Python suite mirrors domain rules rather than interpreting Luau.
- All three model variants still use one placeholder vehicle chassis and cosmetic wheels. True independent suspension, vehicle geometry and camera/mobile UX need separate playtesting and implementation.
- Personal parking is capped at 48 spots with no physical occupancy sweep. The finder rejects unsafe terrain but is not a universal obstacle-free path planner.
- Credit transaction history is bounded; **not** a purchase-receipt journal for Robux. Do not enable real-money purchasing or public multiplayer commercialization from this report alone.
- Race movement verification is a heuristic, not a complete production-grade anti-cheat.
- Seven-district city visuals, NPC traffic and complete mobile accessibility are incomplete.

**Release decision: HOLD — playable source prototype still requires Studio acceptance.**
