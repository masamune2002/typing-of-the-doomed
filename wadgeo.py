#!/usr/bin/env python3
"""WAD level geometry for rail-route tooling.

Parses one map from a WAD and answers walkability questions in the scaled
scene space (x, z) with z = -wad_y * SCALE (the llm/*.md convention).

Movable sectors (doors/lifts/floors) are modeled with route-order state:
  - walkover-triggered sectors (W1/WR openers) become passable only after
    the route crosses one of their trigger lines (geo.commit_hop tracks this)
  - manually-triggered doors (DR / switch types) are passable but reported
    as gates so the caller can insert a typed-door condition station
  - "open stay" doors stay open once gated; DR doors re-gate every crossing

Main API:
  seg_scan(a, b)  -> (problems, gates) for a directed straight hop
  seg_walk(a, b)  -> (walkable, n_gates) incl. player-radius clearance
  find_path(a, b) -> simplified waypoint list using A* over a fine grid
  commit_hop(a,b) -> record walkover triggers the route just crossed
  point_sector(p), sector_bounds(si), player_start()
"""
import struct
import heapq

SCALE = 0.03125          # WAD xz -> scene units (the addon scaleFactor)
MAX_STEP = 24            # DOOM max step-up in raw map units
MIN_GAP = 56             # min ceiling-floor gap the player fits through
PLAYER_RADIUS = 0.45     # scaled units (~14 map units) clearance for pathing
GRID = 0.5               # A* grid step in scaled units
BUCKET = 4.0             # spatial hash bucket size in scaled units
ML_BLOCKING = 0x0001

# Walkover (W1/WR) specials that put their target sector into a passable
# state (doors opening, platforms lowering, floors moving to a level the
# route can use - optimistic for raises, which DOOM maps use as bridges).
WALK_OPENERS = {2, 4, 10, 22, 36, 37, 38, 53, 56, 58, 59, 82, 83, 84, 86,
                87, 88, 90, 92, 93, 94, 95, 96, 98, 105, 106, 108, 109,
                119, 120, 121, 128, 129, 130}
# Walkover specials that CLOSE their target sector: crossing one of these
# lines mid-route slams a door shut (possibly right in the player's face,
# e.g. E1M6's two-slab courtyard trap, sector 187). Pathfinding penalizes
# crossing them so routes avoid the trigger when an open way exists.
WALK_CLOSERS = {3, 16, 75, 76, 110}
# Manual door specials: DR (push) and S1/SR (switch) types that open the
# door sector. These become rail conditions (D<sector>).
MANUAL_DOORS = {1, 26, 27, 28, 31, 32, 33, 34, 117, 118,      # DR / D1
                29, 61, 63, 103, 111, 112, 113, 114, 133, 135, 137}
# Manual types whose door stays open permanently after one activation.
OPEN_STAY = {2, 31, 61, 86, 103, 106, 109, 112, 133, 135, 137}
DOOR_LIKE_SPECIALS = WALK_OPENERS | MANUAL_DOORS | {3, 16, 42, 50, 75, 76,
                                                    107, 110, 62, 21, 123,
                                                    122, 66, 67, 68, 45, 60,
                                                    64, 65, 69, 70, 71, 102,
                                                    131, 140, 5, 14, 15, 20,
                                                    23, 24, 30, 78}


