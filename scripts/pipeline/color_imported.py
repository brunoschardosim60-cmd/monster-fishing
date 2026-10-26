"""Paints the untextured meshes Bruno sent (Tripo FBX/GLB, no UVs, no colours).

Sources live in model_sources/ (the 46 MB dragon GLB is not in git; its 70k-triangle reduction is made
with fast_simplification and saved as RAW_DIR/dragon_70k.ply).
Input: raw mesh dumps written by scripts/pipeline/dump_imported.gd (positions + Godot triangle order).
Output: one .bin per model for scripts/pipeline/bake_imported.gd, which turns them into Godot meshes.

Each face gets a base colour and a pattern id for assets/shaders/imported_model.gdshader (the shader
draws planks, containers, windows, sailcloth, scales… in object space, so no UVs are needed).
Vertices are split only where the class changes, so normals stay smooth inside each painted region
and colour borders stay sharp. Ambient occlusion is baked into the colour with embree rays.

Run:  python3 -I scripts/pipeline/color_imported.py RAW_DIR OUT_DIR
"""
import sys, json, struct
import numpy as np, trimesh

RAW, OUT = sys.argv[1], sys.argv[2]


def load(name):
    b = open(f"{RAW}/{name}.bin", "rb").read()
    nv, ni = np.frombuffer(b[:8], np.uint32)
    o = 8
    V = np.frombuffer(b[o:o + nv * 12], np.float32).reshape(-1, 3); o += nv * 12
    I = np.frombuffer(b[o:o + ni * 4], np.int32).reshape(-1, 3)[:, [0, 2, 1]]  # Godot winds clockwise
    return trimesh.Trimesh(V.copy(), I.copy(), process=True)


def rot_y(m, deg):
    m.apply_transform(trimesh.transformations.rotation_matrix(np.radians(deg), [0, 1, 0]))


def ao(m, normals, rays=20, reach=.06):
    """Fraction of the hemisphere above each vertex that is open (1 = fully open)."""
    rng = np.random.default_rng(3)
    dirs = rng.normal(size=(rays, 3)); dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
    inter = trimesh.ray.ray_pyembree.RayMeshIntersector(m)
    V = m.vertices
    open_ = np.zeros(len(V))
    for d in dirs:
        dd = np.where((normals @ d)[:, None] < 0, -d, d)
        origins = V + normals * 1e-4
        hit, ray_i, _ = inter.intersects_location(origins, dd, multiple_hits=False)
        blocked = np.zeros(len(V), bool)
        if len(ray_i):
            dist = np.linalg.norm(hit - origins[ray_i], axis=1)
            blocked[ray_i[dist < reach]] = True
        open_ += ~blocked
    return open_ / rays


