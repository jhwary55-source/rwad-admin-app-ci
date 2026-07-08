import '../data/call_chat_message.dart';

enum CallConnectionStatus {
  preparing,
  waitingForPeer,
  connecting,
  connected,
  reconnecting,
  ended,
  failed,
}

class CallState {
  final CallConnectionStatus status;
  final String statusText;
  final bool micOn;
  final bool camOn;
  final Duration elapsed;
  final int connectionQuality; // 0..4
  final List<CallChatMessage> chatMessages;
  final int chatUnread;
  final bool chatPanelOpen;
  final String? errorMessage;
  final int retryCount;

  const CallState({
    this.status = CallConnectionStatus.preparing,
    this.statusText = 'جارٍ التجهيز...',
    this.micOn = true,
    this.camOn = true,
    this.elapsed = Duration.zero,
    this.connectionQuality = 0,
    this.chatMessages = const [],
    this.chatUnread = 0,
    this.chatPanelOpen = false,
    this.errorMessage,
    this.retryCount = 0,
  });

  CallState copyWith({
    CallConnectionStatus? status,
    String? statusText,
    bool? micOn,
    bool? camOn,
    Duration? elapsed,
    int? connectionQuality,
    List<CallChatMessage>? chatMessages,
    int? chatUnread,
    bool? chatPanelOpen,
    String? errorMessage,
    int? retryCount,
  }) {
    return CallState(
      status: status ?? this.status,
      statusText: statusText ?? this.statusText,
      micOn: micOn ?? this.micOn,
      camOn: camOn ?? this.camOn,
      elapsed: elapsed ?? this.elapsed,
      connectionQuality: connectionQuality ?? this.connectionQuality,
      chatMessages: chatMessages ?? this.chatMessages,
      chatUnread: chatUnread ?? this.chatUnread,
      chatPanelOpen: chatPanelOpen ?? this.chatPanelOpen,
      errorMessage: errorMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
