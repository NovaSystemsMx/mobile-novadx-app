/// Utilidades para normalizar las URLs de medios de X (hosts `twimg.com`).
///
/// X agrega un parametro `tag` a las variantes MP4 (`...mp4?tag=29`). Desde
/// finales de 2025 el CDN responde `403 Unauthorized` cuando se descarga el
/// archivo con ese parametro presente; al quitarlo el MP4 se sirve normal.
/// Es el mismo workaround que aplican cobalt y yt-dlp.
class TwimgUrl {
  const TwimgUrl._();

  static const _mediaHosts = {'video.twimg.com', 'video-s.twimg.com'};

  /// Devuelve la URL sin el parametro `tag` (solo en hosts de video de X).
  /// Si la URL no es de twimg o no trae `tag`, se regresa tal cual.
  static String clean(String rawUrl) {
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !_mediaHosts.contains(uri.host.toLowerCase())) {
      return trimmed;
    }
    if (!uri.queryParameters.containsKey('tag')) return trimmed;

    final query = uri.queryParameters.entries
        .where((e) => e.key != 'tag')
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');

    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo.isEmpty ? null : uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      query: query.isEmpty ? null : query,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    ).toString();
  }
}