def write(name, m, face_rgb, face_pat, ao_strength=.55, reach=.06, smooth=True, meta=None):
    """Splits vertices by class, computes normals, bakes AO and writes the .bin for Godot."""
    F = m.faces
    key = np.round(face_rgb * 255).astype(np.int64) @ np.array([1, 256, 65536]) + face_pat.astype(np.int64) * 16777216
    # one new vertex per (old vertex, class)
    pairs = np.stack([F.reshape(-1), np.repeat(key, 3)], 1)
    uniq, inv = np.unique(pairs, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    NV = m.vertices[uniq[:, 0]]
    NF = inv.reshape(-1, 3)
    fn = m.face_normals * m.area_faces[:, None]
    N = np.zeros_like(NV)
    for k in range(3): np.add.at(N, NF[:, k], fn)
    if not smooth:
        pass
    N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-12
    C = np.zeros((len(NV), 3)); P = np.zeros(len(NV))
    for k in range(3):
        C[NF[:, k]] = face_rgb; P[NF[:, k]] = face_pat
    if ao_strength > 0:
        occ = ao(m, m.vertex_normals, reach=reach)
        C *= ((1 - ao_strength) + ao_strength * occ[uniq[:, 0]])[:, None]
    rgba = np.concatenate([np.clip(C, 0, 1) * 255, (P / 15. * 255)[:, None]], 1).round().astype(np.uint8)
    with open(f"{OUT}/{name}.bin", "wb") as f:
        f.write(struct.pack("<II", len(NV), NF.size))
        f.write(NV.astype(np.float32).tobytes()); f.write(N.astype(np.float32).tobytes())
        f.write(rgba.tobytes()); f.write(NF[:, [0, 2, 1]].astype(np.int32).tobytes())  # back to clockwise
    info = {"faces": int(len(NF)), "vertices": int(len(NV)), "bounds": m.bounds.round(4).tolist()}
    info.update(meta or {})
    json.dump(info, open(f"{OUT}/{name}.json", "w"), indent=1)
    print(name, info)


def srgb(h):
    h = h.lstrip("#"); return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def paint(n, color, pat):
    return np.tile(srgb(color), (n, 1)), np.full(n, pat)


# ------------------------------------------------------------------ container ship
def merchant(name, deck, wl, bridge, containers):
    m = load(name)
    c = m.triangles_center; nr = m.face_normals
    rgb, pat = paint(len(m.faces), "#888888", 1)
    above = c[:, 1] > deck - .009
    in_bridge = (c[:, 2] > bridge[0]) & (c[:, 2] < bridge[1]) & above
    rgb[in_bridge] = srgb("#eeeeea"); pat[in_bridge] = 3
    top = in_bridge & (c[:, 1] > bridge[2])
    rgb[top] = srgb("#2a2a2a"); pat[top] = 7
    deckf = above & (nr[:, 1] > .7) & (c[:, 1] < deck + .006) & ~in_bridge
    rgb[deckf] = srgb("#4f5f55"); pat[deckf] = 6
    if containers:
        box = above & ~in_bridge & (c[:, 1] > deck + .004) & (np.abs(c[:, 2]) < .47)
        rgb[box] = srgb("#ffffff"); pat[box] = 2
    else:
        hatch = above & ~in_bridge & (c[:, 2] > -.28) & (c[:, 2] < .34) & (c[:, 1] < deck + .03) & (nr[:, 1] > .5)
        rgb[hatch] = srgb("#2f5a46"); pat[hatch] = 6
        crane = above & ~in_bridge & (c[:, 2] > -.28) & (c[:, 2] < .4) & (c[:, 1] > deck + .012) & ~hatch
        rgb[crane] = srgb("#d9a521"); pat[crane] = 0
    bow_mast = above & (c[:, 2] > .4) & (c[:, 1] > deck + .02)
    rgb[bow_mast] = srgb("#d9a521"); pat[bow_mast] = 0
    rot_y(m, 180)  # bow to -Z
    m.apply_translation([0, -wl, 0])
    write(name, m, rgb, pat, reach=.03, meta={"deck": deck - wl, "length": 1.0,
          "bridge_z": -(bridge[0] + bridge[1]) * .5, "bridge_top": bridge[2] - wl})


merchant("container_ship", .1, .045, (-.36, -.265, .215), True)
merchant("cargo_ship", .108, .045, (-.43, -.285, .213), False)


# ------------------------------------------------------------------ galleon
def galleon():
    m = load("sailing_ship")
    wl = .045
    parts = m.split(only_watertight=False)
    big = max(parts, key=lambda p: p.area)
    rgb_all, pat_all, meshes = [], [], []
    for p in parts:
        c = p.triangles_center; nr = p.face_normals; n = len(p.faces)
        e = p.extents
        mean_area = p.area / n
        if p is big:
            rgb, pat = paint(n, "#3a2416", 12)   # the shader paints the gun stripe and the bottom
            up = nr[:, 1] > .6
            rgb[up] = srgb("#9c7b52"); pat[up] = 4
        elif mean_area > 1.5e-4 and c[:, 1].mean() > .14:
            rgb, pat = paint(n, "#ece2c9", 5)
        elif max(e[0], e[2]) < .06 and e[1] > .08:
            rgb, pat = paint(n, "#4a3220", 0)          # masts
        elif p.area < 6e-4 and max(e) > .04:
            rgb, pat = paint(n, "#1d1712", 0)          # rigging
        elif e[1] > .2 and min(e) < .04:
            rgb, pat = paint(n, "#241c15", 0)          # shrouds and ratlines
        else:
            rgb, pat = paint(n, "#6b4a2c", 4)          # deck fittings
        meshes.append(p); rgb_all.append(rgb); pat_all.append(pat)
    m = trimesh.util.concatenate(meshes)
    rgb = np.concatenate(rgb_all); pat = np.concatenate(pat_all)
    rot_y(m, -90)  # bowsprit (-X) to -Z
    m.apply_translation([0, -wl, 0])
    write("sailing_ship", m, rgb, pat, reach=.03, meta={"deck": .113 - wl, "length": 1.0})


galleon()


# ------------------------------------------------------------------ rowboat
def rowboat():
    m = load("rowboat")
    wl = .045
    c = m.triangles_center; nr = m.face_normals
    rgb, pat = paint(len(m.faces), "#8a6e50", 4)       # weathered planks inside
    radial = np.stack([np.zeros(len(c)), np.zeros(len(c)), np.sign(c[:, 2])], 1)
    outward = (np.einsum("ij,ij->i", nr, radial) > .25) & (np.abs(c[:, 2]) > np.interp(c[:, 0], [-.5, -.3, 0, .3, .5], [.01, .1, .14, .1, .01]))
    outward |= (nr[:, 1] < -.4) & (c[:, 1] < .03)
    ends = np.abs(c[:, 0]) > .44
    outward |= ends & (np.abs(nr[:, 0]) > .5) & (np.sign(nr[:, 0]) == np.sign(c[:, 0]))
    rgb[outward] = srgb("#7a3a26"); pat[outward] = 11  # paint colour comes from hull_paint above water
    rail = (nr[:, 1] > .5) & (c[:, 1] > .11)
    rgb[rail] = srgb("#5b4129"); pat[rail] = 4
    parts = m.split(only_watertight=False)
    rot_y(m, 90)
    m.apply_translation([0, -wl, 0])
    write("rowboat", m, rgb, pat, reach=.04, meta={"deck": .035 - wl, "rail": .125 - wl, "length": 1.0})


rowboat()


# ------------------------------------------------------------------ marine pack
def marine_pack():
    """Splits the marine pack (one mesh) into its animals by connected pieces and position."""
    groups = {}
    for c in load("marine_life").split(only_watertight=False):
        x, y, z = c.bounds.mean(0)
        if (x < .02 and y < .25 and c.bounds[0][0] < -.1) or (x < 0 and y < .25): k = "shark"
        elif y < .12 and x < .25: k = "crab"
        elif x < -.03 and y > .25: k = "turtle"
        elif .24 < x < .37 and y < .26: k = "jelly_a"
        elif x >= .37 and y < .26: k = "jelly_b"
        elif .24 < x < .375: k = "jelly_c"
        elif x >= .375: k = "jelly_d"
        else: continue  # small flat fish, unused
        groups.setdefault(k, []).append(c)
    return {k: trimesh.util.concatenate(v) for k, v in groups.items()}


PACK = marine_pack()


def creature(name, colors_fn, pattern, forward_deg, ao_strength=.45):
    m = PACK[name].copy()
    rot_y(m, forward_deg)
    m.apply_translation(-m.bounds.mean(0))
    s = 1. / m.extents.max(); m.apply_scale(s)
    rgb = colors_fn(m)
    write(name, m, rgb, np.full(len(m.faces), pattern), ao_strength=ao_strength, reach=.08, meta={"length": 1.0})


def shark_colors(m):
    c = m.triangles_center; nr = m.face_normals
    top = srgb("#4c5d6b"); belly = srgb("#e8e6df")
    t = np.clip((nr[:, 1] + .15) * 1.6 + (c[:, 1] - .0) * 3., 0, 1)[:, None]
    return belly * (1 - t) + top * t


def turtle_colors(m):
    c = m.triangles_center; nr = m.face_normals
    rgb = np.tile(srgb("#a29a6c"), (len(c), 1))
    shell = (c[:, 1] > m.bounds[0][1] + m.extents[1] * .42) & (nr[:, 1] > .1) & (np.abs(c[:, 0]) < m.extents[0] * .3) & (c[:, 2] > -.28)
    rng = np.random.default_rng(5)
    seeds = rng.uniform(-.3, .3, (14, 2))
    d = np.linalg.norm(c[:, None, [0, 2]] - seeds[None], axis=2); near = d.argmin(1)
    tones = np.array([srgb("#6e5832"), srgb("#86703e"), srgb("#5a4628"), srgb("#947c4a")])
    rgb[shell] = tones[near[shell] % 4]
    belly = nr[:, 1] < -.5
    rgb[belly] = srgb("#efe2b4")
    return rgb


def crab_colors(m):
    c = m.triangles_center; nr = m.face_normals
    rgb = np.tile(srgb("#b8401c"), (len(c), 1))
    rgb[nr[:, 1] < -.3] = srgb("#e8c49a")
    r = np.linalg.norm(c[:, [0, 2]], axis=1)
    rgb[r > r.max() * .82] = srgb("#2a1410")
    return rgb


def jelly_colors(m):
    c = m.triangles_center
    t = np.clip((c[:, 1] - m.bounds[0][1]) / m.extents[1], 0, 1)[:, None]
    return srgb("#f3b8e8") * (1 - t) + srgb("#c98ff0") * t


creature("shark", shark_colors, 9, 0)        # head stays +X, like the parametric fish
creature("turtle", turtle_colors, 9, 90)     # head to -Z like the other animals
creature("crab", crab_colors, 9, 0)
for k in "abcd":
    creature(f"jelly_{k}", jelly_colors, 0, 0, ao_strength=.2)


# ------------------------------------------------------------------ sea serpent (dragon)
def serpent():
    m = trimesh.load(f"{RAW}/dragon_70k.ply", force="mesh")
    m = trimesh.Trimesh(m.vertices, m.faces, process=True)
    c = m.triangles_center; nr = m.face_normals
    inter = trimesh.ray.ray_pyembree.RayMeshIntersector(m)
    # thickness: distance to the opposite side along -normal (fins, spines and teeth are thin)
    hit, idx, _ = inter.intersects_location(c - nr * 1e-4, -nr, multiple_hits=False)
    thick = np.full(len(c), 1.)
    if len(idx): thick[idx] = np.linalg.norm(hit - c[idx], axis=1)
    rgb = np.tile(srgb("#2b6258"), (len(c), 1)); pat = np.full(len(c), 10)
    belly = nr[:, 1] < -.35
    rgb[belly] = srgb("#c9b77a"); pat[belly] = 9
    side = (nr[:, 1] >= -.35) & (nr[:, 1] < .05)
    rgb[side] = srgb("#3a7a68")
    thin = thick < .012
    head = (c[:, 0] < -.12) & (c[:, 1] > .52)
    mouth = head & (c[:, 1] < .75) & (c[:, 0] < -.2)
    fin = thin & ~mouth
    rgb[fin] = srgb("#b4472c"); pat[fin] = 9
    teeth = thin & mouth
    rgb[teeth] = srgb("#efe6c8"); pat[teeth] = 0
    gullet = mouth & ~thin & (thick < .05) & (nr[:, 1] > -.2)
    rgb[gullet] = srgb("#5a1a1a"); pat[gullet] = 9
    for eye in ([-.3, .77, .0], [-.3, .77, .254]):
        d = np.linalg.norm(c - np.array(eye), axis=1)
        socket = d < d.min() + .016
        rgb[socket] = srgb("#ffd23a"); pat[socket] = 8
    rot_y(m, -90)  # head (-X) to -Z
    m.apply_translation([-m.bounds.mean(0)[0], 0, -m.bounds.mean(0)[2]])
    write("serpent", m, rgb, pat, ao_strength=.6, reach=.05, meta={"height": float(m.extents[1])})


serpent()
