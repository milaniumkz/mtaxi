from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import os
os.chdir(Path(__file__).resolve().parents[2] / 'build/web')
class SPA(SimpleHTTPRequestHandler):
    def do_GET(self):
        if not Path(self.translate_path(self.path)).is_file() and '.' not in self.path.rsplit('/',1)[-1]:
            self.path = '/index.html'
        return super().do_GET()
    def log_message(self,*args): pass
ThreadingHTTPServer(('127.0.0.1',18665), SPA).serve_forever()
