import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
