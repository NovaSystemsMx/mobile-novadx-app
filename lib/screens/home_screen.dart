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

enum _ItemStatus { idle, downloading, done, error }

/// Estado de descarga de uno de los videos del post.
class _VideoItem {
  _VideoItem({required this.video, required this.fileName})
      : status = _ItemStatus.idle;

  final ResolvedVideo video;
  final String fileName;
  String? sizeLabel;
  _ItemStatus status;
  double? progress;
  bool cancelRequested = false;
  String? error;
  String lastFileName = '';
}

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
  String _message = '';

  /// Todos los videos del post; uno solo cuando el post trae un único mp4.
  List<_VideoItem> _items = [];
  String _lastResolvedUrl = '';

  Timer? _debounce;

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
        XVideoResolver.looksLikeXUrl(url)) {
      final clean = XVideoResolver.cleanUrl(url);
      if (_controller.text.trim() != clean &&
          _status != DownloadStatus.downloading &&
          _status != DownloadStatus.resolving) {
        _controller.text = clean;
      }
    }
  }

  /// Si el portapapeles ya trae un link de X, lo pone (se resuelve solo).
  Future<void> _maybeAutofill() async {
    if (_controller.text.trim().isNotEmpty) return;
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty && XVideoResolver.looksLikeXUrl(text) && mounted) {
        _controller.text = XVideoResolver.cleanUrl(text);
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
    final clean = XVideoResolver.cleanUrl(text);
    if (clean != text) {
      _controller.value = _controller.value.copyWith(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
    }
    if (clean == _lastResolvedUrl) return;
    if (_status == DownloadStatus.resolving ||
        _status == DownloadStatus.downloading) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_controller.text.trim() != clean) return;
      _start();
    });
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) return;
      final clean = XVideoResolver.cleanUrl(text);
      _controller.text = clean;
      _focusNode.requestFocus();
      // Arranque inmediato: no depender del debounce del listener,
      // que podia no dispararse tras limpiar y pegar.
      await _start();
    } catch (_) {
      // Sin acceso al portapapeles.
    }
  }

  /// Busca todos los videos del post por detras. Al encontrarlos aparece
  /// la lista con un boton Descargar por video (y uno para descargar todos).
  Future<void> _start() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty ||
        _status == DownloadStatus.resolving ||
        _status == DownloadStatus.downloading) {
      return;
    }
    final input = XVideoResolver.cleanUrl(raw);
    if (input != raw) {
      _controller.value = _controller.value.copyWith(
        text: input,
        selection: TextSelection.collapsed(offset: input.length),
      );
    }
    if (input == _lastResolvedUrl &&
        _status == DownloadStatus.preview &&
        _items.isNotEmpty) {
      return;
    }

    if (!XVideoResolver.looksLikeXUrl(input)) {
      setState(() {
        _status = DownloadStatus.resolving;
        _message = '';
        _items = [];
      });
      // Pequeña espera para que se alcance a ver el "Buscando...".
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() {
        _status = DownloadStatus.error;
        _message = 'Ese enlace no es de X.';
      });
      return;
    }

    final stopwatch = Stopwatch()..start();
    setState(() {
      _status = DownloadStatus.resolving;
      _message = '';
      _items = [];
    });

    try {
      final resolved = await _resolver.resolveAll(input);
      final statusId =
          RegExp(r'status\/(\d+)').firstMatch(input)?.group(1) ?? 'video';
      final items = resolved
          .map(
            (v) => _VideoItem(
              video: v,
              // Un solo video conserva el nombre historico x_<id>.mp4.
              // Con varios: x_<id>_1.mp4, x_<id>_2.mp4, ...
              fileName: resolved.length == 1
                  ? 'x_$statusId.mp4'
                  : 'x_${statusId}_${v.index + 1}.mp4',
            ),
          )
          .toList();

      // HEAD de todos en paralelo: no queremos esperar 4 veces de a 8 s.
      final sizes = await Future.wait(
        items
            .map((item) => GalleryDownloader.estimateSizeLabel(
                  item.video.downloadUrl,
                ))
            .toList(),
      );
      for (var i = 0; i < items.length; i++) {
        items[i].sizeLabel = sizes[i];
      }

      if (!mounted) return;
      setState(() {
        _status = DownloadStatus.preview;
        _items = items;
        _lastResolvedUrl = input;
      });
    } on XResolverException catch (e) {
      await _quedarBienDelay(stopwatch);
      if (!mounted) return;
      setState(() {
        _status = DownloadStatus.error;
        _message = e.message;
      });
    } catch (_) {
      await _quedarBienDelay(stopwatch);
      if (!mounted) return;
      setState(() {
        _status = DownloadStatus.error;
        _message = 'Sin conexion. Intentalo de nuevo.';
      });
    }
  }

  /// Garantiza minimo 2s de "Buscando..." antes de mostrar un error,
  /// para que no parezca que ni lo intento. Si la red ya tardo mas,
  /// no agrega espera extra.
  Future<void> _quedarBienDelay(Stopwatch sw) async {
    const min = Duration(seconds: 2);
    final elapsed = sw.elapsed;
    if (elapsed < min) await Future.delayed(min - elapsed);
  }

  /// Descarga un video. Varios pueden estar en marcha a la vez: cada uno
  /// tiene su propio id de DownloadManager y su bucle de progreso.
  Future<void> _downloadItem(_VideoItem item) async {
    if (item.status == _ItemStatus.downloading ||
        item.status == _ItemStatus.done) {
      return;
    }
    setState(() {
      item.status = _ItemStatus.downloading;
      item.progress = null;
      item.error = null;
      item.cancelRequested = false;
      _status = DownloadStatus.downloading;
    });

    if (!Platform.isAndroid) {
      try {
        await _downloader.download(
          item.video.downloadUrl,
          fileName: item.fileName,
          onProgress: (p) {
            if (mounted) setState(() => item.progress = p);
          },
        );
        _finishItem(item, item.fileName);
      } catch (_) {
        _failItem(item);
      }
      return;
    }

    int id;
    try {
      id = await GalleryDownloader.enqueue(
        url: item.video.downloadUrl,
        fileName: item.fileName,
      );
    } catch (_) {
      _failItem(item, 'No pude iniciar la descarga.');
      return;
    }

    while (mounted && item.status == _ItemStatus.downloading) {
      if (item.cancelRequested) {
        await GalleryDownloader.cancel(id);
        if (!mounted) return;
        setState(() {
          item.status = _ItemStatus.idle;
          item.progress = null;
          item.cancelRequested = false;
          _syncGlobalStatus();
        });
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      DownloadProgress info;
      try {
        info = await GalleryDownloader.query(id);
      } catch (_) {
        continue;
      }
      if (info.status == DownloadProgress.successful) {
        _finishItem(item, info.fileName);
        return;
      }
      if (info.status == DownloadProgress.failed) {
        _failItem(item);
        return;
      }
      setState(() {
        item.progress = info.total > 0 ? info.received / info.total : null;
      });
    }
  }

  /// Encola los videos que falten. Las llamadas async se lanzan sin await
  /// para que corran en paralelo; el guard de [_downloadItem] evita duplicar.
  void _downloadAll() {
    for (final item in _items) {
      if (item.status != _ItemStatus.done &&
          item.status != _ItemStatus.downloading) {
        unawaited(_downloadItem(item));
      }
    }
  }

  void _cancelItem(_VideoItem item) {
    if (item.status != _ItemStatus.downloading) return;
    setState(() => item.cancelRequested = true);
  }

  void _cancelAll() {
    setState(() {
      for (final item in _items) {
        if (item.status == _ItemStatus.downloading) {
          item.cancelRequested = true;
        }
      }
    });
  }

  void _finishItem(_VideoItem item, String fileName) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      item.status = _ItemStatus.done;
      item.progress = 1.0;
      item.lastFileName =
          fileName.isNotEmpty ? fileName : item.fileName;
      _syncGlobalStatus();
    });
  }

  void _failItem(_VideoItem item, [String message = 'La descarga fallo.']) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      item.status = _ItemStatus.error;
      item.error = message;
      item.progress = null;
      _syncGlobalStatus();
    });
  }

  /// El estado global solo organiza la card: termina cuando todos los
  /// videos terminaron, o vuelve a preview si no queda ninguno en marcha.
  void _syncGlobalStatus() {
    if (_items.isNotEmpty && _items.every((i) => i.status == _ItemStatus.done)) {
      _status = DownloadStatus.done;
    } else if (_items.any((i) => i.status == _ItemStatus.downloading)) {
      _status = DownloadStatus.downloading;
    } else {
      _status = DownloadStatus.preview;
    }
  }

  void _cancelPreview() {
    setState(() {
      _status = DownloadStatus.idle;
      _items = [];
      _message = '';
      _lastResolvedUrl = '';
    });
  }

  void _downloadAnother() {
    _cancelPreview();
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
                      _cancelPreview();
                      _controller.clear();
                      _focusNode.requestFocus();
                    },
                  ),
                  const SizedBox(height: 16),
                  _StateCard(
                    status: _status,
                    message: _message,
                    items: _items,
                    onDownloadItem: _downloadItem,
                    onCancelItem: _cancelItem,
                    onDownloadAll: _downloadAll,
                    onCancelAll: _cancelAll,
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
    required this.message,
    required this.items,
    required this.onDownloadItem,
    required this.onCancelItem,
    required this.onDownloadAll,
    required this.onCancelAll,
    required this.onCancelPreview,
    required this.onRetry,
    required this.onAnother,
  });

  final DownloadStatus status;
  final String message;
  final List<_VideoItem> items;
  final void Function(_VideoItem item) onDownloadItem;
  final void Function(_VideoItem item) onCancelItem;
  final VoidCallback onDownloadAll;
  final VoidCallback onCancelAll;
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
      case DownloadStatus.preview:
      case DownloadStatus.downloading:
      case DownloadStatus.done:
        if (items.isEmpty) return const SizedBox.shrink();
        if (items.length == 1) return _videoCard(items.first);
        return _videoList();
    }
  }

  /// Card de un video, identica tanto si el post trae uno como si trae varios.
  Widget _videoCard(_VideoItem item) {
    final downloading = item.status == _ItemStatus.downloading;
    final done = item.status == _ItemStatus.done;
    final error = item.status == _ItemStatus.error;

    final children = <Widget>[];

    children.addAll([
      _VideoBanner(url: item.video.thumbnailUrl),
      const SizedBox(height: 14),
      Text(
        done && item.lastFileName.isNotEmpty
            ? item.lastFileName
            : item.fileName,
        style: mono(size: 12, color: AppColors.textDim),
      ),
    ]);

    if (!done) {
      children.addAll([
        const SizedBox(height: 8),
        _MetaChips(
          resolution: _resolutionLabel(item.video),
          size: item.sizeLabel,
        ),
      ]);
    }

    if (error) {
      children.addAll([
        const SizedBox(height: 10),
        Text(
          item.error ?? 'La descarga fallo.',
          style: const TextStyle(fontSize: 13, color: AppColors.error),
        ),
      ]);
    }

    if (downloading) {
      children.addAll([
        const SizedBox(height: 14),
        Text(
          item.progress == null
              ? 'Descargando...'
              : '${(item.progress! * 100).toStringAsFixed(0)} %',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: item.progress,
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
            onPressed: () => onCancelItem(item),
            child: const Text('Cancelar'),
          ),
        ),
      ]);
    } else if (done) {
      children.addAll([
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
        const SizedBox(height: 14),
        _ghostButton('Descargar otro', onAnother),
      ]);
    } else {
      children.addAll([
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ghostButton('Cancelar', onCancelPreview),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _solidButton(
                error ? 'Reintentar' : 'Descargar',
                () => onDownloadItem(item),
              ),
            ),
          ],
        ),
      ]);
    }

    return _card(children: children);
  }

  /// Varios videos: una card completa por video mas las acciones globales.
  Widget _videoList() {
    final doneCount =
        items.where((i) => i.status == _ItemStatus.done).length;
    final anyDownloading =
        items.any((i) => i.status == _ItemStatus.downloading);
    final allDone = doneCount == items.length;
    final remaining = items.length - doneCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.video_library_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$doneCount / ${items.length} videos guardados',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Descarga los que quieras o todos a la vez.',
              style: TextStyle(fontSize: 12, color: AppColors.textDim),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _videoCard(items[i]),
        ],
        const SizedBox(height: 12),
        _card(
          children: [
            if (allDone)
              _ghostButton('Descargar otro', onAnother)
            else if (anyDownloading)
              _ghostButton('Cancelar todos', onCancelAll)
            else
              _solidButton(
                remaining == items.length
                    ? 'Descargar todos (${items.length})'
                    : 'Descargar restantes ($remaining)',
                onDownloadAll,
              ),
          ],
        ),
      ],
    );
  }

  String? _resolutionLabel(ResolvedVideo video) {
    if (video.width != null && video.height != null) {
      return '${video.width} x ${video.height}';
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