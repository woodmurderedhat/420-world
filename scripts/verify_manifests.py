import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARTS_DIR = ROOT / 'data' / 'items' / 'assets' / 'character_parts'

failed = False
for part_dir in PARTS_DIR.iterdir():
    if not part_dir.is_dir():
        continue
    manifest = part_dir / 'manifest.json'
    if not manifest.exists():
        print(f"MISSING manifest: {manifest}")
        failed = True
        continue
    data = json.loads(manifest.read_text())
    parts = data.get('parts', [])
    if not parts:
        print(f"WARN: no parts in {manifest}")
        failed = True
    for p in parts:
        tex = p.get('texture_path')
        if not tex:
            print(f"ERR: no texture_path for {p.get('id')} in {manifest}")
            failed = True
            continue
        tex_path = (part_dir / tex).resolve()
        if not tex_path.exists():
            print(f"ERR: texture file missing: {tex_path}")
            failed = True

if not failed:
    print('PASS: all manifests reference existing texture files')
    exit(0)
else:
    print('FAIL: manifest verification failed')
    exit(1)
