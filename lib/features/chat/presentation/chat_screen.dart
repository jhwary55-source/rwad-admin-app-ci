import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/chat_message.dart';
import '../../../models/consultation.dart';
import '../../../models/profile.dart';
import '../../../models/support_ticket.dart';
import '../../../core/notifications/push_sender.dart';
import '../../appointments/presentation/appointment_form_dialog.dart';
import '../../auth/application/auth_providers.dart';
import '../../consultations/application/consultations_providers.dart';
import '../../tickets/application/tickets_providers.dart';
import '../application/chat_providers.dart';

const _kMineGradient = LinearGradient(
  colors: [AppColors.primary, AppColors.primaryDark],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class ChatScreen extends ConsumerStatefulWidget {
  final String kind; // 'consultation' | 'ticket'
  final String parentId;
  final String title;

  const ChatScreen({super.key, required this.kind, required this.parentId, required this.title});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _uploadingImage = false;
  int _lastMessageCount = -1;

  RealtimeChannel? _typingChannel;
  Timer? _typingResetTimer;
  Timer? _typingThrottle;
  bool _otherTyping = false;
  bool _markedReadOnce = false;
  bool _claiming = false;
  ConsultationStatus? _prevConsultStatus;
  TicketStatus? _prevTicketStatus;

  ChatKind get _chatKind => widget.kind == 'ticket' ? ChatKind.ticket : ChatKind.consultation;
  bool get _isTicket => widget.kind == 'ticket';

  Future<void> _claim(String staffId) async {
    setState(() => _claiming = true);
    try {
      if (_isTicket) {
        await ref.read(ticketsRepositoryProvider).claim(widget.parentId, staffId);
        ref.invalidate(ticketDetailProvider(widget.parentId));
      } else {
        await ref.read(consultationsRepositoryProvider).assign(widget.parentId, staffId);
        ref.invalidate(consultationDetailProvider(widget.parentId));
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _typingChannel = ref.read(chatRepositoryProvider).typingChannel(_chatKind, widget.parentId);
    final myId = ref.read(currentProfileProvider).valueOrNull?.id;
    _typingChannel!
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            if (payload['userId'] == myId) return;
            _typingResetTimer?.cancel();
            setState(() => _otherTyping = true);
            _typingResetTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _otherTyping = false);
            });
          },
        )
        .subscribe();
    _inputCtrl.addListener(_onTypingChanged);
  }

  void _onTypingChanged() {
    if (_inputCtrl.text.isEmpty || _typingThrottle != null) return;
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) return;
    ref.read(chatRepositoryProvider).sendTypingSignal(_typingChannel!, profile.id);
    _typingThrottle = Timer(const Duration(seconds: 2), () => _typingThrottle = null);
  }

  void _markMessagesRead() {
    final myId = ref.read(currentProfileProvider).valueOrNull?.id;
    if (myId == null) return;
    ref.read(chatRepositoryProvider).markAsRead(kind: _chatKind, parentId: widget.parentId, myId: myId);
  }

  @override
  void dispose() {
    _inputCtrl.removeListener(_onTypingChanged);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _typingResetTimer?.cancel();
    _typingThrottle?.cancel();
    if (_typingChannel != null) Supabase.instance.client.removeChannel(_typingChannel!);
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (animate) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  /// معرّف الطرف الآخر بالمحادثة (لإرسال إشعار الدفع له) — العميل إن كنت
  /// موظفًا، أو الموظف المستلم إن كنت عميلاً.
  String? _otherPartyId(Profile me) {
    if (_isTicket) {
      final t = ref.read(ticketDetailProvider(widget.parentId)).valueOrNull;
      if (t == null) return null;
      return me.isStaff ? t.clientId : t.claimedBy;
    }
    final c = ref.read(consultationDetailProvider(widget.parentId)).valueOrNull;
    if (c == null) return null;
    return me.isStaff ? c.clientId : c.assignedTo;
  }

  void _notifyNewMessage(Profile me, {required bool isImage}) {
    final otherId = _otherPartyId(me);
    if (otherId == null) return;
    ref.read(pushSenderProvider).send(
          userIds: [otherId],
          excludeUserId: me.id,
          title: me.name,
          message: isImage ? '📷 صورة' : _inputCtrl.text.trim(),
          imageUrl: me.avatarUrl,
          data: {'type': 'message', 'kind': widget.kind, 'id': widget.parentId},
        );
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            kind: _chatKind,
            parentId: widget.parentId,
            content: text,
            senderId: profile.id,
            senderName: profile.name,
            senderRole: profile.role == StaffRole.client ? 'client' : 'admin',
          );
      _notifyNewMessage(profile, isImage: false);
      _inputCtrl.clear();
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null || _uploadingImage) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingImage = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.contains('.') ? picked.path.split('.').last.toLowerCase() : 'jpg';
      final url = await ref.read(chatRepositoryProvider).uploadChatImage(
            kind: _chatKind,
            parentId: widget.parentId,
            bytes: bytes,
            fileExt: ext,
          );
      await ref.read(chatRepositoryProvider).sendMessage(
            kind: _chatKind,
            parentId: widget.parentId,
            content: '',
            imageUrl: url,
            senderId: profile.id,
            senderName: profile.name,
            senderRole: profile.role == StaffRole.client ? 'client' : 'admin',
          );
      _notifyNewMessage(profile, isImage: true);
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر إرسال الصورة، حاول مرة أخرى')));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider((_chatKind, widget.parentId)));
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final myId = profile?.id;
    final isStaff = profile?.isStaff ?? false;
    final isSuperAdmin = profile?.role == StaffRole.superAdmin;

    bool isClosed = false;
    String? clientId;
    String? clientName;
    String? clientEmail;
    String? claimedById;
    bool detailReady = false;

    if (_isTicket) {
      ref.watch(ticketDetailProvider(widget.parentId)).whenData((t) {
        isClosed = t.status == TicketStatus.closed;
        clientId = t.clientId;
        clientName = t.clientName;
        clientEmail = t.clientEmail;
        claimedById = t.claimedBy;
        detailReady = true;
        if (!isStaff) {
          if (_prevTicketStatus != null && _prevTicketStatus != TicketStatus.closed && t.status == TicketStatus.closed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
            });
          }
          _prevTicketStatus = t.status;
        }
      });
    } else {
      ref.watch(consultationDetailProvider(widget.parentId)).whenData((c) {
        isClosed = c.status == ConsultationStatus.closed;
        clientId = c.clientId;
        clientName = c.clientName;
        clientEmail = c.clientEmail;
        claimedById = c.assignedTo;
        detailReady = true;
        if (!isStaff) {
          if (_prevConsultStatus != null && _prevConsultStatus != ConsultationStatus.closed && c.status == ConsultationStatus.closed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
            });
          }
          _prevConsultStatus = c.status;
        }
      });
    }

    final locked = isClosed && !isStaff;
    final needsClaim = isStaff && !isSuperAdmin && detailReady && claimedById != myId;

    return Scaffold(
      appBar: GradientAppBar(
        title: widget.title.isEmpty ? 'الدردشة' : widget.title,
        actions: [
          if (isStaff && !needsClaim && detailReady && clientId != null)
            IconButton(
              icon: const Icon(Icons.event_available_outlined),
              tooltip: 'حجز موعد',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AppointmentFormDialog(
                  initialClientId: clientId,
                  initialClientName: clientName,
                  initialClientEmail: clientEmail,
                  consultationId: _isTicket ? null : widget.parentId,
                  ticketId: _isTicket ? widget.parentId : null,
                ),
              ),
            ),
        ],
      ),
      body: needsClaim
          ? _ClaimGate(
              claimedById: claimedById,
              claiming: _claiming,
              onClaim: myId == null ? null : () => _claim(myId),
            )
          : Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => const ErrorView(message: 'تعذّر تحميل الرسائل'),
              data: (messages) {
                if (messages.isEmpty) {
                  _lastMessageCount = 0;
                  return const EmptyState(message: 'ابدأ المحادثة...', icon: Icons.chat_bubble_outline);
                }
                // ابدأ الرسائل من الأعلى دائمًا (لا فراغ عند قلّتها)، وانزل تلقائيًا
                // للأسفل عند أول تحميل وعند وصول رسالة جديدة فقط.
                if (messages.length != _lastMessageCount) {
                  final firstLoad = _lastMessageCount <= 0;
                  _lastMessageCount = messages.length;
                  _scrollToBottom(animate: !firstLoad);
                }
                if (!_markedReadOnce) {
                  _markedReadOnce = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _markMessagesRead());
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length + (_otherTyping ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == messages.length) return const _TypingBubble();
                    final m = messages[i];
                    return _MessageBubble(
                      message: m,
                      isMine: m.senderId == myId,
                      isStaff: isStaff,
                    );
                  },
                );
              },
            ),
          ),
          if (locked)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: const Color(0xFFF1F4F5),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('تم إغلاق المحادثة ولا يمكن إرسال رسائل جديدة', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _uploadingImage ? null : _pickAndSendImage,
                      icon: _uploadingImage
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.image_outlined),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        decoration: const InputDecoration(hintText: 'اكتب رسالة...'),
                        onSubmitted: (_) => _send(),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE8EC)),
        ),
        child: const Text('يكتب الآن...', style: TextStyle(color: Colors.grey, fontSize: 12.5, fontStyle: FontStyle.italic)),
      ),
    );
  }
}

