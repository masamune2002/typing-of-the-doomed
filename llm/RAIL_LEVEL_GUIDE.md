# Creating a RailNetwork level from a WAD map

How to build `wads/doom/levels/<MAP>.tscn` for a DOOM map, using the tooling
built for E1M6 (`gen_e1m6.py`, `wadgeo.py`, `check_route.py`). Read this
whole doc first — every rule in here was learned from a real failure.
`gen_e1m6.py` is the plain template; `gen_e1m7.py` adds the lift patterns
and forced-key-order probing described below.

**E2 update:** the nine `gen_e2m*.py` scripts share `railgen.py` (the
gen_e1m9 expander verbatim + a tscn writer) instead of copying it —
new maps should import railgen too. See "Episode 2 additions" at the
bottom for teleport chain-breaks, boss finales, milestone routes, the
walkover-raise trap, and the capsule-snag class of stalls.

## The pipeline

1. Copy `gen_e1m6.py` → `gen_e1m7.py` (etc.) and edit:
   - `SPAWN_X / SPAWN_Z` — the player start from `llm/<MAP>.md`
   - the map name string in `expand_route()` and `write_tscn()` (`MapGeo("DOOM.WAD", "E1M7")`) and the WadPreview `map_name`
   - the scene `uid` — **keep the uid of the existing stub tscn** if one
     exists (grep the first line of the current file), or generate a new one
   - `PATH_BLOCK` — sectors the router must never enter (see below)
   - `RAW` — the design beats (the actual work; see below)
2. `python3 gen_e1m7.py` — regenerates the tscn. Treat every WARNING as a
   design bug: "no path" and "suspicious detour" mean a beat is somewhere
   you think it isn't.
3. `python3 check_route.py E1M7 gen_e1m7` — must print `0/N hops blocked`.
4. `timeout 15 godot --headless --path . --quit` — zero `SCRIPT ERROR`s.
5. Full runtime proof: `godot --headless --path . -- --map E1M7`
   (autoplay: skip_encounters, skip_doors, god_mode, tracking). Run it in
   the background — a full map takes 10–20 minutes. It self-terminates:
   - `[AUTOPLAY] DONE` → the whole rail works, you are finished
   - `[AUTOPLAY] STALLED at pos=... last_station=... blocker=...` → the
     report includes the rail state machine and a raycast to the blocker.
     Convert the printed local position to dump coordinates with
     `wad = local + (SPAWN_X, SPAWN_Z)`.
6. Iterate 2–5 until DONE, then ask the user to playtest. Headless cannot
   exercise typing-under-fire; the user will find pacing/UX issues.

## Coordinates

- `llm/<MAP>.md` positions are scaled WAD coords: `x = wad_x * 0.03125`,
  `z = -wad_y * 0.03125` (**note the negation** — wadgeo handles it).
- Scene-local station coords = dump coords − spawn. Vertical:
  `y = (floor_raw − spawn_floor_raw) * 0.038` — the generator computes this
  per station via `point_sector`. Never leave stations at y=0 in elevated
  areas: they spawn under the floor slab and their snap-to-floor raycast
  drops them (and their rail paths) into the void below the map.

## Writing RAW (design beats)

- **Only use positions that exist in `llm/<MAP>.md`** (enemies, items,
  keys, weapons). They are guaranteed walkable. Invented "filler" positions
  caused the worst bug of E1M6: a beat inside a walled-off pocket sent A*
  on a legal 200-unit tour through half the map.
- Structural beats you must invent (switch stations, walk-trigger
  crossings, exit station) get verified first:
  `MapGeo.point_sector(p)` → check the sector and its floor height.
- Keep it lean: ~60–80 beats. One sweep per area, minimal backtracking.
  A* + auto-gating fills in everything between beats. Long routes feel like
  "running around in circles" in-game.
- Every beat is a one_shot station; the last station's advance action with
  no next station is what makes autoplay print DONE.

### Find the door order FIRST

Before writing any beats, read the "Triggers & Doors" and "Tags" tables in
`llm/<MAP>.md` and write down the progression. Don't guess the key order —
prove it: build a sector adjacency graph in python (wadgeo linedefs, edge
passable if gap >= 56 and climb <= 24 or either sector is movable) and BFS
from the spawn with each key-door set banned. E1M7's order (yellow -> red
-> blue) is forced by geometry and does not match a naive reading of the
map; ten minutes of BFS beats an hour of stalled autoplay runs. The same
probing finds rooms with exactly one exit (E1M7's red-key room is only
reachable over a lift — that dictated solving lift descents at all).

