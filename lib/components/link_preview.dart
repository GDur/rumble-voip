import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:rumble/components/rumble_tooltip.dart';
import 'package:rumble/components/media_gallery.dart';
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
    final mediaType = HtmlUtils.getMediaType(url);
    final isVideo = mediaType == MediaType.video;
    final isAudio = mediaType == MediaType.audio;
    final isPdf = mediaType == MediaType.pdf;
    final isImage = mediaType == MediaType.image;

    if (isImage) {
      return _withMediaOverlay(
        context: context,
        url: url,
        child: ImagePreview(url: url),
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

    if (isPdf) {
      return _withMediaOverlay(
        context: context,
        url: url,
        child: PdfPreview(url: url),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RumbleTooltip(
                    message: 'Open in gallery',
                    child: ShadIconButton.secondary(
                      icon: const Icon(LucideIcons.maximize, size: 14),
                      padding: EdgeInsets.zero,
                      width: 28,
                      height: 28,
                      onPressed: () => _showGallery(context, url),
                    ),
                  ),
                  const SizedBox(width: 4),
                  RumbleTooltip(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGallery(BuildContext context, String currentUrl) {
    _showInternalGallery(context, currentUrl);
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

void _showInternalGallery(BuildContext context, String currentUrl) {
  try {
    final mumbleService = Provider.of<MumbleService>(context, listen: false);
    final uniqueMedia = mumbleService.messages
        .expand<String>((msg) => HtmlUtils.extractAllViewableMedia(msg.content))
        .toSet()
        .toList();

    final index = uniqueMedia.indexOf(currentUrl);
    MediaGalleryDialog.show(
      context,
      uniqueMedia,
      index >= 0 ? index : 0,
    );
  } catch (_) {}
}

class PdfPreview extends StatelessWidget {
  final String url;
  const PdfPreview({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final fileName = url.split('/').last.split('?').first;
    
    return GestureDetector(
      onTap: () => _showInternalGallery(context, url),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: theme.colorScheme.muted.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.muted.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: const Icon(LucideIcons.fileText, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('PDF Document', style: theme.textTheme.small.copyWith(fontWeight: FontWeight.bold)),
                   const SizedBox(height: 4),
                   Text(
                     fileName, 
                     style: theme.textTheme.muted.copyWith(fontSize: 11), 
                     maxLines: 1, 
                     overflow: TextOverflow.ellipsis
                   ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Icon(LucideIcons.chevronRight, size: 16),
            ),
          ],
        ),
      ),
    );
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
        if (metadata?.image == null) {
          _generateThumbnail();
        }
      }
    } catch (_) {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    // Attempt to get a single frame as a thumbnail for direct video files
    Player? tempPlayer;
    try {
      tempPlayer = Player();
      await tempPlayer.open(
        Media(
          widget.url,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
        play: false,
      );
      
      // Wait for metadata to load so we can seek
      await tempPlayer.stream.videoParams.first;
      await tempPlayer.seek(const Duration(seconds: 1));
      
      final screenshot = await tempPlayer.screenshot();
      if (screenshot != null && mounted) {
        setState(() {
          _thumbnailData = screenshot;
        });
      }
    } catch (e) {
      debugPrint('[DEBUG] VideoPreview: Failed to generate thumbnail: $e');
    } finally {
      await tempPlayer?.dispose();
    }
  }

  Uint8List? _thumbnailData;

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

      // Configure player properties
      if (player.platform is NativePlayer) {
        (player.platform as NativePlayer).setProperty('force-seekable', 'yes');
        (player.platform as NativePlayer).setProperty('demuxer-readahead-secs', '15');
        (player.platform as NativePlayer).setProperty('cache', 'yes');
        (player.platform as NativePlayer).setProperty('cache-secs', '10');
      }

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
      final mediaUrl = widget.url;
      debugPrint('[DEBUG] VideoPreview: Opening media $mediaUrl');
      _player!.open(
        Media(
          mediaUrl,
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
        // Filter out non-fatal errors like "Cannot seek" which often happen with HTTP streams
        // but don't prevent actually watching the video.
        if (error.toLowerCase().contains('cannot seek') || 
            error.toLowerCase().contains('force-seekable')) {
          return;
        }
        
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
            image: _thumbnailData != null
              ? DecorationImage(
                  image: MemoryImage(_thumbnailData!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.4),
                    BlendMode.darken,
                  ),
                )
              : (_metadata?.image != null 
                  ? DecorationImage(
                      image: NetworkImage(_metadata!.image!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.4),
                        BlendMode.darken,
                      ),
                    )
                  : null),
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
class ImagePreview extends StatefulWidget {
  final String url;
  const ImagePreview({super.key, required this.url});

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  bool _isHidden = false;
  
  bool get _isGif => widget.url.toLowerCase().split('?').first.endsWith('.gif');

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    
    if (_isHidden) {
      return GestureDetector(
        onTap: () => setState(() => _isHidden = false),
        child: Container(
          height: 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.muted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.eyeOff, size: 20),
              const SizedBox(height: 8),
              Text('GIF Hidden. Click to show', style: theme.textTheme.small),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            final mumbleService = Provider.of<MumbleService>(context, listen: false);
            final uniqueMedia = mumbleService.messages
                .expand<String>((msg) => HtmlUtils.extractAllViewableMedia(msg.content))
                .toSet()
                .toList();

            final index = uniqueMedia.indexOf(widget.url);
            MediaGalleryDialog.show(
              context,
              uniqueMedia,
              index >= 0 ? index : 0,
            );
          },
          child: Image.network(
            widget.url,
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
        if (_isGif)
          Positioned(
            bottom: 4,
            left: 4,
            child: RumbleTooltip(
              message: 'Hide animated GIF',
              child: ShadIconButton.secondary(
                icon: const Icon(LucideIcons.eyeOff, size: 12),
                padding: EdgeInsets.zero,
                width: 24,
                height: 24,
                onPressed: () => setState(() => _isHidden = true),
              ),
            ),
          ),
      ],
    );
  }
}
