# Living City — Social Economy and Districts

Implemented in main (source-level): Seven districts with safety, prosperity, bank trust, NPC departures, property index and law/outlaw influence; five-star crime reporting; faction and player crew HQs, requested/approved crew membership, guards, hired associates and seven contestable turf points; property purchasing, city resale, rents and civic sponsorship; insured and local bank branches with risk-dependent suspension; flora, wildlife and non-graphic hunting/fishing; cash, separate savings and faction HUD.

Profile V4 migrations preserve V1–V3 players and reconcile both development branches (allegiance/realEstate and communityBankCredits/ownedProperties). Core financial updates are server-side via DataStore.UpdateAsync and bounded transaction IDs.

Engineering fixes: V4 constructor no longer reads nonexistent raw; only one SpendCredits implementation; NPC population subscriptions deduplicated; turf markers placed clear of building collision; role and crew memberships checked; server startup and Studio simulation checks expanded.

Scope limits: District crime/property influence and gangs are server-session local, not cross-server persistent. Deeds are personal instanced developments; direct player-to-player deed trading and global turf ownership are not available. Insolvent banks may suspend new services but cannot destroy stored deposits. NPC guard combat, legal proceedings, real property markets, sophisticated wildlife and AAA city systems are future work. No Roblox Studio or Rojo runtime tests performed here.

Before a public release: run `python3 tools/release_gate.py`, build a Rojo place, check Luau errors, run every Studio suite (SmokeTests, ScenarioTests, SimulationTests, CityLifeTests, DistrictEconomyTests and SocialSystemsTests), test multiple live clients, mobility, DataStore V1–V4 migration, simultaneous server saves and low-end Android memory. Add global atomic registries for inter-server territory/factions and player-to-player property sale before claiming those features work.
