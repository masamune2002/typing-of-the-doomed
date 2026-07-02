# Creating a RailNetwork level from a WAD map

How to build `wads/doom/levels/<MAP>.tscn` for a DOOM map, using the tooling
built for E1M6 (`gen_e1m6.py`, `wadgeo.py`, `check_route.py`). Read this
whole doc first — every rule in here was learned from a real failure.
`gen_e1m6.py` is the plain template; `gen_e1m7.py` adds the lift patterns
and forced-key-order probing described below.

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
