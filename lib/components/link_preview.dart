import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:rumble/components/rumble_tooltip.dart';
import 'package:rumble/components/image_gallery.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/utils/html_utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class LinkPreview extends StatelessWidget {
  final String url;

  const LinkPreview({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    // Basic check for common media types that might need different handling
    final isVideo = _isMediaType(url, ['.mp4', '.webm', '.mov', '.mkv']);
    final isAudio = _isMediaType(url, ['.mp3', '.wav', '.ogg', '.m4a']);
    final isPdf = _isMediaType(url, ['.pdf']);
    final isImage = _isMediaType(url, ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp']);

    if (isImage) {
      return GestureDetector(
        onTap: () => _showGallery(context, url),
        child: _withMediaOverlay(
          context: context,
          url: url,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.muted.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const CircularProgressIndicator(),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.muted.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(LucideIcons.imageOff, size: 24),
                  const SizedBox(height: 8),
                  Text('Failed to load image', style: theme.textTheme.small),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (isVideo) {
      return _withMediaOverlay(
        context: context,
        url: url,
        child: VideoPreview(url: url),
      );
    }

    if (isAudio) {
      return _withMediaOverlay(
        context: context,
        url: url,
        child: AudioPreview(url: url),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AnyLinkPreview(
          link: url,
          displayDirection: UIDirection.uiDirectionHorizontal,
          cache: const Duration(days: 7),
          backgroundColor: theme.colorScheme.muted.withValues(alpha: 0.1),
          errorWidget: Container(
            color: theme.colorScheme.muted.withValues(alpha: 0.1),
            child: ListTile(
              leading: Icon(
                isPdf ? LucideIcons.fileText : (isVideo ? LucideIcons.video : (isAudio ? LucideIcons.headphones : LucideIcons.link)),
                color: theme.colorScheme.primary,
              ),
              title: Text(
                _getFileName(url),
                style: theme.textTheme.small,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'External Link',
                style: theme.textTheme.muted.copyWith(fontSize: 10),
              ),
              onTap: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ),
          errorBody: 'Failed to load preview',
          errorTitle: 'Link Preview',
          titleStyle: theme.textTheme.small.copyWith(fontWeight: FontWeight.bold),
          bodyStyle: theme.textTheme.muted.copyWith(fontSize: 12),
          borderRadius: 8,
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
        ),
      ),
    );
  }

  // Helper for consistent media framing with a link overlay
  Widget _withMediaOverlay({required BuildContext context, required Widget child, required String url}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: child,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: RumbleTooltip(
                message: url,
                child: ShadIconButton.secondary(
                  icon: const Icon(LucideIcons.link, size: 14),
                  padding: EdgeInsets.zero,
                  width: 28,
                  height: 28,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ShadToaster.of(context).show(
                      ShadToast(
                        title: const Text('Copied link'),
                        description: const Text('Media URL copied to clipboard'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGallery(BuildContext context, String currentUrl) {
    try {
      final mumbleService = Provider.of<MumbleService>(context, listen: false);
      final uniqueImages = <String>[];
      
      for (final msg in mumbleService.messages) {
        final images = HtmlUtils.extractAllViewableImages(msg.content);
        for (final src in images) {
          if (!uniqueImages.contains(src)) {
            uniqueImages.add(src);
          }
        }
      }

      final index = uniqueImages.indexOf(currentUrl);
      ImageGalleryDialog.show(
        context,
        uniqueImages,
        index >= 0 ? index : 0,
      );
    } catch (_) {}
  }

  bool _isMediaType(String url, List<String> extensions) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      return extensions.any((ext) => path.endsWith(ext));
    } catch (_) {
      return false;
    }
  }

  String _getFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : url;
      return fileName;
    } catch (_) {
      return url;
    }
  }
}

class VideoPreview extends StatefulWidget {
  final String url;
  const VideoPreview({super.key, required this.url});

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  Player? _player;
  VideoController? _controller;
  bool _isInitializing = false;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  Metadata? _metadata;

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
  }

  Future<void> _fetchMetadata() async {
    try {
      final metadata = await AnyLinkPreview.getMetadata(link: widget.url);
      if (mounted) {
        setState(() {
          _metadata = metadata;
        });
      }
    } catch (_) {
      // Ignore metadata fetch errors
    }
  }

  Future<void> _initializePlayer() async {
    if (_isInitialized || _isInitializing) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      final player = Player(
        configuration: const PlayerConfiguration(
          logLevel: MPVLogLevel.debug,
        ),
      );
      
      final controller = VideoController(player);

      player.stream.log.listen((event) {
        debugPrint('[mpv-video] ${event.prefix}: ${event.text}');
      });

      if (mounted) {
        setState(() {
          _player = player;
          _controller = controller;
          _isInitialized = true;
          _isInitializing = false;
        });
      }

      // Start loading and playing the media 
      // (play is true here because this only runs after the user explicitly taps 'Tap to load')
      final cleanUrl = Uri.decodeFull(widget.url);
      debugPrint('[DEBUG] VideoPreview: Opening media $cleanUrl (original: ${widget.url})');
      _player!.open(
        Media(
          cleanUrl,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
        play: true,
      ).then((_) {
        debugPrint('[DEBUG] VideoPreview: Media opened successfully');
      }).catchError((e) {
        debugPrint('[DEBUG] VideoPreview: Error opening media: $e');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = e.toString();
          });
        }
      });

      _player!.stream.error.listen((error) {
        debugPrint('[DEBUG] VideoPreview Player Stream Error: $error');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = error;
          });
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
          _errorMessage = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    if (!_isInitialized) {
      return GestureDetector(
        onTap: _initializePlayer,
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.muted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            image: _metadata?.image != null 
              ? DecorationImage(
                  image: NetworkImage(_metadata!.image!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.4),
                    BlendMode.darken,
                  ),
                )
              : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isInitializing)
                const CircularProgressIndicator()
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.play, size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('Tap to load video', style: theme.textTheme.small.copyWith(color: Colors.white)),
                  ],
                ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.url.split('.').last.split('?').first.toUpperCase(),
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (_metadata?.title != null && !_isInitializing)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 48,
                  child: Text(
                    _metadata!.title!,
                    style: theme.textTheme.small.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [const Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.muted.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RumbleTooltip(
              message: _errorMessage ?? 'Unknown error',
              child: const Icon(LucideIcons.videoOff, size: 32),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Unsupported video format or network error',
                textAlign: TextAlign.center,
                style: theme.textTheme.small,
              ),
            ),
            const SizedBox(height: 12),
            ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: () async {
                final uri = Uri.parse(widget.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: const Text('Open in Browser'),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Video(
          controller: _controller!,
          controls: (state) => MaterialDesktopVideoControls(state),
        ),
      ),
    );
  }
}

class AudioPreview extends StatefulWidget {
  final String url;
  const AudioPreview({super.key, required this.url});

  @override
  State<AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<AudioPreview> {
  late Player _player;
  bool _isPlaying = false;
  bool _hasError = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.debug,
      ),
    );
    
    _player.stream.log.listen((event) {
      debugPrint('[mpv-audio] ${event.prefix}: ${event.text}');
    });
    _subscriptions.add(_player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    }));
    
    _subscriptions.add(_player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    }));
    
    _subscriptions.add(_player.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    }));

    _subscriptions.add(_player.stream.error.listen((error) {
      debugPrint('[DEBUG] AudioPreview Player Stream Error: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Audio Playback Error'),
            description: Text(error),
          ),
        );
      }
    }));

    final cleanUrl = Uri.decodeFull(widget.url);
    debugPrint('[DEBUG] AudioPreview: Opening media $cleanUrl (original: ${widget.url})');
    _player.open(
      Media(
        cleanUrl,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
      play: false,
    ).catchError((e) {
      debugPrint('[DEBUG] AudioPreview: Error opening media: $e');
    });
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    
    // Check for errors in the player state
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.muted.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.circleAlert, size: 16, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Audio playback failed',
                style: theme.textTheme.small,
              ),
            ),
            ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: () async {
                final uri = Uri.parse(widget.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: const Icon(LucideIcons.externalLink, size: 16),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ShadIconButton.secondary(
            icon: Icon(_isPlaying ? LucideIcons.pause : LucideIcons.play),
            onPressed: () => _player.playOrPause(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: _position.inSeconds.toDouble(),
                  max: _duration.inSeconds.toDouble() > 0 
                      ? _duration.inSeconds.toDouble() 
                      : 1,
                  onChanged: (value) async {
                    await _player.seek(Duration(seconds: value.toInt()));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position), style: theme.textTheme.muted.copyWith(fontSize: 10)),
                      Text(_formatDuration(_duration), style: theme.textTheme.muted.copyWith(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
