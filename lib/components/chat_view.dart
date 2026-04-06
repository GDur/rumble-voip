import 'dart:io';
import 'package:flutter/material.dart';
import 'package:rumble/utils/layout_constants.dart';
import 'package:provider/provider.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:rumble/utils/html_utils.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:rumble/components/image_gallery.dart';
import 'package:rumble/components/ptt_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rumble/components/rumble_tooltip.dart';
import 'package:rumble/components/link_preview.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _shouldAutoScroll = true;
  bool _isAutoScrolling = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // Listen for new messages to auto-scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mumbleService = context.read<MumbleService>();
      _lastMessageCount = mumbleService.messages.length;
      mumbleService.clearUnreadCount();
      mumbleService.addListener(_onMessagesUpdated);
      _focusNode.onKeyEvent = _onKeyEvent;
    });
  }

  @override
  void dispose() {
    // Safely remove listener
    try {
      final mumbleService = context.read<MumbleService>();
      mumbleService.removeListener(_onMessagesUpdated);
    } catch (_) {}
    _controller.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients || _isAutoScrolling) return;

    final pos = _scrollController.position;
    // Use a tighter threshold (20px) to prevent accidental reactivation while scrolling away
    final atBottom = pos.pixels >= pos.maxScrollExtent - 20;

    if (atBottom != _shouldAutoScroll) {
      setState(() {
        _shouldAutoScroll = atBottom;
      });
    }
  }

  void _onMessagesUpdated() {
    if (!mounted) return;
    final mumbleService = context.read<MumbleService>();
    final newCount = mumbleService.messages.length;

    // Only act if messages were actually added
    if (newCount > _lastMessageCount) {
      _lastMessageCount = newCount;
      mumbleService.clearUnreadCount();
      if (_shouldAutoScroll) {
        _scrollToBottom();
      }
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      context.read<MumbleService>().sendMessage(text);
      _controller.clear();
      _scrollToBottom();
    }
    _focusNode.requestFocus();
  }

  void _scrollToBottom() {
    if (!mounted || !_scrollController.hasClients) return;

    void executeScroll(int durationMs) {
      if (!mounted || !_scrollController.hasClients) return;
      _isAutoScrolling = true;
      _scrollController
          .animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: durationMs),
            curve: Curves.easeOut,
          )
          .then((_) {
            if (mounted) _isAutoScrolling = false;
          });
    }

    // First scroll attempt
    WidgetsBinding.instance.addPostFrameCallback((_) => executeScroll(300));

    // Follow-up scrolls after short delays to catch any "late" height changes from image rendering
    for (final ms in [100, 300, 800]) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (mounted && _shouldAutoScroll && !_isAutoScrolling) {
          executeScroll(150);
        }
      });
    }
  }

  void _copyMessage(String content) {
    final markdown = HtmlUtils.htmlToMarkdown(content);
    Clipboard.setData(ClipboardData(text: markdown));

    if (mounted) {
      ShadToaster.of(context).show(
        ShadToast(
          title: const Text('Copied'),
          description: const Text('Message copied with formatting intact'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handlePaste() async {
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null) {
        final html = HtmlUtils.imageToHtml(imageBytes);
        if (mounted) {
          context.read<MumbleService>().sendMessage(html);
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Error pasting image: $e');
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final html = HtmlUtils.imageToHtml(bytes);
        if (mounted) {
          context.read<MumbleService>().sendMessage(html);
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Check for Cmd+V or Ctrl+V
      final bool isV = event.logicalKey == LogicalKeyboardKey.keyV;
      final bool modifierPressed =
          HardwareKeyboard.instance.isMetaPressed ||
          HardwareKeyboard.instance.isControlPressed;

      if (isV && modifierPressed) {
        _handlePaste();
        return KeyEventResult.ignored;
      }

      // Handle Enter to send, Shift+Enter for new line
      final bool isEnter =
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter;
      final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

      if (isEnter && !isShiftPressed) {
        _sendMessage();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final mumbleService = context.watch<MumbleService>();
    final messages = mumbleService.messages;
    final isSlim = LayoutConstants.isSlim(context);

    return Stack(
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.border.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.messageSquare,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    mumbleService.currentChannelName,
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${messages.length} messages',
                    style: theme.textTheme.muted.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SelectionArea(
                      child: ListView.builder(
                        controller: _scrollController,
                        cacheExtent: 5000, // Force eager layout of images
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          if (msg.isSystem) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: Column(
                                  children: [
                                    Text(
                                      '[${DateFormat('HH:mm:ss').format(msg.timestamp)}] ${msg.senderName}:',
                                      style: theme.textTheme.muted.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    HtmlWidget(
                                      msg.content,
                                      enableCaching: true,
                                      textStyle: theme.textTheme.muted.copyWith(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      onTapImage: (imageData) {
                                        final currentMessages = context
                                            .read<MumbleService>()
                                            .messages;
                                        final uniqueImages = currentMessages
                                            .expand(
                                              (m) =>
                                                  HtmlUtils.extractAllViewableImages(
                                                    m.content,
                                                  ),
                                            )
                                            .toSet()
                                            .toList();
                                        final index = uniqueImages.indexOf(
                                          imageData.sources.first.url,
                                        );
                                        ImageGalleryDialog.show(
                                          context,
                                          uniqueImages,
                                          index >= 0 ? index : 0,
                                        );
                                      },
                                      onTapUrl: (url) async {
                                        final uri = Uri.parse(url);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri);
                                        }
                                        return true;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: msg.isSelf
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!msg.isSelf)
                                      Text(
                                        msg.senderName,
                                        style: theme.textTheme.small.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('HH:mm').format(msg.timestamp),
                                      style: theme.textTheme.muted.copyWith(
                                        fontSize: 10,
                                      ),
                                    ),
                                    if (msg.isSelf)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Text(
                                          msg.senderName,
                                          style: theme.textTheme.small.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme
                                                .colorScheme
                                                .mutedForeground,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: msg.isSelf
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.1,
                                          )
                                        : theme.colorScheme.muted.withValues(
                                            alpha: 0.2,
                                          ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: msg.isSelf
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.2)
                                          : theme.colorScheme.border.withValues(
                                              alpha: 0.5,
                                            ),
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 24,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            HtmlWidget(
                                              msg.content,
                                              enableCaching: true,
                                              textStyle: theme.textTheme.p.copyWith(
                                                fontSize: 14,
                                                height: 1.4,
                                              ),
                                              onTapImage: (imageData) {
                                                final currentMessages = context
                                                    .read<MumbleService>()
                                                    .messages;
                                                final uniqueImages = currentMessages
                                                    .expand(
                                                      (m) =>
                                                          HtmlUtils.extractAllViewableImages(
                                                            m.content,
                                                          ),
                                                    )
                                                    .toSet()
                                                    .toList();

                                                final currentUrl =
                                                    imageData.sources.first.url;
                                                final index = uniqueImages.indexOf(
                                                  currentUrl,
                                                );

                                                ImageGalleryDialog.show(
                                                  context,
                                                  uniqueImages,
                                                  index >= 0 ? index : 0,
                                                );
                                              },
                                              onTapUrl: (url) async {
                                                final uri = Uri.parse(url);
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(uri);
                                                }
                                                return true;
                                              },
                                              customStylesBuilder: (element) {
                                                if (element.localName == 'img') {
                                                  return {
                                                    'width': 'auto',
                                                    'max-width': '100%',
                                                    'height': 'auto',
                                                    'cursor': 'pointer',
                                                    'border-radius': '8px',
                                                  };
                                                }
                                                if (element.localName == 'ul' ||
                                                    element.localName == 'ol') {
                                                  return {
                                                    'padding-left': '12px',
                                                    'margin-top': '4px',
                                                    'margin-bottom': '4px',
                                                    'list-style-type':
                                                        element.localName == 'ul'
                                                        ? 'disc'
                                                        : 'decimal',
                                                  };
                                                }
                                                if (element.localName == 'li') {
                                                  return {
                                                    'margin-bottom': '4px',
                                                    'display': 'list-item',
                                                  };
                                                }
                                                return null;
                                              },
                                            ),
                                            // Extract and show link previews
                                            ...HtmlUtils.extractUrlsForPreview(msg.content)
                                                .map((url) => LinkPreview(url: url)),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        right: -8,
                                        top: -8,
                                        child: RumbleTooltip(
                                          message: 'Copy message',
                                          child: ShadIconButton.ghost(
                                            icon: Icon(
                                              LucideIcons.copy,
                                              size: 14,
                                              color: theme
                                                  .colorScheme
                                                  .mutedForeground
                                                  .withValues(alpha: 0.5),
                                            ),
                                            width: 32,
                                            height: 32,
                                            padding: EdgeInsets.zero,
                                            onPressed: () =>
                                                _copyMessage(msg.content),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (!_shouldAutoScroll)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: RumbleTooltip(
                        message: 'Scroll to latest',
                        child: ShadIconButton.secondary(
                          icon: const Icon(LucideIcons.chevronDown, size: 16),
                          onPressed: () {
                            _scrollToBottom();
                            setState(() {
                              _shouldAutoScroll = true;
                            });
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.border.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  RumbleTooltip(
                    message: 'Attach image',
                    child: ShadIconButton.ghost(
                      icon: const Icon(LucideIcons.paperclip, size: 18),
                      onPressed: _pickAndUploadImage,
                    ),
                  ),
                  RumbleTooltip(
                    message: 'Paste image from clipboard',
                    child: ShadIconButton.ghost(
                      icon: const Icon(LucideIcons.clipboardPaste, size: 18),
                      onPressed: _handlePaste,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ShadInput(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      placeholder: const Text('Type a message...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RumbleTooltip(
                    message: 'Send message',
                    child: ShadIconButton(
                      icon: const Icon(LucideIcons.send, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (isSlim && mumbleService.isConnected)
          Positioned(
            left: 0,
            right: 0,
            bottom: 84, // Anchored closer to the input area
            child: Center(
              child: PushToTalkButton(
                service: mumbleService,
                width: 180,
                height: 48,
              ),
            ),
          ),
      ],
    );
  }
}