class MapGeo:
    def __init__(self, wad_path, map_name):
        with open(wad_path, "rb") as f:
            data = f.read()
        _, numlumps, dirofs = struct.unpack_from("<4sII", data, 0)
        lumps = []
        for i in range(numlumps):
            ofs, size, name = struct.unpack_from("<II8s", data, dirofs + 16 * i)
            lumps.append((name.rstrip(b"\0").decode("ascii", "ignore"), ofs, size))
        idx = next(i for i, (n, _, _) in enumerate(lumps) if n == map_name)
        raw = {}
        for n, ofs, size in lumps[idx + 1: idx + 11]:
            raw[n] = data[ofs: ofs + size]

        # Vertices in scaled scene space (z negated)
        self.verts = [(x * SCALE, -y * SCALE) for x, y in
                      (struct.unpack_from("<hh", raw["VERTEXES"], i * 4)
                       for i in range(len(raw["VERTEXES"]) // 4))]
        self.linedefs = [struct.unpack_from("<HHHHHHH", raw["LINEDEFS"], i * 14)
                         for i in range(len(raw["LINEDEFS"]) // 14)]
        self.side_sector = [struct.unpack_from("<H", raw["SIDEDEFS"], i * 30 + 28)[0]
                            for i in range(len(raw["SIDEDEFS"]) // 30)]
        self.sectors = []
        for i in range(len(raw["SECTORS"]) // 26):
            floor_h, ceil_h = struct.unpack_from("<hh", raw["SECTORS"], i * 26)
            _, special, tag = struct.unpack_from("<hhh", raw["SECTORS"], i * 26 + 20)
            self.sectors.append((floor_h, ceil_h, special, tag))
        self.things = [struct.unpack_from("<hhHHH", raw["THINGS"], i * 10)
                       for i in range(len(raw["THINGS"]) // 10)]

        # Per-sector activation info
        self.movable = set()
        self.walk_openable = {}    # sector -> True if a W-opener targets it
        self.manual_door = {}      # sector -> True if a manual door type targets it
        self.stays_open = {}       # sector -> True if any opener is open-stay
        self.walk_opener_lines = {}  # linedef idx -> [target sectors]
        self.closer_lines = set()    # linedefs whose crossing closes a door
        for li, (v1, v2, flags, special, tag, s_right, s_left) in enumerate(self.linedefs):
            if special in WALK_CLOSERS and s_left != 0xFFFF:
                self.closer_lines.add(li)
            if special not in DOOR_LIKE_SPECIALS:
                continue
            if tag == 0 and s_left != 0xFFFF:
                targets = [self.side_sector[s_left]]
            elif tag != 0:
                targets = [si for si, (_, _, _, t) in enumerate(self.sectors) if t == tag]
            else:
                targets = []
            for si in targets:
                self.movable.add(si)
                if special in WALK_OPENERS:
                    self.walk_openable[si] = True
                    self.walk_opener_lines.setdefault(li, []).append(si)
                if special in MANUAL_DOORS:
                    self.manual_door[si] = True
                if special in OPEN_STAY:
                    self.stays_open[si] = True

        # Route-order state: sectors known to be in a passable state, and
        # sectors the router must never cross (set per map by callers).
        self.opened = set()
        self.path_block = set()

        # Spatial hash of linedefs
        self._hash = {}
        for li, (v1, v2, *_rest) in enumerate(self.linedefs):
            (x1, z1), (x2, z2) = self.verts[v1], self.verts[v2]
            bx1, bx2 = sorted((int(x1 // BUCKET), int(x2 // BUCKET)))
            bz1, bz2 = sorted((int(z1 // BUCKET), int(z2 // BUCKET)))
            for bx in range(bx1, bx2 + 1):
                for bz in range(bz1, bz2 + 1):
                    self._hash.setdefault((bx, bz), []).append(li)
        self._edge_cache = {}

    # ---------------- basic queries ----------------

    def player_start(self):
        for x, y, ang, ttype, flags in self.things:
            if ttype == 1:
                return (x * SCALE, -y * SCALE)
        return None

    def point_sector(self, p):
        """Sector containing p: nearest linedef hit by a +x ray, taking the
        side facing p. (Front side has positive cross in scene coords.)"""
        px, pz = p
        best_t, best = None, -1
        for li, (v1, v2, *_rest) in enumerate(self.linedefs):
            (x1, z1), (x2, z2) = self.verts[v1], self.verts[v2]
            if (z1 > pz) == (z2 > pz):
                continue
            t = x1 + (pz - z1) / (z2 - z1) * (x2 - x1)
            if t <= px:
                continue
            if best_t is None or t < best_t:
                best_t, best = t, li
        if best < 0:
            return None
        v1, v2, flags, special, tag, s_right, s_left = self.linedefs[best]
        (x1, z1), (x2, z2) = self.verts[v1], self.verts[v2]
        cross = (x2 - x1) * (pz - z1) - (z2 - z1) * (px - x1)
        side = s_right if cross > 0 else s_left
        if side == 0xFFFF:
            side = s_right
        return self.side_sector[side]

    def point_closed_door_sector(self, p):
        """Sector index if p lies inside a closed manual-door sector, else
        None (path points there make the route zigzag through the slab)."""
        si = self.point_sector(p)
        if si is None:
            return None
        f, c, _, _ = self.sectors[si]
        if (si in self.movable and bool(self.manual_door.get(si))
                and c - f < MIN_GAP and si not in self.opened):
            return si
        return None

    def sector_bounds(self, si):
        xs, zs = [], []
        for v1, v2, flags, special, tag, s_right, s_left in self.linedefs:
            for sd in (s_right, s_left):
                if sd != 0xFFFF and self.side_sector[sd] == si:
                    for v in (v1, v2):
                        xs.append(self.verts[v][0])
                        zs.append(self.verts[v][1])
        if not xs:
            return None
        return (min(xs), min(zs), max(xs), max(zs))

    # ---------------- hop analysis ----------------

    def _candidates(self, a, b):
        bx1, bx2 = sorted((int(a[0] // BUCKET), int(b[0] // BUCKET)))
        bz1, bz2 = sorted((int(a[1] // BUCKET), int(b[1] // BUCKET)))
        out = set()
        for bx in range(bx1 - 1, bx2 + 2):
            for bz in range(bz1 - 1, bz2 + 2):
                out.update(self._hash.get((bx, bz), ()))
        return out

    @staticmethod
    def _cross(p1, p2, q1, q2):
        def d(a, b, c):
            return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
        d1, d2 = d(q1, q2, p1), d(q1, q2, p2)
        d3, d4 = d(p1, p2, q1), d(p1, p2, q2)
        return ((d1 > 0) != (d2 > 0)) and ((d3 > 0) != (d4 > 0))

    @staticmethod
    def _cross_t(p1, p2, q1, q2):
        dpx, dpz = p2[0] - p1[0], p2[1] - p1[1]
        dqx, dqz = q2[0] - q1[0], q2[1] - q1[1]
        denom = dpx * dqz - dpz * dqx
        if abs(denom) < 1e-12:
            return 0.5
        return ((q1[0] - p1[0]) * dqz - (q1[1] - p1[1]) * dqx) / denom

    def _crossings(self, a, b):
        """All linedefs crossed by a->b as (t, linedef_index), sorted."""
        out = []
        for li in self._candidates(a, b):
            v1, v2 = self.linedefs[li][0], self.linedefs[li][1]
            q1, q2 = self.verts[v1], self.verts[v2]
            if self._cross(a, b, q1, q2):
                out.append((self._cross_t(a, b, q1, q2), li))
        out.sort()
        return out

    def seg_scan(self, a, b, opened=None):
        """Analyze the directed straight hop a->b in crossing order.

        Returns (problems, gates): problems are blocking reasons; gates are
        (t, sector) entries for manual doors needing a typed condition.
        Walkover trigger lines crossed earlier in the hop open their targets
        for the rest of the hop."""
        opened = set(self.opened if opened is None else opened)
        problems, gates = [], []
        for t, li in self._crossings(a, b):
            v1, v2, flags, special, tag, s_right, s_left = self.linedefs[li]
            if li in self.walk_opener_lines and s_left != 0xFFFF:
                opened.update(self.walk_opener_lines[li])
            if s_left == 0xFFFF:
                problems.append("solid wall")
                continue
            if flags & ML_BLOCKING:
                problems.append("blocking line")
                continue
            fs, bs = self.side_sector[s_right], self.side_sector[s_left]
            q1, q2 = self.verts[v1], self.verts[v2]
            cr = ((q2[0] - q1[0]) * (a[1] - q1[1])
                  - (q2[1] - q1[1]) * (a[0] - q1[0]))
            src, dst = (fs, bs) if cr > 0 else (bs, fs)
            if src in self.path_block or dst in self.path_block:
                problems.append("blocked sector (sec %d->%d)" % (src, dst))
                continue
            s_floor = self.sectors[src][0]
            d_floor, d_ceil = self.sectors[dst][0], self.sectors[dst][1]
            gap = min(self.sectors[src][1], d_ceil) - max(s_floor, d_floor)
            climb = d_floor - s_floor
            passable = gap >= MIN_GAP and climb <= MAX_STEP
            if passable:
                continue
            movable = src in self.movable or dst in self.movable
            if not movable:
                if gap < MIN_GAP:
                    problems.append("gap %d too small (sec %d->%d)" % (gap, src, dst))
                else:
                    problems.append("climb %d too high (sec %d->%d)" % (climb, src, dst))
                continue
            m_sec = dst if dst in self.movable else src
            if m_sec in opened:
                continue
            if self.walk_openable.get(m_sec):
                problems.append("unopened walkover sector %d" % m_sec)
            elif self.manual_door.get(m_sec):
                if not gates or gates[-1][1] != m_sec:
                    # include the crossed line's midpoint: it centers the
                    # opening between the jambs (works for multi-slab doors)
                    mid = ((q1[0] + q2[0]) / 2, (q1[1] + q2[1]) / 2)
                    gates.append((t, m_sec, mid))
            else:
                problems.append("immovable-in-practice sector %d" % m_sec)
        return problems, gates

    def commit_hop(self, a, b, gated=()):
        """Record route progress over hop a->b: walkover triggers fire, and
        gated open-stay doors remain open. Clears the A* edge cache when the
        opened-state changes."""
        newly = set()
        for t, li in self._crossings(a, b):
            if li in self.walk_opener_lines:
                newly.update(self.walk_opener_lines[li])
        for sec in gated:
            if self.stays_open.get(sec):
                newly.add(sec)
        if newly - self.opened:
            self.opened |= newly
            self._edge_cache.clear()

    GATE_PENALTY = 300.0     # typed-door crossing: only when unavoidable
    CLOSER_PENALTY = 120.0   # walkover closer line: avoid springing traps

    def seg_walk(self, a, b):
        """(walkable, extra_cost) for a directed hop with clearance flanks.
        extra_cost penalizes typed-door crossings and walkover closer lines
        so pathfinding avoids both unless there is no open way around."""
        dx, dz = b[0] - a[0], b[1] - a[1]
        length = (dx * dx + dz * dz) ** 0.5
        if length < 1e-9:
            return True, 0.0
        probs, gates = self.seg_scan(a, b)
        if probs:
            return False, 0.0
        ox, oz = -dz / length * PLAYER_RADIUS, dx / length * PLAYER_RADIUS
        for off in ((ox, oz), (-ox, -oz)):
            p = (a[0] + off[0], a[1] + off[1])
            q = (b[0] + off[0], b[1] + off[1])
            if self.seg_scan(p, q)[0]:
                return False, 0.0
        closers = sum(1 for _, li in self._crossings(a, b)
                      if li in self.closer_lines)
        return True, (self.GATE_PENALTY * len(gates)
                      + self.CLOSER_PENALTY * closers)

    def _edge_walk(self, a, b):
        key = (a, b)
        hit = self._edge_cache.get(key)
        if hit is None:
            hit = self.seg_walk(a, b)
            self._edge_cache[key] = hit
        return hit

    # ---------------- pathfinding ----------------

    def find_path(self, a, b, max_nodes=400000):
        """A* on a GRID lattice honoring current opened-state; returns a
        simplified [a..b] point list or None."""
        # Grid nodes are offset by J so they never coincide with map lines
        # (WAD geometry sits on multiples of SCALE): a node exactly on a wall
        # lets the strict crossing test slip segments into the void.
        J = 0.137
        def snap(p):
            # round to the same precision as neighbor generation, or the
            # goal-equality test can miss by float epsilon
            return (round(round((p[0] - J) / GRID) * GRID + J, 4),
                    round(round((p[1] - J) / GRID) * GRID + J, 4))
        start, goal = snap(a), snap(b)

        def h(n):
            return abs(n[0] - goal[0]) + abs(n[1] - goal[1])

        open_q = [(h(start), 0.0, start)]
        came, gscore = {start: None}, {start: 0.0}
        found = False
        explored = 0
        while open_q and explored < max_nodes:
            _, g, cur = heapq.heappop(open_q)
            explored += 1
            if cur == goal:
                found = True
                break
            cx, cz = cur
            for nx, nz in ((cx + GRID, cz), (cx - GRID, cz),
                           (cx, cz + GRID), (cx, cz - GRID)):
                nxt = (round(nx, 4), round(nz, 4))
                ok, extra = self._edge_walk(cur, nxt)
                if not ok:
                    continue
                ng = g + GRID + extra
                if gscore.get(nxt, 1e18) <= ng:
                    continue
                gscore[nxt] = ng
                came[nxt] = cur
                heapq.heappush(open_q, (ng + h(nxt), ng, nxt))
        if not found:
            return None
        path = [goal]
        while came[path[-1]] is not None:
            path.append(came[path[-1]])
        path.reverse()
        path = [a] + path + [b]
        return self._simplify(path)

    def _simplify(self, path):
        # Only merge across penalty-free segments: a long merged segment
        # could cross a door or closer trigger the grid path avoided.
        out = [path[0]]
        i = 0
        while i < len(path) - 1:
            j = len(path) - 1
            while j > i + 1 and self._edge_walk(path[i], path[j]) != (True, 0.0):
                j -= 1
            out.append(path[j])
            i = j
        return out