/// حاجز "استلام" — يمنع فتح محادثة استشارة/تذكرة لأي موظف قبل استلامها،
/// حتى يظهر اسم كل مستلم بوضوح بدل دخول عشوائي من عدة موظفين لنفس المحادثة.
class _ClaimGate extends ConsumerWidget {
  final String? claimedById;
  final bool claiming;
  final VoidCallback? onClaim;
  const _ClaimGate({required this.claimedById, required this.claiming, required this.onClaim});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimerProfile = claimedById != null ? ref.watch(profileByIdProvider(claimedById!)).valueOrNull : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(claimedById == null ? Icons.inbox_outlined : Icons.lock_person_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              claimedById == null ? 'هذه المحادثة غير مستلمة بعد' : 'تم استلامها من قِبل ${claimerProfile?.name ?? '...'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              claimedById == null ? 'استلمها أولًا لتتمكن من عرض المحادثة والرد عليها' : 'لا يمكنك عرض هذه المحادثة لأنها مستلمة من موظف آخر',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            if (claimedById == null) ...[
              const SizedBox(height: 20),
              GradientButton(label: 'استلام', icon: Icons.assignment_ind_outlined, loading: claiming, onPressed: onClaim),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final bool isMine;
  final bool isStaff;
  const _MessageBubble({required this.message, required this.isMine, required this.isStaff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = isMine;
    final senderProfile = message.senderId != null ? ref.watch(profileByIdProvider(message.senderId!)).valueOrNull : null;
    final avatarUrl = senderProfile?.avatarUrl;
    final isAppointmentNotice = message.senderRole == 'system' && message.content.contains('📅');

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.65),
      decoration: BoxDecoration(
        gradient: mine ? _kMineGradient : null,
        color: mine ? null : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: mine ? null : Border.all(color: const Color(0xFFDDE8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            Text(
              message.senderName,
              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700, height: 1.4),
            ),
            const SizedBox(height: 3),
          ],
          if (message.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                message.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  width: 160,
                  height: 120,
                  child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(width: 160, height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                },
              ),
            ),
            if (message.content.isNotEmpty) const SizedBox(height: 6),
          ],
          if (message.content.isNotEmpty) Text(message.content, style: TextStyle(color: mine ? Colors.white : Colors.black87)),
          if (isAppointmentNotice) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => context.push(isStaff ? '/appointments' : '/client/appointments'),
              icon: const Icon(Icons.calendar_month_outlined, size: 15),
              label: const Text('عرض المواعيد', style: TextStyle(fontSize: 12.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: mine ? Colors.white : AppColors.primary,
                side: BorderSide(color: mine ? Colors.white70 : AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('HH:mm').format(message.createdAt),
                style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : Colors.grey),
              ),
              if (mine && message.senderRole != 'system') ...[
                const SizedBox(width: 4),
                Icon(
                  message.readAt != null ? Icons.done_all : Icons.done,
                  size: 13,
                  color: message.readAt != null ? const Color(0xFF7EC8F2) : Colors.white70,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    final avatar = PersonAvatar(avatarUrl: avatarUrl, name: message.senderName, radius: 14);
    final spacer = const SizedBox(width: 6);

    return Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: mine ? [Flexible(child: bubble), spacer, avatar] : [avatar, spacer, Flexible(child: bubble)],
      ),
    );
  }
}
