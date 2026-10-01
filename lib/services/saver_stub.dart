import 'dart:typed_data';

/// Implementacion por defecto (no deberia usarse en la practica). Existe para
/// que el import condicional siempre tenga un objetivo valido al analizar.
Future<String> saveBytes(Uint8List bytes, String fileName) {
  throw UnsupportedError('Plataforma no soportada para guardar archivos.');
}
