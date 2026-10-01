"""Genera un QR (PNG) apuntando a la URL de descarga del APK."""
import os
import qrcode

URL = "https://j8bvqsrh-8000.use2.devtunnels.ms/app-release.apk"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "logo", "apk_qr.png")

qr = qrcode.QRCode(
    version=None,
    error_correction=qrcode.constants.ERROR_CORRECT_M,
    box_size=12,
    border=4,
)
qr.add_data(URL)
qr.make(fit=True)

img = qr.make_image(fill_color="black", back_color="white")
img.save(OUT)
print("QR guardado:", OUT)
print("URL:", URL)
