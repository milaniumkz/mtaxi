#!/usr/bin/env python3
"""Generate public, script-free legal pages from the same asset used by Flutter."""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
source = json.loads((ROOT / 'assets/jsons/legal_documents.json').read_text())
output = ROOT / 'web/legal'
output.mkdir(parents=True, exist_ok=True)
e = html.escape
style = '''*{box-sizing:border-box}body{margin:0;background:#f6f7f3;color:#1b242b;font:17px/1.65 system-ui,sans-serif}main{max-width:880px;margin:auto;padding:32px 20px 60px}header{border-bottom:1px solid #dce1da;padding-bottom:20px;margin-bottom:28px}.brand{font-weight:800;font-size:24px;color:#1b242b}h1{font-size:clamp(26px,5vw,38px);line-height:1.2}h2{font-size:22px;line-height:1.35;margin-top:32px}a{color:#126e68;text-underline-offset:3px}a:focus-visible{outline:3px solid #e6bd63;outline-offset:4px}nav ul{padding-left:24px}li{margin:12px 0}section{scroll-margin-top:20px}footer{border-top:1px solid #dce1da;margin-top:36px;padding-top:20px;font-size:15px}.meta{color:#56635d}article{overflow-wrap:anywhere}.contact{background:#fff;border:1px solid #dce1da;border-radius:16px;padding:20px}@media print{body{background:white}nav,.back{display:none}main{max-width:none;padding:0}h2{break-after:avoid}a{color:inherit}}'''
nav = '<nav aria-label="Документы"><ul>' + ''.join(f'<li><a href="/legal/{e(d["id"])}.html">{e(d["title"])}</a></li>' for d in source['documents']) + '</ul></nav>'
op = source['operator']
contact = f'<aside class="contact" aria-label="Реквизиты оператора"><strong>{e(op["name"])}</strong><br>ИИН {e(op["iin"])}<br>{e(op["address"])}<br><a href="mailto:{e(op["email"])}">{e(op["email"])}</a> · <a href="tel:{e(op["phone"])}">{e(op["phone"])}</a></aside>'
def page(title, body):
    return f'''<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="description" content="{e(title)} — MTaxi, ИП Milanium. Документ доступен без регистрации."><meta name="referrer" content="no-referrer"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"><title>{e(title)} — MTaxi</title><style>{style}</style></head><body><main><header><a class="brand" href="/legal/">MTaxi · документы</a><h1>{e(title)}</h1><p class="meta">Редакция {e(source['version'])}. Дата публикации: {e(source['effectiveDate'])}.</p></header>{body}<footer>{contact}<p><a href="/legal/">Все документы</a> · <a href="/">Открыть MTaxi</a></p><p>Документы можно сохранить или распечатать средствами браузера.</p></footer></main></body></html>'''
(output / 'index.html').write_text(page('Правовая информация', '<p>Условия использования MTaxi, обработка данных и правила расчётов. Все страницы открываются без входа в аккаунт.</p>' + nav))
for d in source['documents']:
    sections = ''.join(f'<section id="section-{i}"><h2>{e(s["title"])}</h2>' + ''.join(f'<p>{e(p)}</p>' for p in s['paragraphs']) + '</section>' for i,s in enumerate(d['sections'],1))
    body = '<p class="back"><a href="/legal/">← Все документы</a></p><article>' + sections + '</article>'
    if d['id'] == 'delete-account':
        body += f'<p><a href="mailto:{e(op["email"])}?subject=Удаление%20аккаунта%20MTaxi">Написать запрос на удаление</a></p>'
    (output / (d['id'] + '.html')).write_text(page(d['title'], body))
print(f'Generated {len(source["documents"])+1} public legal pages')
