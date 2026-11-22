import 'dart:convert';
import 'package:http/http.dart' as http;

import 'twimg_url.dart';

/// Resultado de resolver un tweet: la URL directa del mp4 y metadatos útiles.
class ResolvedVideo {
  const ResolvedVideo({
    required this.downloadUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.bitrate,
  });

  final String downloadUrl;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int? bitrate;
}

class XResolverException implements Exception {
  XResolverException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Motor de resolución de videos de X (Twitter), aislado del resto de la app.
///
/// Hoy usa el servicio publico de fxtwitter/vxtwitter, que expone un JSON
/// con la URL directa del mp4 sin necesidad de API keys. Si algun dia quieres
/// cambiar de metodo (API oficial, otro extractor, etc.), solo se toca esta
/// clase: la UI no sabe como se obtiene el video.
class XVideoResolver {
  XVideoResolver({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Encuentra un enlace de X dentro de un texto y captura el usuario y el
  /// id del post. Acepta x.com/twitter.com (con o sin `www.`/`mobile.`),
  /// variantes como `/usuario/status/123/video/1` y `/i/web/status/123`.
  static final RegExp _xUrlPattern = RegExp(
    r'(?:https?:\/\/)?(?:www\.|mobile\.)?(?:twitter|x)\.com\/'
    r'(?:([A-Za-z0-9_]+)|i\/web)\/status\/(\d+)',
    caseSensitive: false,
  );

  /// Detecta si un texto contiene un enlace de un tweet.
  static bool looksLikeXUrl(String input) {
    return _xUrlPattern.hasMatch(input.trim());
  }

  /// Limpia un enlace de X dejando solo la URL canonica del post:
  /// `https://x.com/usuario/status/id`. Descarta parametros de consulta
  /// (`?a=`, `?s=`, `?t=`...), fragmentos, subrutas como `/video/1` o
  /// `/photo/1`, y texto que rodee al enlace.
  static String cleanUrl(String input) {
    final trimmed = input.trim();
    final match = _xUrlPattern.firstMatch(trimmed);
    if (match == null) return trimmed;

    final handle = match.group(1) ?? 'i/web';
    final statusId = match.group(2)!;
    final host = match.group(0)!.toLowerCase().contains('twitter.com')
        ? 'twitter.com'
        : 'x.com';

    return 'https://$host/$handle/status/$statusId';
  }

  /// Extrae el id numerico del status del tweet.
  static String? _extractStatusId(String url) {
    final match = RegExp(r'status\/(\d+)').firstMatch(url);
    return match?.group(1);
  }

  /// Reescribe cualquier enlace de x.com/twitter.com hacia el host del
  /// servicio de extraccion, preservando la ruta del status.
  Uri _buildApiUri(String rawUrl) {
    final uri = Uri.parse(cleanUrl(rawUrl));
    // api.fxtwitter.com respeta la misma ruta /usuario/status/id
    return Uri(
      scheme: 'https',
      host: 'api.fxtwitter.com',
      path: uri.path,
    );
  }

  /// Resuelve el enlace de un tweet a la mejor variante de video disponible.
  Future<ResolvedVideo> resolve(String rawUrl) async {
    final cleanedUrl = cleanUrl(rawUrl);
    if (!looksLikeXUrl(cleanedUrl)) {
      throw XResolverException(
        'El enlace no parece un post de X. Debe verse como '
        'https://x.com/usuario/status/123...',
      );
    }
    if (_extractStatusId(cleanedUrl) == null) {
      throw XResolverException('No pude identificar el id del post en el enlace.');
    }

    final apiUri = _buildApiUri(cleanedUrl);

    http.Response res;
    try {
      res = await _client.get(
        apiUri,
        headers: {'User-Agent': 'downloader_x/1.0'},
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw XResolverException('No pude conectar con el servicio de extraccion.');
    }

    if (res.statusCode == 404) {
      throw XResolverException('El post no existe o fue eliminado.');
    }
    if (res.statusCode != 200) {
      throw XResolverException(
        'El servicio respondio con estado ${res.statusCode}.',
      );
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw XResolverException('La respuesta del servicio no fue valida.');
    }

    final tweet = json['tweet'] as Map<String, dynamic>?;
    if (tweet == null) {
      throw XResolverException('El post no contiene datos utilizables.');
    }

    final media = tweet['media'] as Map<String, dynamic>?;
    final videos = media?['videos'] as List<dynamic>?;

    if (videos == null || videos.isEmpty) {
      throw XResolverException('Este post no contiene ningun video.');
    }

    // Tomamos el primer video y elegimos la mejor variante por bitrate.
    final video = videos.first as Map<String, dynamic>;
    final variants = video['variants'] as List<dynamic>?;

    String? bestUrl;
    int bestBitrate = -1;

    if (variants != null && variants.isNotEmpty) {
      for (final v in variants.cast<Map<String, dynamic>>()) {
        final type = (v['content_type'] ?? '').toString();
        if (!type.contains('mp4')) continue;
        final br = (v['bitrate'] as num?)?.toInt() ?? 0;
        if (br > bestBitrate) {
          bestBitrate = br;
          bestUrl = v['url'] as String?;
        }
      }
    }

    // Fallback al url directo que a veces trae el objeto video.
    bestUrl ??= video['url'] as String?;

    if (bestUrl == null || bestUrl.isEmpty) {
      throw XResolverException('No encontre una URL de video descargable.');
    }

    return ResolvedVideo(
      // El CDN de X devuelve 403 si el mp4 lleva el parametro `tag`.
      downloadUrl: TwimgUrl.clean(bestUrl),
      thumbnailUrl: video['thumbnail_url'] as String?,
      width: (video['width'] as num?)?.toInt(),
      height: (video['height'] as num?)?.toInt(),
      bitrate: bestBitrate > 0 ? bestBitrate : null,
    );
  }

  void dispose() => _client.close();
}