- which keys exist and where (Keys section)
- which doors need which key (`DR Door <Color> Key ...` rows → door sector)
- which doors are switch-opened (`S1/SR ...` rows: the **switch linedef
  position** is where the player must stand; the tag → target sector is the
  door, often far away)
- which doors/floors are walkover-triggered (`W1/WR ...`): these fire
  automatically when the route crosses the trigger line — wadgeo simulates
  this in route order, but A* cannot *plan* "cross trigger, then door";
  if a trigger must be walked before a barrier elsewhere opens, add an
  explicit beat pair that crosses the trigger line (see the E1M6 tag-14
  arena beats `(-49.5,-43.3) → (-52.0,-43.0)`).

Then order the beats: key → that key's door → next area. E1M6's real order
(red → blue → east switch → yellow) did not match the first guess; expect
to probe.

## Conditions — the exact rules

Conditions are `VariableCondition`s. Shorthands resolve in
`VariableCondition._resolve_shorthand`: `D<n>` → `door_sector_<n>`,
`F<n>` → `floor_sector_<n>`, `L<n>` → `lift_sector_<n>`. In autoplay,
a failing condition auto-activates the matching interactable/item; in real
play the rail waits until the player types/picks up the thing.

1. **Keys: put `key_<key_name>` ON the key's own station**
   (`key_red_keycard`, `key_blue_keycard`, `key_yellow_keycard`). The rail
   physically waits on the key until pickup registers; autoplay force-picks
   it up. Do NOT put the key condition only on a later door-approach
   station — if pickup silently fails the player is stranded far from the
   key.
2. **Switch-opened doors: put `D<target_sector>` on a beat AT THE SWITCH.**
   The player can only type words within ~20 units and line of sight. A
   gate at the remote door leaves the player staring at a closed door with
   nothing to type. The auto-gater will still add a backup gate at the door
   itself; that's fine (the var is already true by then).
3. **Plain manual doors (DR / key DR): don't hand-place anything.**
   `expand_route` detects every closed-manual-door crossing and inserts a
   gate station ~1.5 units before the opening, centered between the jambs.
   (Centering matters: a rail that grazes the door frame physically snags
   the player capsule.)
