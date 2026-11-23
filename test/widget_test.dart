import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:downloader_x/main.dart';
import 'package:downloader_x/services/twimg_url.dart';
import 'package:downloader_x/services/x_video_resolver.dart';
import 'package:downloader_x/widgets/block_logo.dart';

void main() {
  testWidgets('Muestra el logo y el input al iniciar', (tester) async {
    await tester.pumpWidget(const DownloaderXApp());
    await tester.pump();

    // El logo (RichText) y el campo de entrada estan presentes.
    expect(find.byType(BlockLogo), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  test('Valida enlaces de X/Twitter correctamente', () {
    expect(
      XVideoResolver.looksLikeXUrl('https://x.com/user/status/123456789'),
      isTrue,
    );
    expect(
      XVideoResolver.looksLikeXUrl(
          'https://twitter.com/user/status/987654321?p=test&s=20'),
      isTrue,
    );
    expect(XVideoResolver.looksLikeXUrl('https://youtube.com/watch?v=abc'),
        isFalse);
    expect(XVideoResolver.looksLikeXUrl('hola mundo'), isFalse);
  });

  test('Limpia todos los parametros de la URL de X que se pega o introduce', () {
    expect(
      XVideoResolver.cleanUrl('https://x.com/user/status/123456789?p=1&s=20'),
      'https://x.com/user/status/123456789',
    );
    expect(
      XVideoResolver.cleanUrl(
        'https://twitter.com/user/status/987654321?t=abc#fragment',
      ),
      'https://twitter.com/user/status/987654321',
    );
    expect(
      XVideoResolver.cleanUrl('https://x.com/user/status/123456789'),
      'https://x.com/user/status/123456789',
    );
    expect(
      XVideoResolver.cleanUrl('hola mundo'),
      'hola mundo',
    );
  });

  test('Quita subrutas como /video/1 y parametros de enlaces compartidos', () {
    // Caso real: enlace copiado desde la app de X.
    expect(
      XVideoResolver.cleanUrl(
        'https://x.com/chodanarchive/status/2124247665311699211/video/1'
        '?a=53wy31crWffrTHUdL50&s=19',
      ),
      'https://x.com/chodanarchive/status/2124247665311699211',
    );
    expect(
      XVideoResolver.cleanUrl(
        'https://x.com/user/status/123456789/photo/1',
      ),
      'https://x.com/user/status/123456789',
    );
    expect(
      XVideoResolver.cleanUrl(
        'https://mobile.twitter.com/user/status/123456789/video/1?s=20',
      ),
      'https://twitter.com/user/status/123456789',
    );
    expect(
      XVideoResolver.cleanUrl('https://x.com/i/web/status/123456789?s=20'),
      'https://x.com/i/web/status/123456789',
    );
  });

  test('Extrae el enlace de X cuando viene rodeado de texto', () {
    expect(
      XVideoResolver.cleanUrl(
        'Mira este video https://x.com/user/status/123/video/1?s=19 que bueno',
      ),
      'https://x.com/user/status/123',
    );
    expect(
      XVideoResolver.looksLikeXUrl(
        'Mira esto: https://x.com/user/status/123/video/1?s=19',
      ),
      isTrue,
    );
  });

  test('Quita todos los parametros (tag, p, v, etc.) de las URLs de twimg', () {
    const rawTag =
        'https://video.twimg.com/amplify_video/123/vid/avc1/1280x720/a.mp4?tag=29';
    expect(
      TwimgUrl.clean(rawTag),
      'https://video.twimg.com/amplify_video/123/vid/avc1/1280x720/a.mp4',
    );

    const rawMultiple =
        'https://video-s.twimg.com/amplify_video/1/vid/a.mp4?tag=16&v=cfc&p=test';
    expect(
      TwimgUrl.clean(rawMultiple),
      'https://video-s.twimg.com/amplify_video/1/vid/a.mp4',
    );

    const rawParamP =
        'https://video.twimg.com/amplify_video/123/vid/avc1/1280x720/a.mp4?p=example';
    expect(
      TwimgUrl.clean(rawParamP),
      'https://video.twimg.com/amplify_video/123/vid/avc1/1280x720/a.mp4',
    );
  });

  test('No toca URLs ajenas a twimg', () {
    const other = 'https://example.com/video.mp4?tag=29&p=123';
    expect(TwimgUrl.clean(other), other);
  });

  test('Deja intacta una URL de twimg sin parametros', () {
    const clean = 'https://video.twimg.com/amplify_video/1/vid/a.mp4';
    expect(TwimgUrl.clean(clean), clean);
  });

  test('Resuelve todos los videos de un post, no solo el primero', () async {
    const body = '''
    {
      "tweet": {
        "media": {
          "videos": [
            {
              "url": "https://video.twimg.com/a.mp4?tag=1",
              "thumbnail_url": "https://pbs.twimg.com/1.jpg",
              "width": 1280,
              "height": 720,
              "variants": [
                {"content_type": "video/mp4", "bitrate": 832000,
                 "url": "https://video.twimg.com/a480.mp4?tag=1"},
                {"content_type": "video/mp4", "bitrate": 2176000,
                 "url": "https://video.twimg.com/a720.mp4?tag=1"},
                {"content_type": "application/x-mpegURL",
                 "url": "https://video.twimg.com/a.m3u8"}
              ]
            },
            {
              "url": "https://video.twimg.com/b.mp4",
              "thumbnail_url": "https://pbs.twimg.com/2.jpg",
              "width": 640,
              "height": 360,
              "variants": [
                {"content_type": "video/mp4", "bitrate": 550000,
                 "url": "https://video.twimg.com/b360.mp4"}
              ]
            },
            {}
          ]
        }
      }
    }
    ''';
    final resolver = XVideoResolver(
      client: MockClient((request) async => http.Response(body, 200)),
    );

    final videos =
        await resolver.resolveAll('https://x.com/user/status/123?s=20');

    expect(videos, hasLength(2));
    expect(videos.map((v) => v.index), [0, 1]);
    expect(
      videos.map((v) => v.downloadUrl),
      [
        'https://video.twimg.com/a720.mp4',
        'https://video.twimg.com/b360.mp4',
      ],
    );
    expect(videos.first.bitrate, 2176000);
    expect(videos.first.thumbnailUrl, 'https://pbs.twimg.com/1.jpg');

    // El metodo antiguo sigue devolviendo el primero para compatibilidad.
    final first = await resolver.resolve('https://x.com/user/status/123');
    expect(first.downloadUrl, videos.first.downloadUrl);
  });
}
