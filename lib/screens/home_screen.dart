import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/gallery_downloader.dart';
import '../services/x_video_resolver.dart';
import '../services/video_downloader.dart';
import '../theme.dart';
import '../widgets/block_logo.dart';

enum DownloadStatus { idle, resolving, preview, downloading, done, error }

/// Pantalla principal: pega el link, se busca solo y aparece Descargar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _resolver = XVideoResolver();
  final _downloader = VideoDownloader();

  DownloadStatus _status = DownloadStatus.idle;
  double? _progress;
  String _message = '';

  ResolvedVideo? _preview;
  String _fileName = '';
  String? _sizeLabel;
  String _lastResolvedUrl = '';

  Timer? _debounce;
  bool _cancelRequested = false;
  String _lastFileName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(() {
      if (!mounted) return;
      setState(() {});
      _scheduleAutoResolve();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _focusNode.requestFocus();
      await _checkSharedText();
      await _maybeAutofill();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _resolver.dispose();
    _downloader.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkSharedText();
  }

  /// Link compartido desde X u otra app.
  Future<void> _checkSharedText() async {
    if (!Platform.isAndroid) return;
    final text = await GalleryDownloader.getSharedText();
    if (text == null || !mounted) return;
    final match = RegExp(r'https?://\S+').firstMatch(text);
    final url = match?.group(0) ?? '';
    if (url.isNotEmpty &&
        XVideoResolver.looksLikeXUrl(url) &&
        _controller.text.trim() != url &&
        _status != DownloadStatus.downloading &&
        _status != DownloadStatus.resolving) {
      _controller.text = url;
    }
  }

  /// Si el portapapeles ya trae un link de X, lo pone (se resuelve solo).
  Future<void> _maybeAutofill() async {
    if (_controller.text.trim().isNotEmpty) return;
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty && XVideoResolver.looksLikeXUrl(text) && mounted) {
        _controller.text = text;
      }
    } catch (_) {
      // Portapapeles no disponible: no pasa nada.
    }
  }

  /// La busqueda arranca sola al detectar un link valido, sin tocar nada.
  void _scheduleAutoResolve() {
    _debounce?.cancel();
    final text = _controller.text.trim();
    if (!XVideoResolver.looksLikeXUrl(text)) return;
    if (text == _lastResolvedUrl) return;
    if (_status == DownloadStatus.resolving ||
        _status == DownloadStatus.downloading ||
        _status == DownloadStatus.preview) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_controller.text.trim() != text) return;
      _start();
    });
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) return;
      _controller.text = text;
      _focusNode.requestFocus();
    } catch (_) {
      // Sin acceso al portapapeles.
    }
  }

  /// Busca el video por detras. Al encontrarlo aparece el boton Descargar.
  Future<void> _start() async {
    final input = _controller.text.trim();
    if (input.isEmpty ||
        _status == DownloadStatus.resolving ||
        _status == DownloadStatus.downloading) {
      return;
    }
    if (input == _lastResolvedUrl &&
        _status == DownloadStatus.preview &&
        _preview != null) {
      return;
    }

    if (!XVideoResolver.looksLikeXUrl(input)) {
      setState(() {
        _status = DownloadStatus.error;
        _message = 'Ese enlace no es de X.';
      });
      return;
    }

    setState(() {
      _status = DownloadStatus.resolving;
      _progress = null;
      _message = '';
      _preview = null;
    });

    try {
      final resolved = await _resolver.resolve(input);
      final statusId =
          RegExp(r'status\/(\d+)').firstMatch(input)?.group(1) ?? 'video';
      final fileName = 'x_$statusId.mp4';
      final size = await GalleryDownloader.estimateSizeLabel(
        resolved.downloadUrl,
      );
      if (!mounted) return;
      setState(() {
        _status = DownloadStatus.preview;
        _preview = resolved;
        _fileName = fileName;
        _sizeLabel = size;
        _lastResolvedUrl = input;
      });
    } on XResolverException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = DownloadStatus.error;
        _message = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = DownloadStatus.error;
        _message = 'Sin conexion. Intentalo de nuevo.';
      });
    }
  }

  /// Descarga el video ya localizado.
  Future<void> _download() async {
    final video = _preview;
    if (video == null || _status == DownloadStatus.downloading) return;

    setState(() {
      _status = DownloadStatus.downloading;
      _progress = null;
      _cancelRequested = false;
    });

    if (!Platform.isAndroid) {
      try {
        await _downloader.download(
          video.downloadUrl,
          fileName: _fileName,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        setState(() {
          _status = DownloadStatus.done;
          _progress = 1.0;
          _lastFileName = _fileName;
        });
        _controller.clear();
        _lastResolvedUrl = '';
        _focusNode.requestFocus();
      } catch (_) {
        if (!mounted) return;
        HapticFeedback.lightImpact();
        setState(() {
          _status = DownloadStatus.error;
          _message = 'La descarga fallo.';
        });
      }
      return;
    }

    int id;
    try {
      id = await GalleryDownloader.enqueue(
        url: video.downloadUrl,
        fileName: _fileName,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = DownloadStatus.error;
        _message = 'No pude iniciar la descarga.';
      });
      return;
    }

    while (mounted) {
      if (_cancelRequested) {
        await GalleryDownloader.cancel(id);
        setState(() {
          _status = DownloadStatus.idle;
          _progress = null;
          _preview = null;
          _lastResolvedUrl = '';
        });
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
      DownloadProgress info;
      try {
        info = await GalleryDownloader.query(id);
      } catch (_) {
        continue;
      }
      if (info.status == DownloadProgress.successful) {
        HapticFeedback.mediumImpact();
        setState(() {
          _status = DownloadStatus.done;
          _progress = 1.0;
          _lastFileName =
              info.fileName.isNotEmpty ? info.fileName : _fileName;
        });
        _controller.clear();
        _lastResolvedUrl = '';
        _focusNode.requestFocus();
        return;
      }
      if (info.status == DownloadProgress.failed) {
        HapticFeedback.lightImpact();
        setState(() {
          _status = DownloadStatus.error;
          _message = 'La descarga fallo.';
        });
        return;
      }
      setState(() {
        _progress = info.total > 0 ? info.received / info.total : null;
      });
    }
  }

  void _cancelDownload() {
    if (_status == DownloadStatus.downloading) {
      setState(() => _cancelRequested = true);
    }
  }

  void _cancelPreview() {
    setState(() {
      _status = DownloadStatus.idle;
      _preview = null;
      _progress = null;
      _message = '';
      _lastResolvedUrl = '';
    });
  }

  void _downloadAnother() {
    setState(() {
      _status = DownloadStatus.idle;
      _preview = null;
      _progress = null;
      _message = '';
      _lastResolvedUrl = '';
    });
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _status == DownloadStatus.downloading ||
        _status == DownloadStatus.resolving;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BlockLogo(fontSize: 40),
                  const SizedBox(height: 10),
                  Text(
                    'NOVA DOWNLOADER X',
                    textAlign: TextAlign.center,
                    style: mono(
                      size: 13,
                      color: AppColors.textDim,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _LinkCard(
                    controller: _controller,
                    focusNode: _focusNode,
                    busy: busy,
                    onSubmit: _start,
                    onPaste: _paste,
                    onClear: () {
                      _controller.clear();
                      _lastResolvedUrl = '';
                      _focusNode.requestFocus();
                    },
                  ),
                  const SizedBox(height: 16),
                  _StateCard(
                    status: _status,
                    progress: _progress,
                    message: _message,
                    preview: _preview,
                    fileName: _fileName,
                    sizeLabel: _sizeLabel,
                    lastFileName: _lastFileName,
                    onDownload: _download,
                    onCancelDownload: _cancelDownload,
                    onCancelPreview: _cancelPreview,
                    onRetry: _start,
                    onAnother: _downloadAnother,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Los videos se almacenan en la galeria',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo del enlace con acciones de pegar y limpiar.
class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSubmit,
    required this.onPaste,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onPaste;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isEmpty = controller.text.isEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: AppColors.accent),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !busy,
                  cursorColor: AppColors.cursor,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => onSubmit(),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    hintText: 'Pega el enlace del post de X con el video',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: AppColors.textDim,
                    ),
                  ),
                ),
              ),
              if (isEmpty)
                IconButton(
                  tooltip: 'Pegar',
                  onPressed: busy ? null : onPaste,
                  icon: const Icon(
                    Icons.content_paste_rounded,
                    color: AppColors.textDim,
                  ),
                )
              else
                IconButton(
                  tooltip: 'Limpiar',
                  onPressed: busy ? null : onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textDim,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de estado: solo aparece cuando hay algo que mostrar.
class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.status,
    required this.progress,
    required this.message,
    required this.preview,
    required this.fileName,
    required this.sizeLabel,
    required this.lastFileName,
    required this.onDownload,
    required this.onCancelDownload,
    required this.onCancelPreview,
    required this.onRetry,
    required this.onAnother,
  });

  final DownloadStatus status;
  final double? progress;
  final String message;
  final ResolvedVideo? preview;
  final String fileName;
  final String? sizeLabel;
  final String lastFileName;
  final VoidCallback onDownload;
  final VoidCallback onCancelDownload;
  final VoidCallback onCancelPreview;
  final VoidCallback onRetry;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case DownloadStatus.idle:
        return const SizedBox.shrink();
      case DownloadStatus.resolving:
        return _card(
          children: const [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Buscando...',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
        );
      case DownloadStatus.preview:
        return _card(
          children: [
            _VideoBanner(url: preview?.thumbnailUrl),
            const SizedBox(height: 14),
            Text(
              fileName,
              style: mono(size: 12, color: AppColors.textDim),
            ),
            const SizedBox(height: 8),
            _MetaChips(
              resolution: _resolutionLabel(),
              size: sizeLabel,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ghostButton('Cancelar', onCancelPreview),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _solidButton('Descargar', onDownload),
                ),
              ],
            ),
          ],
        );
      case DownloadStatus.downloading:
        return _card(
          children: [
            _VideoBanner(url: preview?.thumbnailUrl),
            const SizedBox(height: 14),
            Text(
              fileName,
              style: mono(size: 12, color: AppColors.textDim),
            ),
            const SizedBox(height: 8),
            _MetaChips(
              resolution: _resolutionLabel(),
              size: sizeLabel,
            ),
            const SizedBox(height: 14),
            Text(
              progress == null
                  ? 'Descargando...'
                  : '${(progress! * 100).toStringAsFixed(0)} %',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sigue en segundo plano.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textDim,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancelDownload,
                child: const Text('Cancelar'),
              ),
            ),
          ],
        );
      case DownloadStatus.done:
        return _card(
          children: [
            _VideoBanner(url: preview?.thumbnailUrl),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Video guardado',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              lastFileName,
              style: mono(size: 12, color: AppColors.textDim),
            ),
            const SizedBox(height: 14),
            _ghostButton('Descargar otro', onAnother),
          ],
        );
      case DownloadStatus.error:
        return _card(
          children: [
            const Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Algo salio mal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(height: 14),
            _solidButton('Reintentar', onRetry),
          ],
        );
    }
  }

  String? _resolutionLabel() {
    final v = preview;
    if (v?.width != null && v?.height != null) {
      return '${v!.width} x ${v.height}';
    }
    return null;
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _solidButton(String label, VoidCallback onTap) {
    return Material(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ghostButton(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Portada del video a todo lo ancho con esquinas redondeadas.
class _VideoBanner extends StatelessWidget {
  const _VideoBanner({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: url == null || url!.isEmpty
            ? Container(
                color: AppColors.border,
                child: const Icon(
                  Icons.movie_rounded,
                  color: AppColors.textDim,
                  size: 40,
                ),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.border,
                  child: const Icon(
                    Icons.movie_rounded,
                    color: AppColors.textDim,
                    size: 40,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Etiquetas tipo pastilla con formato, resolucion y peso aproximado.
class _MetaChips extends StatelessWidget {
  const _MetaChips({required this.resolution, required this.size});

  final String? resolution;
  final String? size;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      'MP4',
      ?resolution,
      ?size,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              c,
              style: mono(size: 12, color: AppColors.textDim),
            ),
          ),
      ],
    );
  }
}
