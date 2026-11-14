#!/usr/bin/env python3
"""Local-only Godot Web test server; Python 3.9+ and standard library only."""

import argparse
import email.utils
import functools
import http.server
import os
from pathlib import Path
import shutil
import sys
import threading
import urllib.parse
import webbrowser
import zlib


MIME_TYPES = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
    ".png": "image/png",
    ".ico": "image/x-icon",
    ".json": "application/json; charset=utf-8",
    ".txt": "text/plain; charset=utf-8",
}
GZIP_EXTENSIONS = {".html", ".js", ".wasm", ".pck"}
CHUNK_SIZE = 64 * 1024


def accepts_gzip(header):
    """Honor explicit gzip;q=0 even if a wildcard is also present."""
    qualities = {}
    for item in header.split(","):
        parts = item.strip().lower().split(";")
        name, quality = parts[0], 1.0
        for option in parts[1:]:
            key, separator, value = option.strip().partition("=")
            if separator and key == "q":
                try:
                    quality = float(value)
                except ValueError:
                    quality = 0.0
        qualities[name] = quality if 0.0 <= quality <= 1.0 else 0.0
    return qualities.get("gzip", qualities.get("*", 0.0)) > 0.0


def etag_matches(header, etag):
    def weak_value(value):
        return value.strip().removeprefix("W/")
    return any(value.strip() == "*" or weak_value(value) == weak_value(etag)
               for value in header.split(","))


class LocalWebHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "BeatCardLocal/1.0"

    def __init__(self, *args, directory, **kwargs):
        self.root = Path(directory).resolve(strict=True)
        super().__init__(*args, **kwargs)

    def do_GET(self):
        self._serve(head_only=False)

    def do_HEAD(self):
        self._serve(head_only=True)

    def _resolve_file(self):
        try:
            url = urllib.parse.urlsplit(self.path)
            if url.scheme or url.netloc:
                raise ValueError("absolute URL")
            decoded = urllib.parse.unquote(url.path, errors="strict").replace("\\", "/")
            if "\x00" in decoded or ".." in decoded.split("/"):
                raise ValueError("invalid path")
            relative = decoded.lstrip("/")
            path = (self.root / relative).resolve()
            if not path.is_relative_to(self.root):
                raise ValueError("path outside package")
            if path.is_dir():
                path = (path / "index.html").resolve()
            if relative == "favicon.ico" and not path.exists():
                path = (self.root / "app-icon.png").resolve()
            if not path.is_relative_to(self.root):
                raise ValueError("path outside package")
            return path
        except (ValueError, UnicodeError, OSError):
            self.send_error(403, "Path is outside the package")
            return None

    def _not_modified(self, stat, etag):
        if_none_match = self.headers.get("If-None-Match")
        if if_none_match is not None:
            return etag_matches(if_none_match, etag)
        if_modified_since = self.headers.get("If-Modified-Since")
        if if_modified_since:
            try:
                since = email.utils.parsedate_to_datetime(if_modified_since)
                if since.tzinfo is not None:
                    return int(stat.st_mtime) <= int(since.timestamp())
            except (ValueError, TypeError, OverflowError):
                pass
        return False

    def _cache_headers(self, stat, etag):
        self.send_header("ETag", etag)
        self.send_header("Last-Modified", self.date_time_string(stat.st_mtime))
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Vary", "Accept-Encoding")
        self.send_header("X-Content-Type-Options", "nosniff")

    def _serve(self, head_only):
        path = self._resolve_file()
        if path is None:
            return
        try:
            stream = path.open("rb")
        except (FileNotFoundError, IsADirectoryError, NotADirectoryError):
            self.send_error(404, "File not found")
            return
        except (PermissionError, OSError):
            self.send_error(403, "Cannot read file")
            return
        try:
            with stream:
                stat = os.fstat(stream.fileno())
                compressed = (path.suffix.lower() in GZIP_EXTENSIONS
                              and accepts_gzip(self.headers.get("Accept-Encoding", "")))
                representation = "gzip" if compressed else "identity"
                etag = 'W/"%x-%x-%s"' % (stat.st_mtime_ns, stat.st_size, representation)
                if self._not_modified(stat, etag):
                    self.send_response(304)
                    self._cache_headers(stat, etag)
                    self.end_headers()
                    return
                self.send_response(200)
                self.send_header("Content-Type", MIME_TYPES.get(path.suffix.lower(),
                                                                 "application/octet-stream"))
                self._cache_headers(stat, etag)
                if compressed:
                    self.send_header("Content-Encoding", "gzip")
                    self.send_header("Transfer-Encoding", "chunked")
                else:
                    self.send_header("Content-Length", str(stat.st_size))
                self.end_headers()
                if head_only:
                    return
                if compressed:
                    self._copy_gzip(stream, stat.st_size)
                else:
                    shutil.copyfileobj(stream, self.wfile, length=CHUNK_SIZE)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            self.close_connection = True

    def _copy_gzip(self, stream, original_size):
        compressor = zlib.compressobj(level=3, wbits=31)
        transferred = 0

        def write_chunk(data):
            nonlocal transferred
            if data:
                self.wfile.write(("%x\r\n" % len(data)).encode("ascii"))
                self.wfile.write(data)
                self.wfile.write(b"\r\n")
                transferred += len(data)

        while True:
            block = stream.read(CHUNK_SIZE)
            if not block:
                break
            write_chunk(compressor.compress(block))
        write_chunk(compressor.flush())
        self.wfile.write(b"0\r\n\r\n")
        self.log_message("gzip payload: %d -> %d bytes", original_size, transferred)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--port", type=int, default=18765)
    parser.add_argument("--open", action="store_true", help="Open the local game in a browser")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("--port must be between 1 and 65535")
    try:
        directory = args.directory.resolve(strict=True)
        if not directory.is_dir() or not (directory / "index.html").is_file():
            parser.error("--directory must contain index.html")
        handler = functools.partial(LocalWebHandler, directory=directory)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    except OSError as error:
        print("Cannot start local Web test server: %s" % error, file=sys.stderr)
        return 1
    url = "http://localhost:%d/" % args.port
    print("Local Web test: %s" % url, flush=True)
    print("Keep this window open. Press Ctrl+C to stop.", flush=True)
    print("Only this computer can connect. Python standard library; no Godot required.", flush=True)
    if args.open:
        opener = threading.Timer(0.3, webbrowser.open, args=(url,))
        opener.daemon = True
        opener.start()
    try:
        with server:
            server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        print("\nLocal Web server stopped.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
