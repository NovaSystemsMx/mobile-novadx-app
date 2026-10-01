import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:downloader_x/main.dart';
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
}
