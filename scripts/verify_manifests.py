import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARTS_DIR = ROOT / 'data' / 'items' / 'assets' / 'character_parts'

UNIFIED_MANIFEST = PARTS_DIR / 'manifest.json'

failed = False

if not UNIFIED_MANIFEST.exists():
    print(f"MISSING unified manifest: {UNIFIED_MANIFEST}")
    exit(1)

data = json.loads(UNIFIED_MANIFEST.read_text(encoding='utf-8'))
parts = data.get('parts', None)
if not parts:
    print(f"WARN: no parts in {UNIFIED_MANIFEST}")
    failed = True

# parts may be either a dict mapping types -> array of parts, or a flat array of parts
if isinstance(parts, dict):
    iter_parts = []
    for t, arr in parts.items():
        if not isinstance(arr, list):
            print(f"WARN: parts.{t} is not a list in {UNIFIED_MANIFEST}")
            failed = True
            continue
        for p in arr:
            iter_parts.append(p)
else:
    iter_parts = parts

for p in iter_parts:
    if not isinstance(p, dict):
        print(f"WARN: invalid part entry in {UNIFIED_MANIFEST}: {p}")
        failed = True
        continue

    tex = p.get('texture_path')
    if not tex:
        print(f"ERR: no texture_path for {p.get('id')} in {UNIFIED_MANIFEST}")
        failed = True
        continue

    # Support both res:// absolute paths and paths relative to the unified manifest.
    if isinstance(tex, str) and tex.startswith('res://'):
        rel = tex[len('res://'):].lstrip('/')
        tex_path = (ROOT / rel).resolve()
    else:
        tex_path = (UNIFIED_MANIFEST.parent / tex).resolve()

    if not tex_path.exists():
        print(f"ERR: texture file missing: {tex_path}")
        failed = True

if not failed:
    print('PASS: all manifests reference existing texture files')
    exit(0)
else:
    print('FAIL: manifest verification failed')
    exit(1)
