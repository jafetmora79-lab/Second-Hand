"""Serves build/web on http://localhost:8060 with caching turned off, so every reload gets the newest index.pck.
Run:  python tools/dev/serve_web.py"""
import http.server, os, functools

class NoCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, must-revalidate")
        super().end_headers()

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")
http.server.ThreadingHTTPServer(("127.0.0.1", 8060), functools.partial(NoCache, directory=root)).serve_forever()