4. **Trap doors (`W1/WR Close Wait Open`, e.g. E1M6 sector 187): put a
   `D<sector>` station before RE-crossing them.** These close when their
   trigger line is walked and reopen ~30s later. The rail otherwise grinds
   against the door for the whole wait. Pathfinding penalizes crossing
   closer lines, but some maps (E1M6's courtyard) make the trap
   unavoidable.
5. Conditions on stations are checked every frame while the encounter is
   active; the rail advances the moment they pass.
6. **Wide door slabs (>= 0.75 units / 24 map units) need straight flanking
   beats.** The A* grid step is 0.5, so a grid node can land inside a wide
   slab, splitting the transit into extra sub-hops and stranding the
   auto-gate two stations before the crossing (check_route reports
   "ungated door"). Put a beat ~2 units before and after the door on a
   straight line through its center so the whole transit is one hop
   (E1M7 door 39).

## Lifts (WR/SR "Platform Lower Wait Raise")

Riding lifts is the most failure-prone thing a route can do. E1M7 took six
autoplay runs to get right. The rules:

- **Ascent (from the bottom) is naturally stable** and needs no condition:
  a beat pair crossing the WR trigger line (lift lowers), a beat ON the
  lift, then beats on the upper floor. The player waits pressed against
  the shaft until the platform arrives, rides up, walks off. This is the
  E1M6-era pattern and it just works.
- **Descent (from the top) needs two things:**
  1. an `L<sector>` condition beat on the approach, 1.5-3 units before
     the lift edge. Lift variables read true ONLY while the platform is
     physically at the bottom (`Interactable._isDoorOpen` reads the shared
     `curH`), so the rail holds until it is actually safe. In real play
     the player types the lift's word; in autoplay it auto-activates.
  2. the next station AT THE LIFT CENTER — never beyond the exit. If the
     lift has auto-raised again by the time the player arrives (its bottom
     wait is only ~3s and station-end processing can eat all of it), the
     player walks onto the raised top flush and the entry crossing of the
     walkover line re-lowers a settled lift with the player safely
     centered. A station past the exit instead wedges the player against
     the wall above the opening. See the `(-43.46, 2.5)` beat in
     `gen_e1m7.py` (position play-tuned by hand).
- **Never let the route dwell on a lift mid-transit** other than that
  center station: encounter processing outlasts the 3s bottom wait and
  the lift rises mid-encounter with the player aboard.
- **Why descents wedge without this:** sector ceiling slabs have ~1 unit
  of collider thickness and protrude slightly into the lift shaft. A
  player dragged off the top edge at full rail speed (8 u/s) is carried
  ~1.8 units sideways in the first half-unit of fall — straight onto that
  lip, where they stand looking like gravity broke (y frozen just below
  the upper floor). Two framework pieces defuse this: lift conditions
  gate on bottomed platforms (above), and `Player.gd` damps airborne rail
  carry to 15% after 0.15s of airtime (`AIR_CARRY_*` constants) so longer
  falls drop nearly straight.
- **Debugging signature:** stall report with the player's y frozen at the
  raised-lift height (or just below it) while the cursor is at floor
  level beyond the lift = one of the above. Player y exactly at raised
  height -> the lift never lowered or re-raised under them; y frozen a
  fraction below -> they are standing on a ceiling-slab lip.
- Prefer static drops over lift rides when geometry allows: walking off a
  raised deck edge into an open lower sector needs nothing special (E1M7
  yellow-key deck drops into sector 26 instead of re-riding lift 23).

## What the generator/wadgeo already handle (don't re-do by hand)

- A* routing between beats with player-radius clearance, directional steps
  (drops of any height OK, climbs ≤ 24 map units), and a jittered grid so
  nodes never sit exactly on geometry lines
- walkover trigger simulation in route order (`commit_hop` / `opened`)
- auto-gating of manual doors, centered on the crossed line's midpoint
  (works for multi-slab door sectors like E1M6's 28)
- one gate per door transit even when an A* point lands inside the slab
- station heights from sector floors; near-duplicate station dedupe
- penalties: manual door crossing 300, closer-line crossing 120 — A* only
  crosses them when there is no open way around

## PATH_BLOCK and what to skip

- Add to `PATH_BLOCK`: pits you can drop into but never leave (check
  neighbor floor deltas — climbing out needs ≤ 24 raw units), e.g. E1M6's
  blue-armor pit (sector 180).
- Skip secret sectors (listed at the bottom of `llm/<MAP>.md`) unless the
  user asks, remote monster ledges (floor far above neighbors, lowered by
  a distant trigger), and switch-lowered pedestals (e.g. soulsphere on a
  `SR Platform Lower` pedestal) unless you verify the mechanism.
- Enemies flagged `ambush` often stand inside closets that only open on
  some trigger — check `point_sector` + floor before giving them a beat.
  Fight them from outside instead.

## Debugging a stall

The stall report is rich — use all of it:

- `pos` vs `cursor`: cursor far below the player → station under the floor
  (heights bug). Cursor ~1 unit ahead, both frozen, `moving=true` → the
  player is physically pressed against something.
- `blocker=` names the exact StaticBody (sector/linenode) hit by a ray
  toward the cursor. No blocker + frozen → check `alive` (death — god mode
  should prevent it) or a zero-length curve.
- `enc(... condsMet=true)` at a door means a `door_sector_*` variable was
  true while the door was physically shut. That class of bug (trigger
  nodes misread as open doors) is fixed in `Interactable.gd` by reading
  door geometry (`curH`/`bottomH`) instead of state enums — but if it
  recurs, instrument `VariableCondition._try_auto_activate` and
  `door.gd activate()` with prints and read the log.
- A door sector that RESTS AJAR (closed ceiling above its floor, e.g.
  E1M5 sectors 121/122: floor 80 / ceil 88) is a variant of the same
  bug: a naive `curH > bottomH` check reads it as open at level load,
  the var goes true, and the door's Interactable self-hides — so
  autoplay's auto-activate finds nothing (no `[AUTOACT]` line) while
  the rail walks into the slab. `Interactable._isDoorOpen` now requires
  a player-passable gap (~56 raw units, capped by the door's travel).
  To scan a map for such doors: for each sector in `geo.movable`, flag
  `0 < ceil - floor < 56`.
- The mirror image of that bug class: a TYPED activation that does
  nothing. A sector driven by two mover chains (E1M4 hub doors
  10/106/133/138: WR open-stay + WR open-wait-close) shares `curH`, but
  each door node keeps a private state enum that only ever syncs to OPEN
  at the top, never back to CLOSED. After the other chain cycles the
  door shut, the wrapped open-stay node still reports OPEN and its
  `activate()` no-ops — the player types D106 forever while the rail
  pushes into the slab. Fixed in `Interactable._syncStaleDoorState`
  (re-derives state from geometry before `_triggerWadNode` dispatches).
- Useful one-off probes (python3, import wadgeo):
  `geo.point_sector(p)`, `geo.sector_bounds(si)`, `geo.seg_scan(a, b)`,
  `geo.find_path(a, b)`. Dump every RAW beat's sector+floor and eyeball
  the floor jumps — that table exposed most of E1M6's wrong assumptions.

## Runtime facts worth remembering

- Rail speed is `moveSpeed` (8 u/s); the cursor only advances while the
  player is within 1.5 units (`RAIL_MAX_LEAD`) — walls stall the rail
  forever, there is no auto-recovery. That's why every hop must be
  statically clean. The lead check is XZ-ONLY: a player stranded on a
  ledge directly above the path still counts as "close", so the cursor
  happily runs on underneath them — height desyncs must be prevented by
  route design (gates), not expected to self-heal.
- Autoplay = `--map <MAP>` user arg. Stall detector fires after 45s of no
  movement (sized above the 30s door-reopen cycle). Do not re-enable
  superspeed — it bulldozes through geometry that catches real players.
- DR doors close again ~4s after opening: every RE-crossing of one needs
  its own gate (the auto-gater handles this because it re-checks state per
  crossing).
- Enemies never body-block the player (`Enemy._ready` strips collision
  layer 2) — do not add avoidance for them in routes.
- E1M5 predates this tooling (`gen_e1m5.py` is hand-routed); E1M6
  (`gen_e1m6.py`) is the plain template; E1M7 (`gen_e1m7.py`) is the
  template when the route needs lifts or a probed key order.
- If the user hand-moves a generated station in the editor and it fixes a
  stall, bake the new position back into the generator's RAW (regenerating
  otherwise clobbers it) — the tscn is generated output, not a source file.

## Episode 2 additions (learned building E2M1-E2M9)

### Shared generator: railgen.py

Per-map scripts define `MAP/UID/SPAWN_X/SPAWN_Z/PATH_BLOCK/RAW` (+ optional
`FORCE_OPEN`, `GEO_PREP`) and call `railgen.generate(...)`. Keep exposing
`expand_route(raw)` so `check_route.py` can replay the exact route (it also
honors `FORCE_OPEN` and applies `GEO_PREP` to its own geo).

### Probing: probe_map.py

`python3 probe_map.py E2M4` automates the guide's key-order BFS: spawn/key/
exit sectors, key-door sectors per color, teleport edges, and a staged
reachability closure. CAVEATS learned the hard way:
- its `movable ⇒ passable` rule is optimistic: switch-raised pits (E2M2's
  exit pit 1), lowered pedestals and lift rides all read "reachable" when
  they are not. Confirm every probe claim with `geo.find_path` before
  trusting it (wadgeo is the strict model).
- a key-door SECTOR can have a keyless DR face on one side and a key face
  on the other (E2M6's dark-maze door 80): the probe bans the whole sector,
  wrongly hiding the keyless entry. Check both faces' specials.

### Teleports (TeleportPlayerAction chain breaks)

Walkover teleport pads DO NOT move the rail player (no `teleport()` method)
— routes may cross pads freely. When progression NEEDS a teleport, mark the
RAW beat with a 5th element `{"teleport": tag}`: the station ends its rail
chain with a TeleportPlayerAction and the NEXT beat starts a new chain that
must sit EXACTLY on the WAD teleport-destination thing (type 14) — the
player lands inside its trigger area (EncounterPoint body entry, the E1M8
finale pattern). railgen refuses to generate if the teleport beat is not
its chain's last station. E2M1 chains four of these; E2M4 uses one.

### Boss finale maps (E2M8)

Vanilla E2M8 has no exit line — the episode ends on the boss kill. Mark the
last beat `{"finale": max_distance}`: the station waits on
NearbyEnemiesClearedCondition and runs EpisodeFinaleAction (E2 text wall;
prints `[AUTOPLAY] DONE ... (episode finale)` in autoplay).

### Milestone routes are a legitimate ship gate

gen_e1m9.py set the precedent; E2M2/E2M4/E2M5/E2M7 follow it. When the
vanilla endgame runs over crate-top hops after a stair build (E2M2),
teleporter shuttle booths + a moat with no modelable exit (E2M4), a
capsule-wedging shelf (E2M5) or interleaved raised tiers (E2M7), end the
route at a strong verified milestone (keys collected / a key door opened /
an overlook) and document exactly what was skipped in the gen docstring.

### Walkover floor-RAISES are traps, not bridges

wadgeo's WALK_OPENERS treats W1/WR floor raises optimistically. On E2M4's
dark maze, crossing line 287 raises a barrier that WALLS OFF the corridor
for every later pass. `railgen.raise_walkovers_are_traps(geo)` converts
raise-walkovers into high-penalty avoid-lines (and raises CLOSER_PENALTY to
2000 - a mid-route barrier is a hard failure, not a 120-unit trade). After
generating, verify zero trap crossings by scanning the expanded route's
`geo._crossings` against `geo.closer_lines`.

### Built stairs: bake the floors

Stair-build switches (S1/W1 types 7/8) create floors wadgeo cannot see.
Write a `GEO_PREP` that rewrites `geo.sectors[i]` to the post-build heights
(E2M8 `bake_stairs`). The switch's interactable is DOOR-typed (stairs
script), so the condition is `D<target_sector>`, not `F<n>`. Note the
four-faced pillar quirk: a face builds the OPPOSITE side's stairs.

### Multi-sector switches and the deduped variable

One S1 line can open several door sectors (E2M1's tag 16 -> doors 6 AND 9).
The spawned switch interactable dedupes to the LOWEST sector (`sector_6`)
and typing it sets ALL linked door vars. Hand-place the guide-rule-2 beat
with `D<lowest>`; the auto-gate's `D9` at the far slab passes via the
linked vars. Autoplay's auto-activate matches by NAME, so a `D9`-only gate
stalls autoplay even though real play might squeak by.

### Capsule snags: straight legs skip the clearance check

`expand_chain` only A*-routes a hop when the CENTER line has problems, so a
"clean" straight leg gets NO player-radius flank check. Two stall flavors:
- grazing a convex corner (E2M2's crate at (19.5,-127.5), E2M6's chaingun
  nook): add a waypoint beat ~1.5 units clear of the corner.
- a knee-high (+8) riser that wedges the capsule while the stall raycast
  passes OVER it — "no blocker" + frozen at the step line is the signature
  (E2M5 line 590; step-up handles most +8..+24 risers, this one it doesn't).
  If re-centering the crossing doesn't fix it, reroute or end the route
  before it.

### Damage floors

Block only INESCAPABLE pits by default (climb-out > 24 or ringed by more
damage); shallow nukage the vanilla route wades (E2M3 crossings, E2M6's
southeast pool 55) can stay routable — A* prefers dry paths and only wades
when there is no other way. Keep in-pool beats to enter/exit pairs.

## Episode 3 additions (learned building E3M1-E3M9)

- **E3 keys are SKULLS** (`key_blue_skull` etc.), and the game's item table
  had vanilla types 38/39 (red/yellow skull) SWAPPED - fixed in
  DoomGame.gd. If a key station stalls with condsMet=false and no
  [AUTOACT], check the item table's name/key for that thing type first.
- **Rising-floor elevators** (S1 type 18 "Floor Raise to Next Higher" on
  pit walls: both E3M1/E3M9 spawns, E3M7's exit elevator 135): put the
  F<sector> cond ON the station in the pit; the floor rises with the
  player. GEO_PREP-bake the raised height for spawn pits (and capture the
  as-loaded spawn floor first - railgen does this; a baked spawn floor
  otherwise shifts every station height). Do NOT bake elevators ridden
  mid-route (the XZ-only lead check tolerates the height change).
- **Sinking bridges** (W1 type 37 chains, E3M1/E3M9 west bridge): each
  segment lowers to lava as its line is crossed and the far bank ends
  40+ above - the rail cannot outrun them; skip or reroute.
- **A `D<n>` gate can be poisoned by a same-named CLOSE switch**: E3M4's
  door 75 has a DR face plus separate SR open AND close switches, all
  spawning interactables named sector_75. Autoplay's auto-activate used
  to fire the first match (sometimes the close switch: variable set, slab
  shut, rail wedged). VariableCondition now prefers DOOR faces over
  switches; if a map still misbehaves, check which interactables share
  the gate's name.
- **+24 risers wedge ~half the time** (STEP_HEIGHT is 0.9 units = 23.7):
  E3M2's south rim, E3M4's 63-strip. Treat any exactly-24 climb on the
  route as suspect; find a flat or <=16 lane (probe a coordinate grid).
- **point_sector misattributes near diagonal/one-sided line clusters**
  (E3M9's yard read as the far teleport box; E3M3's court read as the
  parapet). When A* produces a "legal" climb that makes no sense, verify
  with a floor-grid probe before trusting either model.
- **Warrens-style reveals** (W1 lowers walls map-wide) work with plain
  walkover sim + an explicit beat pair over the square; remember every
  SR-lift crossing AFTER the reveal needs its own fresh L-cond (they
  re-raise; E3M9 return leg).
