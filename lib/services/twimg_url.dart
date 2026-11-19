/// Utilidades para normalizar las URLs de medios de X (hosts `twimg.com`).
///
/// X y servicios de extraccion agregan parametros (?tag=, ?p=, etc.) a las
/// variantes MP4. El CDN de X (`twimg.com`) responde `403 Unauthorized` o
/// rechaza la descarga cuando se incluye cualquier parametro de consulta.
/// Al remover todos los parametros y fragmentos, el MP4 se descarga correctamente.
class TwimgUrl {
  const TwimgUrl._();

  static const _mediaHosts = {'video.twimg.com', 'video-s.twimg.com'};

  /// Devuelve la URL limpia sin ningun parametro de consulta ni fragmento
  /// (solo en hosts de medios de twimg).
  /// Si la URL no es de twimg, se regresa tal cual.
  static String clean(String rawUrl) {
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    final host = uri.host.toLowerCase();
    final isTwimg = _mediaHosts.contains(host) ||
        host == 'twimg.com' ||
        host.endsWith('.twimg.com');

    if (!isTwimg) {
      return trimmed;
    }

    if (!uri.hasQuery && uri.fragment.isEmpty) return trimmed;

    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo.isEmpty ? null : uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
  }
}
