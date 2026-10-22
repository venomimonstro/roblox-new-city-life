# Public transit and living city NPCs — source implementation receipt

Updated: 2026-10-22. Branch: main. No GitHub Actions or CI.

## Implemented in current Luau source

- Three-station metro at Old Town, Central and Uptown. Physically modelled platform, track bed, walls, underground tunnel and animated light-weight carriage below the surface. Each station has a street entrance, access to its underground platform, a ticketed journey to the next platform and a separate street exit. Fixed in-game fare: 40 credits.
- Five bus stops at Harbor, West City, Central, East City and Coast, with server-controlled 25-credit transfers to the next stop and an animated display bus. Both transfer systems validate actual player proximity, ProfileService availability, wallet debit and a walkable arrival floor. Player does not choose arbitrary coordinates or fares over RemoteEvents.
- NPC drivers have an occupation, mood, current duty and trip count attached to traffic vehicle models.
- 28 neighborhood residents keep lightweight server-side daily lives: employment and job changes, feelings, friendships, dating and marriage, stylized disagreements, occasional drinking, occasional abstract passing away / new arrival, shopping and commuting. State advances once every 12 seconds.
- Nearby players can use the new Talk prompt to discover a resident's work, mood, relationship status and most recent activity.
- Nearby-only physical NPC walking and social encounter display. Distant residents still advance their abstract lives but do not run individual movement/pathfinding steps; visible driver traffic continues as a fixed bounded pool.
- StartupContract refuses to mark the server ready when metro and bus station structures or prompts are absent. Studio-only TransitAndNpcTests validates stop counts, station/platform continuity, model presence and pure bounded NPC state transitions.
- Source check validates 14 relevant module wiring, action, performance and regression invariants as of this commit.

## Limits — not a finished physically simulated GTA subway

The train and bus are lightweight animated visual models. A passenger's trip is currently a server-validated **scheduled station transfer** with a wait, not actual physics-based seating/attachment in the moving carriage or vehicle. The metro interior is separate underground geometry and is reachable from the surface via prompts, not physical walkable stairs. Subway exits do not yet have detailed station halls, tactile route maps or crowds.

NPC social lives are deterministic state machines, not language-model agents. Weddings, romance, drinking, conflict, death and employment are represented by life state changes / attributes and nearby pauses or UI inspection; there are no bespoke cinematic scenes, conversational dialogue trees, Humanoid walking pathfinding, dynamic family homes or full-time persistence across servers. The 28 citizens are pre-existing stylized models. NPC transit ridership is modelled as passenger counts, not individuals with live seats.

## Performance approach

- 28 social agents each update every 12 seconds with a fixed bounded transition function.
- Detailed social attributes are evaluated near real players within 165 studs.
- Citizen walking only updates near players (existing 4 Hz walking loop), while offscreen residents use abstract state only.
- Tram/train/bus displays use at most 10 animated pivot updates per second and no expensive passenger physics.
- Existing world traffic continues with its own capped server update (~5 Hz), fixed maximum count and recoverable vehicle slots.
- No Robux operations and no paid AI inference are invoked by these features.

## Required acceptance before launch

1. Run `python3 tools/release_gate.py` in a full checkout with Rojo installed and fix any Luau compile errors in Roblox Studio.
2. Run the Studio `TransitAndNpcTests` suite and manually enter the underground tunnel from all three entrances.
3. Travel each direction via station transfers, validate safe spawn locations, correct fare debiting and reconnection handling; try dying in transit, wrong-station prompts, quick repeated prompt use, and leaving the server during purchase.
4. 2–4 clients: follow an NPC walking, speak with one, examine relationships and job changes in long-lived sessions; follow a driver to verify route and obstacle handling.
5. Profile server memory, update traffic and social systems at target population and on weak phones, especially when lots of players follow different residents at once.
6. Expand staged NPC life into persistent records, crowd animation and safe long-distance routes only after actual engine profiling.

Release readiness: **not verified**; source integration passed, gameplay/physics/Roblox Studio tests have not been executed here.
