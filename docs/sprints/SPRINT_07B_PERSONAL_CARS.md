# Sprint 07B — Owned starter car spawning (source implementation)

Implemented: a player receives at most one active personal prototype car after ProfileService has loaded and validated the profile. The spawned car takes engine, gearbox and tire IDs from the saved starter configuration. A player cannot enter another owner's car through the proximity prompt; headlights are driver/owner-checked. PlayerRemoving despawns the car, and transient physics/gear state is dropped.

Cautions: this prototype does not offer multiple owned cars, parking/respawning/repositioning, garage menu, physical suspension or automatic updates of the live personal car after garage mutations. The old shared test car is still present. In unpublished Studio, personal spawning is disabled because persistence is disabled. One player-spawn slot is chosen from ten provisional slots; spatial collisions across larger servers are possible and must be tested.

Critical acceptance: staging DataStore API access, profile rejoin restoration, two-user isolation, rapid join/leave, initial spawn before/after profile load, and seat ownership/collisions. None are confirmed by a live Roblox test yet. Keep production unpublished.
