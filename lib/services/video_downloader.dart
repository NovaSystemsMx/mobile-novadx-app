import 'dart:typed_data';
import 'package:http/http.dart' as http;

// Selecciona la implementacion correcta segun la plataforma en tiempo de
// compilacion: en web usa la descarga del navegador, en nativo usa archivos.
import 'saver_stub.dart'
    if (dart.library.js_interop) 'saver_web.dart'
    if (dart.library.io) 'saver_native.dart';

class DownloadException implements Exception {
  DownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Descarga el mp4 desde una URL directa, reportando progreso, y lo guarda
/// usando el mecanismo propio de cada plataforma (navegador o disco).
class VideoDownloader {
  VideoDownloader({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// [onProgress] recibe un valor de 0.0 a 1.0, o null si el servidor no
  /// informa el tamano total (progreso indeterminado).
  Future<String> download(
    String url, {
    required String fileName,
    void Function(double? progress)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = 'downloader_x/1.0';

    http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } catch (_) {
      throw DownloadException('No pude iniciar la descarga del video.');
    }

    if (response.statusCode != 200) {
      throw DownloadException(
        'La descarga fallo con estado ${response.statusCode}.',
      );
    }

    final total = response.contentLength;
    final chunks = <int>[];
    int received = 0;

    await for (final chunk in response.stream) {
      chunks.addAll(chunk);
      received += chunk.length;
      if (onProgress != null) {
        onProgress(total != null && total > 0 ? received / total : null);
      }
    }

    final bytes = Uint8List.fromList(chunks);
    if (bytes.isEmpty) {
      throw DownloadException('El video descargado esta vacio.');
    }

    // saveBytes viene de la implementacion especifica de plataforma.
    return saveBytes(bytes, fileName);
  }

  void dispose() => _client.close();
}
