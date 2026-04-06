import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pdfx/pdfx.dart';
import 'package:rumble/utils/html_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class MediaGalleryDialog extends StatefulWidget {
  final List<String> sources;
  final int initialIndex;

  const MediaGalleryDialog({
    super.key,
    required this.sources,
    required this.initialIndex,
  });

  static void show(BuildContext context, List<String> sources, int initialIndex) {
    if (sources.isEmpty) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Gallery',
      barrierColor: Colors.black.withValues(alpha: 0.9),
      pageBuilder: (context, animation, secondaryAnimation) {
        return MediaGalleryDialog(sources: sources, initialIndex: initialIndex);
      },
    );
  }

  @override
  State<MediaGalleryDialog> createState() => _MediaGalleryDialogState();
}

class _MediaGalleryDialogState extends State<MediaGalleryDialog> {
  late PageController _pageController;
  late int _currentIndex;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < widget.sources.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _nextPage();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _previousPage();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Backdrop dismissal
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.black),
              ),
            ),

            // Main Gallery View
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.sources.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final source = widget.sources[index];
                  final type = HtmlUtils.getMediaType(source);
                  
                  switch (type) {
                    case MediaType.image:
                      return _ImageSlide(source: source);
                    case MediaType.video:
                    case MediaType.audio:
                      return _VideoSlide(source: source, isAudio: type == MediaType.audio);
                    case MediaType.pdf:
                      return _PdfSlide(source: source);
                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
            ),

            // Top Actions
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: ShadIconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),

            // Left Arrow
            if (_currentIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: ShadIconButton(
                    icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
                    onPressed: _previousPage,
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),

            // Right Arrow
            if (_currentIndex < widget.sources.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: ShadIconButton(
                    icon: const Icon(LucideIcons.chevronRight, color: Colors.white),
                    onPressed: _nextPage,
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),

            // Bottom Thumbnail Row
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_currentIndex + 1} / ${widget.sources.length}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 60,
                      child: Center(
                        child: ListView.separated(
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: widget.sources.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final source = widget.sources[index];
                            final type = HtmlUtils.getMediaType(source);
                            final isSelected = _currentIndex == index;
                            
                            Widget thumbnail;
                            if (type == MediaType.image) {
                              if (source.startsWith('data:')) {
                                final base64Data = source.split(',').last;
                                thumbnail = Image.memory(
                                  base64Decode(base64Data),
                                  fit: BoxFit.cover,
                                );
                              } else {
                                thumbnail = Image.network(
                                  source,
                                  fit: BoxFit.cover,
                                );
                              }
                            } else {
                              IconData icon;
                              switch (type) {
                                case MediaType.video: icon = LucideIcons.video; break;
                                case MediaType.audio: icon = LucideIcons.music; break;
                                case MediaType.pdf: icon = LucideIcons.fileText; break;
                                default: icon = LucideIcons.file;
                              }
                              thumbnail = Container(
                                color: theme.colorScheme.muted,
                                child: Icon(icon, color: Colors.white, size: 24),
                              );
                            }

                            return GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : Colors.white24,
                                    width: isSelected ? 3 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: thumbnail,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageSlide extends StatelessWidget {
  final String source;
  const _ImageSlide({required this.source});

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;
    if (source.startsWith('data:')) {
      final base64Data = source.split(',').last;
      imageProvider = MemoryImage(base64Decode(base64Data));
    } else {
      imageProvider = NetworkImage(source);
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: PhotoView(
        imageProvider: imageProvider,
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 0.5,
        // For images smaller than current viewport, stay at original size as much as possible 
        // but PhotoView is tricky about it. 1.0 means original size if it fits.
        maxScale: PhotoViewComputedScale.covered * 4.0,
        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
        filterQuality: FilterQuality.high,
        // Also pop when tapping the image itself, as requested for 'backdrop' 
        // (in many contexts, the image area is also considered backdrop if no UI is showing)
        onTapUp: (context, details, value) => Navigator.of(context).pop(),
      ),
    );
  }
}

class _VideoSlide extends StatefulWidget {
  final String source;
  final bool isAudio;
  const _VideoSlide({required this.source, required this.isAudio});

  @override
  State<_VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends State<_VideoSlide> {
  late Player _player;
  late VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.open(
      Media(
        widget.source,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isAudio) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.music, size: 64, color: Colors.white54),
            const SizedBox(height: 32),
            SizedBox(
              width: 400,
              child: Material(
                color: Colors.transparent,
                child: StreamBuilder(
                  stream: _player.stream.position,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = _player.state.duration;
                    return Column(
                      children: [
                        Slider(
                          value: position.inSeconds.toDouble(),
                          max: duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1,
                          onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
                        ),
                        Text(
                          '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')} / ${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        ShadIconButton(
                          icon: Icon(_player.state.playing ? LucideIcons.pause : LucideIcons.play),
                          onPressed: () => _player.playOrPause(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: GestureDetector(
          onTap: () {}, // Consume taps on the video itself
          child: Video(
            controller: _controller,
            controls: MaterialVideoControls,
            fit: BoxFit.scaleDown,
          ),
        ),
      ),
    );
  }
}

class _PdfSlide extends StatefulWidget {
  final String source;
  const _PdfSlide({required this.source});

  @override
  State<_PdfSlide> createState() => _PdfSlideState();
}

class _PdfSlideState extends State<_PdfSlide> {
  PdfController? _pdfController;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      if (widget.source.startsWith('data:')) {
        final base64Data = widget.source.split(',').last;
        final bytes = base64Decode(base64Data);
        _pdfController = PdfController(document: PdfDocument.openData(bytes));
      } else {
        // Download network PDF to temp file
        final response = await http.get(Uri.parse(widget.source));
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await tempFile.writeAsBytes(response.bodyBytes);
        _pdfController = PdfController(document: PdfDocument.openFile(tempFile.path));
      }
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error loading PDF: $_error', style: const TextStyle(color: Colors.white)));
    if (_pdfController == null) return const Center(child: Text('Failed to initialize PDF viewer', style: TextStyle(color: Colors.white)));

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        margin: const EdgeInsets.all(32),
        child: PdfView(
          controller: _pdfController!,
          scrollDirection: Axis.vertical,
        ),
      ),
    );
  }
}
