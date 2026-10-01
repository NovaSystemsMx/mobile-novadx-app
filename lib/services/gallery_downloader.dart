import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class GalleryDownloadException implements Exception {
  GalleryDownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DownloadProgress {
  const DownloadProgress({
    required this.received,
    required this.total,
    required this.status,
    required this.fileName,
  });

  final int received;
  final int total;
  final int status;
  final String fileName;

  static const successful = 8;
  static const failed = 16;
}

/// Descarga via DownloadManager nativo de Android.
///
/// Sigue en segundo plano aunque salgas de la app y Android muestra
/// la notificacion del sistema con el progreso y al terminar.
/// Guarda directo en Movies/NovaDX visible en galeria.
class GalleryDownloader {
  static const _channel = MethodChannel('novadx/gallery');

  static Future<int> enqueue({
    required String url,
    required String fileName,
  }) async {
    int? id;
    try {
      id = await _channel.invokeMethod<int>('enqueueDownload', {
        'url': url,
        'fileName': fileName,
      });
    } on PlatformException catch (e) {
      throw GalleryDownloadException(e.message ?? 'No pude iniciar la descarga.');
    }
    if (id == null) throw GalleryDownloadException('No pude iniciar la descarga.');
    return id;
  }

  static Future<DownloadProgress> query(int id) async {
    final info = await _channel.invokeMethod<Map<Object?, Object?>>(
      'queryProgress',
      {'id': id},
    );
    if (info == null) throw GalleryDownloadException('Sin respuesta del sistema.');
    return DownloadProgress(
      received: (info['received'] as num?)?.toInt() ?? 0,
      total: (info['total'] as num?)?.toInt() ?? -1,
      status: (info['status'] as num?)?.toInt() ?? 2,
      fileName: info['fileName'] as String? ?? '',
    );
  }

  static Future<void> cancel(int id) async {
    try {
      await _channel.invokeMethod('cancelDownload', {'id': id});
    } on PlatformException {
      // Ya termino o no existe: no es error para la UI.
    }
  }

  static Future<void> open(int id) async {
    try {
      await _channel.invokeMethod('openDownload', {'id': id});
    } on PlatformException {
      throw GalleryDownloadException('No encontre una app para abrir el video.');
    }
  }

  static Future<void> share(int id) async {
    try {
      await _channel.invokeMethod('shareDownload', {'id': id});
    } on PlatformException {
      throw GalleryDownloadException('No pude compartir el video.');
    }
  }

  /// Texto compartido desde otra app (X) hacia NovaDX, si existe.
  static Future<String?> getSharedText() async {
    try {
      return await _channel.invokeMethod<String>('getSharedText');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Peso estimado del mp4 con un HEAD rapido. Null si no se pudo saber.
  static Future<String?> estimateSizeLabel(String url) async {
    try {
      final res = await http
          .head(Uri.parse(url), headers: {'User-Agent': 'downloader_x/1.0'})
          .timeout(const Duration(seconds: 8));
      final raw = res.headers['content-length'];
      final bytes = int.tryParse(raw ?? '');
      if (bytes == null || bytes <= 0) return null;
      if (bytes >= 1048576) {
        return 'Aprox ${(bytes / 1048576).toStringAsFixed(1)} MB';
      }
      return 'Aprox ${(bytes / 1024).toStringAsFixed(0)} KB';
    } catch (_) {
      return null;
    }
  }
}
