import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

/// En web disparamos una descarga del navegador creando un Blob y un enlace
/// temporal con el atributo download.
Future<String> saveBytes(Uint8List bytes, String fileName) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'video/mp4'),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);

  return 'Descargas del navegador';
}
