#!/usr/bin/env python3
"""Build a local, offline comparison of handoff PNGs and Flutter golden fixtures.
Requires Pillow for the contact sheets; never fetches maps or modifies the inputs.
"""
import argparse
import hashlib
import html
import json
from pathlib import Path
import shutil
from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=Path('output/design-review'))
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    reference = args.reference.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / 'reference').mkdir(exist_ok=True)
    (output / 'flutter').mkdir(exist_ok=True)
    manifest = json.loads((reference / 'spec/SCREEN_MANIFEST.json').read_text())
    titles = {str(item['design_id']).zfill(2): item['title'] for item in manifest['screens']}
    titles.update({item['state_id']: item['title'] for item in manifest['state_cards']})
    ids = [f'{i:02}' for i in range(1, 33)] + [f'E{i:02}' for i in range(1, 9)]
    records, cards = [], []
    for screen_id in ids:
        source = reference / 'design' / ('states' if screen_id.startswith('E') else 'screens') / f'{screen_id}.png'
        actual = repo / 'test/goldens' / f'{screen_id}.png'
        if not source.exists() or not actual.exists():
            raise SystemExit(f'Missing reference or fixture for {screen_id}')
        shutil.copy2(source, output / 'reference' / source.name)
        shutil.copy2(actual, output / 'flutter' / actual.name)
        records.append({'id': screen_id, 'title': titles[screen_id], 'reference_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'flutter_sha256': hashlib.sha256(actual.read_bytes()).hexdigest(), 'flutter_size': Image.open(actual).size})
        title = html.escape(titles[screen_id])
        cards.append(f'<article id="{screen_id}"><h2>{screen_id} · {title}</h2><div class="pair"><figure><figcaption>Утверждённый PNG</figcaption><img src="reference/{screen_id}.png" alt="Эталон {screen_id}"></figure><figure><figcaption>Flutter · тестовые данные</figcaption><img src="flutter/{screen_id}.png" alt="Flutter {screen_id}"></figure></div></article>')
    for first in range(0, len(ids), 8):
        batch = ids[first:first + 8]
        sheet = Image.new('RGB', (1600, 920), '#e8ebe5')
        draw = ImageDraw.Draw(sheet)
        for index, screen_id in enumerate(batch):
            x, y = index % 4 * 400, index // 4 * 460
            draw.text((x + 8, y + 4), f'{screen_id}  reference | Flutter', fill='#1b242b')
            for column, folder in enumerate(('reference', 'flutter')):
                im = Image.open(output / folder / f'{screen_id}.png').convert('RGB')
                im.thumbnail((195, 422))
                sheet.paste(im, (x + column * 200, y + 26))
        sheet.save(output / f'comparison-{first + 1:02}-{first + len(batch):02}.png')
    (output / 'manifest.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
    (output / 'index.html').write_text('''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>MTaxi · сравнение дизайна</title><style>body{font:16px system-ui;background:#fcfcfa;color:#1b242b;margin:24px}header{max-width:960px}article{border-top:1px solid #ccc;padding-top:18px;margin:32px 0}h2{font-size:22px}.pair{display:flex;flex-wrap:wrap;gap:22px}figure{margin:0}figcaption{margin:10px 0}img{width:390px;max-width:100%;height:auto;border:1px solid #ddd}nav a{display:inline-block;padding:10px;color:#1b242b}</style><header><h1>MTaxi · визуальный обзор</h1><p>Слева исходный PNG, справа снимок реальных Flutter-виджетов на fixtures. Обе стороны — 390×844. Это инструмент ручного сравнения, а не автоматическое подтверждение соответствия дизайну.</p><p>Карта в тестах использует одноцветные тайлы: сеть, реальные GPS и реальные платежи не используются. Шкала, имена, суммы и маршруты — тестовые данные. Системные status bars из концепта не рисуются внутри приложения. E06 проверяет компонент ошибки; полный выбор/загрузка фото требует отдельной проверки.</p></header><nav>''' + ''.join(f'<a href="#{item}">{item}</a>' for item in ids) + '</nav>' + ''.join(cards) + '</html>', encoding='utf-8')
    print(f'{len(records)} comparisons: {output / "index.html"}')


if __name__ == '__main__':
    main()
