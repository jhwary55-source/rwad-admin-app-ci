import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/call_chat_message.dart';

/// لوحة دردشة جلسة الاتصال — صورة + اسم لكل رسالة + مؤشر قراءة (✓/✓✓)، مطابقة
/// لنفس فكرة دردشة call.html السابقة بالضبط. تُستخدم كعمود جانبي ثابت على
/// الشاشات العريضة، أو كطبقة بحجم الشاشة كاملة على الجوال (تُتحكّم بها من
/// الشاشة الأب عبر `isFullscreenOverlay`).
class CallChatPanel extends StatefulWidget {
  final List<CallChatMessage> messages;
  final ValueChanged<String> onSend;
  final VoidCallback? onClose;
  final bool isFullscreenOverlay;

  const CallChatPanel({
    super.key,
    required this.messages,
    required this.onSend,
    this.onClose,
    this.isFullscreenOverlay = false,
  });

  @override
  State<CallChatPanel> createState() => _CallChatPanelState();
}

class _CallChatPanelState extends State<CallChatPanel> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(covariant CallChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _inputCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: theme.cardTheme.color, border: Border(bottom: BorderSide(color: theme.dividerColor))),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('دردشة الجلسة', style: TextStyle(fontWeight: FontWeight.w800))),
                  if (widget.isFullscreenOverlay && widget.onClose != null)
                    IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
                ],
              ),
            ),
            Expanded(
              child: widget.messages.isEmpty
                  ? const Center(child: Text('ابدأ المحادثة...', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: widget.messages.length,
                      itemBuilder: (context, i) => _ChatBubble(message: widget.messages[i]),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.dividerColor))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: const InputDecoration(hintText: 'اكتب رسالة...', isDense: true),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(icon: const Icon(Icons.send, size: 18), onPressed: _send),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final CallChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final time = DateFormat('HH:mm').format(message.sentAt);
    final row = Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        PersonAvatar(avatarUrl: message.senderAvatarUrl, name: message.senderName, radius: 13),
        const SizedBox(width: 7),
        Flexible(
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(message.senderName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: isMe ? AppGradients.tealToDark : null,
                  color: isMe ? null : Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(message.text, style: TextStyle(color: isMe ? Colors.white : null, fontSize: 13)),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  if (isMe) ...[
                    const SizedBox(width: 3),
                    Icon(message.read ? Icons.done_all : Icons.done, size: 13, color: message.read ? Colors.lightBlue : Colors.grey),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: row);
  }
}
