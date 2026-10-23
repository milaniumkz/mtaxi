"""Summarize observed load data without treating incomplete stages as passed."""
import datetime
import json
from pathlib import Path
p=Path(__file__).resolve().parents[2]/'output/load-followup'
r=json.loads((p/'load-final.json').read_text())
def timestamp(s): return datetime.datetime.fromisoformat(s.replace('Z','+00:00')).timestamp()
def lines(name):
    f=p/name
    return [json.loads(s) for s in f.read_text().splitlines() if s] if f.exists() else []
start=timestamp(r['startedAt']); end=start+r['durationSeconds']
backend=[x for x in lines('backend-final-resources.jsonl') if start<=timestamp(x['at'])<=end]
generator=lines('load-final.json.progress.jsonl')
db=lines('load-final.json.database.jsonl'); valid=[x for x in db if 'error' not in x]
host=[x for x in lines('host-final-resources.jsonl') if start<=x['at']<=end]
log=(p/'load-final.log').read_text()
finished='"finished":true' in log
planned=[x['name'] for x in r['plan']]
observed=[x['name'] for x in r['stages']]
summary=dict(revision=r['revision'],finished=finished,aborted=r['aborted'],abortReason=r['abortReason'],
    completedPlan=finished and not r['aborted'] and observed==planned,
    maxSessions=r['maxLive'],requests=r['requests'],unexpectedErrors=r['unexpected'],
    unexpectedPercent=r['unexpected']/max(1,r['requests'])*100,
    businessRefusals=r['business'],completedTrips=r['completedTrips'],durationSeconds=r['durationSeconds'],
    stages=r['stages'],operations=r['operations'],realtimeDelivery=r['realtimeDelivery'],gpsAge=r['gpsPositionAge'],
    backendSamples=len(backend),backendMaxCpuPercent=max((x['cpuPercent'] for x in backend),default=None),
    backendMaxRssMiB=max((x['rss']/1048576 for x in backend),default=None),
    backendMaxWindowEventLoopP95Ms=max((x['eventLoopP95Ms'] for x in backend),default=None),
    generatorMaxCpuPercent=max((x['cpuPercent'] for x in generator),default=None),
    generatorMaxRssMiB=max((x['rss']/1048576 for x in generator),default=None),
    databaseCounterDeltas={k:int(valid[-1][k])-int(valid[0][k]) for k in ['xact_commit','xact_rollback','blks_read','blks_hit','temp_bytes','deadlocks']} if valid else {},
    databaseSamples=len(valid),databaseSamplingErrors=[x for x in db if 'error'in x],
    databaseMaxima={k:max((int(x[k]) for x in valid),default=None) for k in ['numbackends','waiting','deadlocks','negative_balances','duplicate_assignments','duplicate_money']},
    postgresCpuPercentMax=max((float(x['docker']['CPUPerc'].rstrip('%')) for x in host if 'CPUPerc'in x['docker']),default=None),
    postgresMemorySamples=[x['docker'].get('MemUsage') for x in host],
    hostOomObservations=list(set(x['memory.events'] for x in host)))
summary['latencyGoals']={name:{'p95Ms':op['p95'],'targetMs':2000 if name in ['createPassengerOrder','acceptOrder','respondOrderOffer'] else 1000,'passed':op['p95']<=(2000 if name in ['createPassengerOrder','acceptOrder','respondOrderOffer'] else 1000)} for name,op in r['operations'].items()}
summary['errorGoalPassed']=summary['unexpectedPercent']<1
(p/'load-summary.json').write_text(json.dumps(summary,indent=2))
print(json.dumps({k:v for k,v in summary.items() if k not in ['operations','postgresMemorySamples','hostOomObservations','stages']},ensure_ascii=False))
