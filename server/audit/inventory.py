"""Source inventory only; declarations do not prove execution or visual coverage."""
import json
import re
from pathlib import Path
root = Path(__file__).resolve().parents[2]
routes, elements = [], []
for path in sorted((root / 'lib').rglob('*.dart')):
    source = str(path.relative_to(root))
    role = 'admin' if '/admin/' in source else 'driver' if '/driver/' in source else 'passenger/shared'
    text = path.read_text()
    for match in re.finditer(r"static String routePath\s*=\s*'([^']+)'", text):
        routes.append(dict(path=match[1], source=source, role=role))
    for line, value in enumerate(text.splitlines(), 1):
        if re.search(r'\bon(?:Tap|Pressed|Changed|Submitted):|\b(?:TextFormField|TextField)\(', value):
            elements.append(dict(id=f'EL-{len(elements)+1:04}', source=source, line=line,
                role=role, declaration=value.strip(), status='not_checked_individually', evidence=None))
output = root / 'output/full-audit'
output.mkdir(parents=True, exist_ok=True)
(output / 'source-inventory.json').write_text(json.dumps(dict(routes=routes, elements=elements,
    note='Source declarations only; see ui-matrix.json and api-matrix-final.json for executed scenarios.'), ensure_ascii=False, indent=2))
print(json.dumps(dict(routes=len(routes), declarations=len(elements))))
