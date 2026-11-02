#!/usr/bin/python3
"""Chromium native-messaging host for the Quickshell Apple Music bridge.

Relays JSON both ways between the extension (length-prefixed frames on
stdio) and Quickshell's unix socket (one JSON object per line). Keeps retrying
the socket so a shell restart is transparent, and replays the last known
state to a freshly connected shell.
"""
import json
import os
import socket
import struct
import sys
import threading
import time

SOCK = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "quickshell-applemusic.sock")

out_lock = threading.Lock()
sock_lock = threading.Lock()
sock = None
last_state = None


def to_chromium(obj):
    data = json.dumps(obj, separators=(",", ":")).encode()
    with out_lock:
        sys.stdout.buffer.write(struct.pack("<I", len(data)) + data)
        sys.stdout.buffer.flush()


def drop():
    global sock
    with sock_lock:
        s, sock = sock, None
    if s:
        try:
            s.close()
        except OSError:
            pass


def to_shell(line):
    with sock_lock:
        s = sock
    if not s:
        return
    try:
        s.sendall(line)
    except OSError:
        drop()


def shell_loop():
    """Keep a connection to the shell; forward its lines to Chromium."""
    global sock
    while True:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            s.connect(SOCK)
        except OSError:
            s.close()
            time.sleep(2)
            continue
        with sock_lock:
            sock = s
        if last_state:
            to_shell(last_state)
        buf = b""
        try:
            while True:
                chunk = s.recv(65536)
                if not chunk:
                    break
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    if line.strip():
                        try:
                            to_chromium(json.loads(line))
                        except ValueError:
                            pass
        except OSError:
            pass
        drop()
        time.sleep(1)


def main():
    global last_state
    threading.Thread(target=shell_loop, daemon=True).start()
    stdin = sys.stdin.buffer
    while True:
        head = stdin.read(4)
        if len(head) < 4:
            return  # Chromium closed the port
        (n,) = struct.unpack("<I", head)
        raw = stdin.read(n)
        if len(raw) < n:
            return
        try:
            if json.loads(raw).get("type") == "state":
                last_state = raw + b"\n"
        except (ValueError, AttributeError):
            continue
        to_shell(raw + b"\n")


if __name__ == "__main__":
    main()
