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
          'https://twitter.com/user/status/987654321'),
      isTrue,
    );
    expect(XVideoResolver.looksLikeXUrl('https://youtube.com/watch?v=abc'),
        isFalse);
    expect(XVideoResolver.looksLikeXUrl('hola mundo'), isFalse);
  });

  test('Quita el parametro tag de los mp4 de twimg', () {
    const raw =
        'https://video.twimg.com/amplify_video/123/vid/avc1/1280x720/a.mp4?tag=29';
    expect(
      TwimgUrl.clean(raw),
      'https://video.twimg.com/amplify_video/123/vid/avc1/1280x720/a.mp4',
    );
  });

  test('Conserva otros parametros y no toca URLs ajenas', () {
    expect(
      TwimgUrl.clean(
        'https://video-s.twimg.com/amplify_video/1/vid/a.mp4?tag=16&v=cfc',
      ),
      'https://video-s.twimg.com/amplify_video/1/vid/a.mp4?v=cfc',
    );
    const other = 'https://example.com/video.mp4?tag=29';
    expect(TwimgUrl.clean(other), other);
  });

  test('Deja intacta una URL de twimg sin tag', () {
    const clean = 'https://video.twimg.com/amplify_video/1/vid/a.mp4';
    expect(TwimgUrl.clean(clean), clean);
  });
}
