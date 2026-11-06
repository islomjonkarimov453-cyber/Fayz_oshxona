#!/usr/bin/env python3
"""Oddiy TLS proxy: HTTPS (8443) -> HTTP Django (8000).

PWA o'rnatish uchun HTTPS kerak. Django runserver SSL'ni qo'llamaydi,
shuning uchun bu proxy sertifikatni tugatib, so'rovlarni Django'ga uzatadi.
"""
import socket
import ssl
import threading
import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CERT = os.path.join(BASE_DIR, 'certs', 'cert.pem')
KEY = os.path.join(BASE_DIR, 'certs', 'key.pem')
LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8443
TARGET = ('127.0.0.1', int(sys.argv[2])) if len(sys.argv) > 2 else ('127.0.0.1', 8000)

context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(CERT, KEY)


def pipe(src, dst):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        try:
            dst.shutdown(socket.SHUT_WR)
        except OSError:
            pass


def handle(client):
    try:
        upstream = socket.create_connection(TARGET)
    except OSError:
        client.close()
        return
    t = threading.Thread(target=pipe, args=(client, upstream), daemon=True)
    t.start()
    pipe(upstream, client)
    upstream.close()
    client.close()


def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', LISTEN_PORT))
    server.listen(50)
    print(f'HTTPS proxy: https://0.0.0.0:{LISTEN_PORT} -> http://{TARGET[0]}:{TARGET[1]}', flush=True)
    while True:
        client, _ = server.accept()
        try:
            tls_client = context.wrap_socket(client, server_side=True)
        except ssl.SSLError:
            client.close()
            continue
        threading.Thread(target=handle, args=(tls_client,), daemon=True).start()


if __name__ == '__main__':
    main()
