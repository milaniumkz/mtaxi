"""Build review artifacts from completed evidence; never substitute source inventory for executed checks."""
import csv
import html
import json
from pathlib import Path
p=Path(__file__).resolve().parents[2]/'output/load-followup'
load=json.loads((p/'load-final.json').read_text())
summary=json.loads((p/'load-summary.json').read_text())
rows=[]
for filename,kind in [('api-matrix.json','HTTP API'),('final-ui-f9744a3/ui-matrix.json','browser')]:
    for row in json.loads((p/filename).read_text()): rows.append(dict(kind=kind,**row))
finished=summary['finished']
observed={x['name']:x for x in load['stages']}
for stage in load['plan']:
    found=observed.get(stage['name'])
    passed=bool(found and found['actualSeconds']>=stage['seconds']-.1 and not found.get('unexpected'))
    rows.append(dict(kind='load',name=stage['name'],role='600 passenger/390 driver/10 admin',expected=stage,actual=found,status='passed' if passed else 'failed' if finished else 'pending',evidence='load-final.json'))
for op,goal in summary['latencyGoals'].items():
    rows.append(dict(kind='latency goal',name=op,role='mixed',expected={'p95MaxMs':goal['targetMs']},actual={'p95Ms':goal['p95Ms']},status='passed' if finished and goal['passed'] else 'failed' if finished else 'pending',evidence='load-summary.json'))
reconciliation=p/'reconciliation-final.json'
if reconciliation.exists():
    r=json.loads(reconciliation.read_text());rows.append(dict(kind='reconciliation',name='All1000 user cash/driver bonus/passenger bonus balances',role='all',expected='No ledger mismatch or negative wallet',actual=r,status='passed' if r['passed'] else 'failed',evidence=reconciliation.name))
(p/'verification-matrix.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
with (p/'verification-matrix.csv').open('w') as f:
    writer=csv.DictWriter(f,fieldnames=['kind','name','role','expected','actual','status','evidence']);writer.writeheader()
    for row in rows:writer.writerow({k:json.dumps(v,ensure_ascii=False) if isinstance(v,(dict,list)) else v for k,v in row.items()})
counts={s:sum(x['status']==s for x in rows) for s in ['passed','failed','pending']}
(p/'coverage-summary.json').write_text(json.dumps(counts,indent=2))
shots=sorted((p/'final-ui-f9744a3').glob('*.png'))
(p/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>MTaxi load follow-up</title><style>body{font:16px sans-serif;background:#f6f5f0;padding:24px}figure{display:inline-block;vertical-align:top;width:330px;margin:10px}img{width:100%;border:1px solid #aaa}figcaption{overflow-wrap:anywhere}td,th{padding:8px;border-bottom:1px solid #ddd}table{border-collapse:collapse}</style><h1>MTaxi: isolated load follow-up</h1><p>Backend f9744a3. Providers synthetic, SMS/FCM disabled. No production deployment. Device/background/push-fanout checks remain outside this test.</p><p>'+html.escape(json.dumps(counts))+'</p><p><a href="verification-matrix.csv">Matrix</a> · <a href="load-final.json">Raw load</a> · <a href="load-summary.json">Summary</a> · <a href="reconciliation-final.json">All balances</a></p><table><tr><th>Stage</th><th>Sessions</th><th>Seconds</th><th>Requests</th><th>Errors</th><th>Trips</th></tr>'+''.join('<tr>'+''.join('<td>'+html.escape(str(stage.get(k,'')))+'</td>' for k in ['name','vus','actualSeconds','requests','unexpected','completedTrips'])+'</tr>' for stage in load['stages'])+'</table>'+''.join('<figure><a href="final-ui-f9744a3/'+html.escape(x.name)+'"><img loading="lazy" src="final-ui-f9744a3/'+html.escape(x.name)+'"></a><figcaption>'+html.escape(x.name)+(' — initial test-input timing diagnostic; later rechecked' if 'failure' in x.name else '')+'</figcaption></figure>' for x in shots))
print(json.dumps(dict(matrix=counts,screenshots=len(shots))))
