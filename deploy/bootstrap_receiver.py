"""One-use HTTPS-proxied receiver for the existing FCM account. No secret logging."""
import hmac
import json
import os
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

BASE = Path('/etc/mtaxi')
class Receiver(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass
    def do_POST(self):
        token_path = BASE / 'bootstrap-token'
        expected = token_path.read_text().strip() if token_path.exists() else ''
        supplied = self.headers.get('Authorization', '')
        if self.path != '/__mtaxi_initial_firebase' or not expected or not hmac.compare_digest(supplied, 'Bearer ' + expected):
            self.send_error(403)
            return
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size < 65536:
                raise ValueError()
            account = json.loads(self.rfile.read(size))
            if account.get('project_id') != 'mtaxi-52990' or not account.get('private_key', '').startswith('-----BEGIN PRIVATE KEY-----') or not account.get('client_email'):
                raise ValueError()
            path = BASE / 'firebase.json'
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, 'w') as file:
                json.dump(account, file)
            token_path.unlink()
        except (ValueError, OSError, TypeError):
            self.send_error(400)
            return
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"ok":true}')
        threading.Thread(target=self.server.shutdown, daemon=True).start()

if __name__ == '__main__':
    HTTPServer(('127.0.0.1', 8099), Receiver).serve_forever()
