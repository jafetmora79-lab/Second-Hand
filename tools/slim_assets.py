"""Shrinks the asset pack: caps every texture (embedded in .glb models and loose .png/.jpg beside them) at MAX px on the long side.
The game pixelates kit textures to 256 px at runtime (kit.gd pixelate), so 512 keeps a 2x margin.  Run:  python -I tools/slim_assets.py [MAX]"""
import glob, io, json, os, struct, sys
from PIL import Image

MAX = int(sys.argv[1]) if len(sys.argv) > 1 else 512
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
SKIP = {os.path.normpath(os.path.join(root, "textures"))}

def shrink(img):
    if max(img.size) <= MAX:
        return None
    s = MAX / max(img.size)
    return img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)

def encode(img, mime):
    b = io.BytesIO()
    if mime == "image/jpeg":
        img.convert("RGB").save(b, "JPEG", quality=90, optimize=True)
    else:
        img.save(b, "PNG", optimize=True)
    return b.getvalue()

def slim_glb(path):
    d = open(path, "rb").read()
    jl = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + jl])
    bo = 20 + jl + 8
    binlen = struct.unpack("<I", d[20 + jl:24 + jl])[0]
    blob = d[bo:bo + binlen]
    views = j.get("bufferViews", [])
    new = {}
    for im in j.get("images", []):
        if "bufferView" not in im:
            continue
        v = views[im["bufferView"]]
        raw = blob[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
        img = Image.open(io.BytesIO(raw)); img.load()
        small = shrink(img)
        if small is not None:
            out = encode(small, im.get("mimeType", "image/png"))
            if len(out) < len(raw):
                new[im["bufferView"]] = out
    if not new:
        return 0
    out = bytearray()
    for i, v in enumerate(views):
        while len(out) % 4: out.append(0)
        data = new.get(i, blob[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]])
        v["byteOffset"] = len(out); v["byteLength"] = len(data)
        out += data
    while len(out) % 4: out.append(0)
    j["buffers"][0]["byteLength"] = len(out)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(out)
    open(path, "wb").write(b"glTF" + struct.pack("<II", 2, total) + struct.pack("<I", len(js)) + b"JSON" + js + struct.pack("<I", len(out)) + b"BIN\0" + bytes(out))
    return len(d) - total

def slim_img(path):
    img = Image.open(path); img.load()
    small = shrink(img)
    if small is None:
        return 0
    before = os.path.getsize(path)
    if path.lower().endswith(".png"):
        small.save(path, "PNG", optimize=True)
    else:
        small.convert("RGB").save(path, "JPEG", quality=90, optimize=True)
    return before - os.path.getsize(path)

saved = 0
for p in sorted(glob.glob(os.path.join(root, "**", "*"), recursive=True)):
    if os.path.normpath(os.path.dirname(p)) in SKIP or os.path.isdir(p):
        continue
    e = p.lower().rsplit(".", 1)[-1]
    if e == "glb": saved += slim_glb(p)
    elif e in ("png", "jpg", "jpeg"): saved += slim_img(p)
print("saved %.1f MB" % (saved / 1048576))
