"""Read-only resource sampling for the explicitly named local test container."""
import json, os, subprocess, time
from pathlib import Path
out = Path(os.environ.get('MTAXI_AUDIT_RESOURCE_DIR', str(Path(__file__).resolve().parents[2] / 'output/full-audit')))
env = {k:v for k,v in os.environ.items() if k not in ['DOCKER_HOST','DOCKER_CONTEXT','DOCKER_TLS','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH']}
for _ in range(180):
    result = subprocess.run(['docker','--host=unix:///var/run/docker.sock','stats','--no-stream','--format','{{json .}}','mtaxi-audit-pg'],env=env,capture_output=True,text=True,timeout=20)
    sample={'at':time.time(),'docker':json.loads(result.stdout) if result.returncode==0 else {'error':result.stderr[:300]}}
    for name in ['cpu.stat','cpu.max','memory.current','memory.max','memory.events']:
        sample[name]=Path('/sys/fs/cgroup',name).read_text().strip()
    with (out/os.environ.get('MTAXI_AUDIT_RESOURCE_FILE','load-resource-host.jsonl')).open('a') as f:f.write(json.dumps(sample)+'\n')
    log=out/os.environ.get('MTAXI_AUDIT_LOAD_LOG','load-latest.log')
    if log.exists() and '"finished":true' in log.read_text():break
    time.sleep(15)
