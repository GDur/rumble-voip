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
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audioplayers/audioplayers.dart' as ap;

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
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _videoController.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          aspectRatio: _videoController.value.aspectRatio,
          autoPlay: false,
          looping: false,
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          },
        );
      });
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = error.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

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

    if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: _videoController.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
      );
    }

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.muted.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading video...', style: TextStyle(fontSize: 12, color: Colors.white54)),
          ],
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
  final _audioPlayer = ap.AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == ap.PlayerState.playing);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 48, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ShadIconButton.secondary(
            icon: Icon(_isPlaying ? LucideIcons.pause : LucideIcons.play),
            onPressed: () {
              if (_isPlaying) {
                _audioPlayer.pause();
              } else {
                _audioPlayer.play(ap.UrlSource(widget.url));
              }
            },
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
                    await _audioPlayer.seek(Duration(seconds: value.toInt()));
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position), style: theme.textTheme.muted.copyWith(fontSize: 10)),
                    Text(_formatDuration(_duration), style: theme.textTheme.muted.copyWith(fontSize: 10)),
                  ],
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
