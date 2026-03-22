import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:rumble/utils/html_utils.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:rumble/components/image_gallery.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    // Listen for new messages to auto-scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mumbleService = context.read<MumbleService>();
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
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onMessagesUpdated() {
    if (mounted) {
      _scrollToBottom();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Check for Cmd+V or Ctrl+V
      final bool isV = event.logicalKey == LogicalKeyboardKey.keyV;
      final bool modifierPressed = HardwareKeyboard.instance.isMetaPressed || 
                                   HardwareKeyboard.instance.isControlPressed;

      if (isV && modifierPressed) {
        _handlePaste();
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final mumbleService = context.watch<MumbleService>();
    final messages = mumbleService.messages;

    final self = mumbleService.self;
    final currentChannelName = self?.channel.name ?? 'Chat';

    return Column(
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
                currentChannelName,
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
          child: ListView.builder(
            controller: _scrollController,
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
                          textStyle: theme.textTheme.muted.copyWith(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          onTapImage: (imageData) {
                            final allImages = messages
                                .expand((m) => HtmlUtils.extractImageSources(m.content))
                                .toList();
                            final index = allImages.indexOf(imageData.sources.first.url);
                            ImageGalleryDialog.show(context, allImages, index >= 0 ? index : 0);
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
                          style: theme.textTheme.muted.copyWith(fontSize: 10),
                        ),
                        if (msg.isSelf)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              msg.senderName,
                              style: theme.textTheme.small.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.mutedForeground,
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
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : theme.colorScheme.muted.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: msg.isSelf
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.2,
                                )
                              : theme.colorScheme.border.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                      ),
                      child: HtmlWidget(
                        msg.content,
                        textStyle: theme.textTheme.p.copyWith(fontSize: 14),
                        onTapImage: (imageData) {
                          // Extract all unique images from all messages
                          final allImages = messages
                              .expand((m) => HtmlUtils.extractImageSources(m.content))
                              .toList();
                          // Handle duplicates by getting unique list while preserving order
                          final uniqueImages = <String>[];
                          for (final img in allImages) {
                            if (!uniqueImages.contains(img)) {
                              uniqueImages.add(img);
                            }
                          }
                          
                          final currentUrl = imageData.sources.first.url;
                          final index = uniqueImages.indexOf(currentUrl);
                          
                          ImageGalleryDialog.show(
                            context,
                            uniqueImages,
                            index >= 0 ? index : 0,
                          );
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
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
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
              Expanded(
                child: ShadInput(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  placeholder: const Text('Type a message...'),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              ShadIconButton(
                icon: const Icon(LucideIcons.send, size: 18),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
