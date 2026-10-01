"""Servidor minimo que sirve el APK con las cabeceras correctas para Android.

El http.server por defecto no envia el Content-Type que Android espera para
paquetes, lo que combinado con un tunel puede hacer que el navegador guarde el
archivo con extension/tipo equivocado y el instalador lo rechace.

Uso:  python tool/apk_server.py
Sirve en el puerto 8000 el archivo app-release.apk.
"""
import http.server
import os

PORT = 8000
APK_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "build", "app", "outputs", "flutter-apk",
)
APK_NAME = "app-release.apk"


class Handler(http.server.BaseHTTPRequestHandler):
    def _serve(self, body=True):
        path = os.path.join(APK_DIR, APK_NAME)
        if not os.path.exists(path):
            self.send_error(404, "APK no encontrado")
            return
        size = os.path.getsize(path)
        self.send_response(200)
        self.send_header("Content-Type", "application/vnd.android.package-archive")
        self.send_header("Content-Disposition", f'attachment; filename="{APK_NAME}"')
        self.send_header("Content-Length", str(size))
        self.end_headers()
        if body:
            with open(path, "rb") as f:
                self.wfile.write(f.read())

    def do_GET(self):
        self._serve(body=True)

    def do_HEAD(self):
        self._serve(body=False)

    def log_message(self, fmt, *args):
        print("[apk_server]", fmt % args)


if __name__ == "__main__":
    print(f"Sirviendo {APK_NAME} en el puerto {PORT}")
    print(f"Carpeta: {APK_DIR}")
    http.server.HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
