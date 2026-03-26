import http.server
import ssl
import os

os.chdir(os.path.dirname(os.path.abspath(__file__)))

handler = http.server.SimpleHTTPRequestHandler
handler.extensions_map.update({
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
    ".js": "application/javascript",
})

server = http.server.HTTPServer(("0.0.0.0", 8443), handler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain("cert.pem", "key.pem")
server.socket = context.wrap_socket(server.socket, server_side=True)

print("HTTPS server running at https://0.0.0.0:8443")
print("Open on phone: https://192.168.68.69:8443/index.html")
server.serve_forever()
