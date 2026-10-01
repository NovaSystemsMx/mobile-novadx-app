import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Guarda el video y lo publica en la galeria dentro de Movies/NovaDX.
///
/// Flujo en Android:
/// 1. Escribe los bytes a un temporal interno.
/// 2. Invoca el canal nativo `novadx/gallery` que lo mueve via MediaStore a
///    `Movies/NovaDX` (visible en galeria, como hacen las apps de Facebook).
/// 3. Si el canal falla (desktop/tests), cae al directorio externo de la app.
Future<String> saveBytes(Uint8List bytes, String fileName) async {
  final tmp = await getTemporaryDirectory();
  final tmpFile = File('${tmp.path}${Platform.pathSeparator}$fileName');
  await tmpFile.writeAsBytes(bytes, flush: true);

  try {
    const channel = MethodChannel('novadx/gallery');
    final dest = await channel.invokeMethod<String>('saveVideo', {
      'path': tmpFile.path,
      'fileName': fileName,
    });
    if (dest != null && dest.isNotEmpty) {
      if (dest.startsWith('content://')) {
        return 'Galeria / Movies/NovaDX/$fileName';
      }
      return dest;
    }
  } on PlatformException {
    // Cae al fallback de abajo.
  } on MissingPluginException {
    // Tests o desktop sin canal nativo.
  }

  try {
    final dir =
        (await getExternalStorageDirectory()) ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await tmpFile.copy(file.path);
    await tmpFile.delete();
    return file.path;
  } catch (_) {
    return tmpFile.path;
  }
}
