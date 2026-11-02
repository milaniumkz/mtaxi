"""Aggregate existing evidence; does not execute tests or claim source-element coverage."""
import csv
import datetime
import html
import json
from pathlib import Path
p = Path(__file__).resolve().parents[2] / 'output/full-audit'
load = json.loads((p / 'load-validation.json').read_text())
def ts(value):
    return datetime.datetime.fromisoformat(value.replace('Z', '+00:00')).timestamp()
start = ts(load['startedAt'])
end = start + load['durationSeconds']
rows = [json.loads(x) for x in (p/'latest-backend-resources.jsonl').read_text().splitlines() if x]
rows = [x for x in rows if start <= ts(x['at']) <= end]
db = [json.loads(x) for x in (p/'load-validation.json.database.jsonl').read_text().splitlines() if x]
host = [json.loads(x) for x in (p/'load-validation-host.jsonl').read_text().splitlines() if x]
host = [x for x in host if start <= x['at'] <= end]
summary = dict(backendSamples=len(rows), backendMaxCpuPercent=max(x['cpuPercent'] for x in rows),
    backendMaxRssMiB=max(x['rss'] for x in rows)/1048576,
    backendMaxEventLoopP95Ms=max(x['eventLoopP95Ms'] for x in rows),
    databaseMaxima={k:max(float(x[k]) for x in db) for k in ['numbackends','waiting','negative_balances','duplicate_assignments','duplicate_money','deadlocks']},
    postgresMemorySamples=[x['docker']['MemUsage'] for x in host],
    hostOomEvents=sorted(set(x['memory.events'] for x in host)), hostCpuQuota=host[0]['cpu.max'],hostMemoryLimit=host[0]['memory.max'])
(p/'load-resources-summary.json').write_text(json.dumps(summary, indent=2))
matrix = []
for filename, kind in [('ui-matrix.json','browser'), ('api-matrix-final.json','HTTP API')]:
    for row in json.loads((p/filename).read_text()):
        matrix.append(dict(kind=kind, **row))
matrix.append(dict(kind='load',name='Capacity target: 1000 concurrent sessions',role='all',expected='Complete planned stages through1000 and hold/spike',actual='Stopped at250 after >5% unexpected errors over one minute; 14228 requests,292 errors',status='failed',evidence='load-validation.json'))
for name, reason in [
    ('Android install/upgrade/physical GPS/TTS/camera/push','No device/emulator'),
    ('iOS build/install/push/background GPS','No macOS/Xcode/device'),
    ('500/1000/15-minute hold/spike','Load safety stop at 250'),
]:
    matrix.append(dict(kind='pending',name=name,role='all',expected='Execute on appropriate isolated environment',actual=reason,status='blocked',evidence='docs/full_audit_2026-10-23.md'))
for name in ['Every source control clicked individually','Real village geocoding and route quality','Production backup restoration','Complete RU/KK and design pixel review','Driver cash withdrawal end-user flow','Real bank settlement reconciliation']:
    matrix.append(dict(kind='pending',name=name,role='all',expected='Additional verification/work',actual='Outside completed evidence',status='not_checked',evidence='docs/full_audit_2026-10-23.md'))
(p/'verification-matrix.json').write_text(json.dumps(matrix,ensure_ascii=False,indent=2))
with (p/'verification-matrix.csv').open('w') as out:
    writer=csv.DictWriter(out,fieldnames=['kind','name','role','expected','actual','status','evidence'])
    writer.writeheader()
    for row in matrix:
        writer.writerow({k:json.dumps(v,ensure_ascii=False) if isinstance(v,(dict,list)) else v for k,v in row.items()})
counts={status:sum(x['status']==status for x in matrix) for status in ['passed','failed','blocked','not_checked']}
(p/'coverage-summary.json').write_text(json.dumps(counts,indent=2))
shots=sorted(p.glob('*.png'))
(p/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>MTaxi isolated audit</title><style>body{font:16px sans-serif;background:#f4f3ee;padding:24px}figure{display:inline-block;vertical-align:top;width:340px;margin:12px}img{width:100%;border:1px solid #aaa}figcaption{overflow-wrap:anywhere}</style><h1>MTaxi: evidence, 2026-10-23</h1><p>Some screenshots show defects before fixes. Screen presence does not prove all controls work.</p><p>'+html.escape(json.dumps(counts))+'</p><p><a href="verification-matrix.csv">Verification matrix</a> · <a href="load-validation.json">Load results</a> · <a href="source-inventory.json">Source declarations</a></p>'+''.join('<figure><a href="'+html.escape(x.name)+'"><img loading="lazy" src="'+html.escape(x.name)+'"></a><figcaption>'+html.escape(x.name)+'</figcaption></figure>' for x in shots))
print(json.dumps(dict(matrix=counts,screenshots=len(shots),resources=summary),ensure_ascii=False))
