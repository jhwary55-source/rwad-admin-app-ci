import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/notifications/push_sender.dart';
import '../data/call_chat_message.dart';
import '../data/call_signaling_repository.dart';
import 'call_state.dart';

/// خوادم STUN/TURN — نفس القائمة المستخدمة بصفحة call.html بالموقع (خوادم
/// STUN وحدها تفشل بصمت عندما يكون الطرفان بشبكتين مختلفتين تمامًا خلف NAT
/// صارم؛ خادم TURN المجاني (Open Relay Project) ضروري لعبور هذي الحالة).
const _iceServers = [
  {'urls': 'stun:stun.l.google.com:19302'},
  {'urls': 'stun:stun1.l.google.com:19302'},
  {'urls': 'turn:openrelay.metered.ca:80', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
  {'urls': 'turn:openrelay.metered.ca:443', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
  {'urls': 'turn:openrelay.metered.ca:443?transport=tcp', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
];

class CallParams {
  final String roomId;
  final String peerName;
  final bool isHost;
  final String? calleeId;

  const CallParams({required this.roomId, required this.peerName, required this.isHost, this.calleeId});

  @override
  bool operator ==(Object other) =>
      other is CallParams && other.roomId == roomId && other.peerName == peerName && other.isHost == isHost && other.calleeId == calleeId;

  @override
  int get hashCode => Object.hash(roomId, peerName, isHost, calleeId);
}

class CallController extends StateNotifier<CallState> {
  final CallSignalingRepository _signaling;
  final PushSender _pushSender;
  final CallParams params;
  final String myId;
  final String myName;
  final String? myAvatarUrl;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  RealtimeChannel? _channel;
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  Timer? _timerTick;
  Timer? _qualityTimer;
  Timer? _retryTimer;
  DateTime? _startedAt;
  bool _offerSent = false;
  bool _remoteDescSet = false;
  bool _disposed = false;
  final _pendingRemoteCandidates = <RTCIceCandidate>[];
  int _msgSeq = 0;

  /// يُستدعى عند إنهاء الطرف الآخر للمكالمة أو مغادرته — الواجهة تستمع لهذا
  /// لإغلاق الشاشة تلقائيًا (مطابقة لحدث 'call_ended' بصفحة call.html السابقة).
  void Function()? onPeerHangup;

  CallController({
    required CallSignalingRepository signaling,
    required PushSender pushSender,
    required this.params,
    required this.myId,
    required this.myName,
    this.myAvatarUrl,
  })  : _signaling = signaling,
        _pushSender = pushSender,
        super(const CallState());

  Future<void> start() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    if (!kIsWeb && Platform.isAndroid) {
      final statuses = await [Permission.camera, Permission.microphone].request();
      if (statuses.values.any((s) => !s.isGranted)) {
        _setState(state.copyWith(
          status: CallConnectionStatus.failed,
          errorMessage: 'يحتاج الاتصال إذن الكاميرا والميكروفون لتشغيله. يرجى منح الإذن من إعدادات التطبيق.',
        ));
        return;
      }
    }

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user', 'width': {'ideal': 1280}, 'height': {'ideal': 720}},
      });
    } catch (_) {
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
        _setState(state.copyWith(camOn: false));
      } catch (e) {
        _setState(state.copyWith(
          status: CallConnectionStatus.failed,
          errorMessage: 'تعذّر الوصول للكاميرا/الميكروفون: $e',
        ));
        return;
      }
    }
    localRenderer.srcObject = _localStream;

    _channel = _signaling.channelFor(params.roomId);
    _wireChannel(_channel!);
    _channel!.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _signaling.trackPresence(_channel!, {
          'role': params.isHost ? 'host' : 'guest',
          'userId': myId,
          'name': myName,
          'avatarUrl': myAvatarUrl,
          'mediaReady': true,
        });
        if (params.isHost) {
          _setState(state.copyWith(status: CallConnectionStatus.waitingForPeer, statusText: 'في انتظار انضمام العميل...'));
          if (params.calleeId != null) _notifyCallee();
        } else {
          _setState(state.copyWith(status: CallConnectionStatus.waitingForPeer, statusText: 'جارٍ الاتصال...'));
          _maybeSendOfferFromPresence();
        }
      }
    });
  }

  Future<void> _notifyCallee() async {
    try {
      await _pushSender.send(
        userIds: [params.calleeId!],
        title: 'مكالمة واردة 📞',
        message: '$myName يتصل بك الآن',
        imageUrl: myAvatarUrl,
        data: {'type': 'call', 'room': params.roomId, 'name': myName},
      );
    } catch (_) {}
  }

  void _wireChannel(RealtimeChannel channel) {
    channel.onPresenceSync((_) => _maybeSendOfferFromPresence());
    channel.onPresenceJoin((_) => _maybeSendOfferFromPresence());

    channel.onBroadcast(event: 'offer', callback: (payload) async {
      if (payload['senderId'] == myId || params.isHost == false) return;
      await _ensurePeerConnection();
      await _pc!.setRemoteDescription(RTCSessionDescription(payload['sdp'] as String, 'offer'));
      _remoteDescSet = true;
      await _flushPendingCandidates();
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      _signaling.sendAnswer(channel, sdp: answer.sdp ?? '', senderId: myId);
    });

    channel.onBroadcast(event: 'answer', callback: (payload) async {
      if (payload['senderId'] == myId || params.isHost || _pc == null) return;
      await _pc!.setRemoteDescription(RTCSessionDescription(payload['sdp'] as String, 'answer'));
      _remoteDescSet = true;
      await _flushPendingCandidates();
    });

    channel.onBroadcast(event: 'ice-candidate', callback: (payload) async {
      if (payload['senderId'] == myId) return;
      final candidate = RTCIceCandidate(
        payload['candidate'] as String?,
        payload['sdpMid'] as String?,
        payload['sdpMLineIndex'] as int?,
      );
      if (_pc != null && _remoteDescSet) {
        try {
          await _pc!.addCandidate(candidate);
        } catch (_) {}
      } else {
        _pendingRemoteCandidates.add(candidate);
      }
    });

    channel.onBroadcast(event: 'hangup', callback: (payload) {
      if (payload['senderId'] == myId) return;
      _setState(state.copyWith(status: CallConnectionStatus.ended, statusText: 'أنهى الطرف الآخر المكالمة'));
      onPeerHangup?.call();
    });

    channel.onBroadcast(event: 'chat-message', callback: (payload) {
      if (payload['senderId'] == myId) return;
      final msg = CallChatMessage(
        id: payload['msgId'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        senderId: payload['senderId'] as String? ?? '',
        senderName: payload['senderName'] as String? ?? params.peerName,
        senderAvatarUrl: payload['senderAvatarUrl'] as String?,
        text: payload['text'] as String? ?? '',
        sentAt: DateTime.now(),
        isMe: false,
      );
      final list = [...state.chatMessages, msg];
      if (state.chatPanelOpen) {
        _sendChatRead();
        _setState(state.copyWith(chatMessages: list));
      } else {
        _setState(state.copyWith(chatMessages: list, chatUnread: state.chatUnread + 1));
      }
    });

    channel.onBroadcast(event: 'chat-read', callback: (payload) {
      if (payload['readerId'] == myId) return;
      final updated = state.chatMessages.map((m) {
        if (m.isMe) m.read = true;
        return m;
      }).toList();
      _setState(state.copyWith(chatMessages: updated));
    });
  }

  void _maybeSendOfferFromPresence() {
    if (params.isHost || _offerSent || _channel == null) return;
    final states = _channel!.presenceState();
    final hasReadyHost = states.any((s) => s.presences.any((p) => p.payload['role'] == 'host' && p.payload['mediaReady'] == true));
    if (hasReadyHost) _sendOffer();
  }

  Future<void> _sendOffer() async {
    if (_offerSent) return;
    _offerSent = true;
    _setState(state.copyWith(status: CallConnectionStatus.connecting, statusText: 'جارٍ الاتصال بالمحامي...'));
    await _ensurePeerConnection();
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _signaling.sendOffer(_channel!, sdp: offer.sdp ?? '', senderId: myId);
    _startRetryTimer();
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 3), () {
      if (_disposed || state.status == CallConnectionStatus.connected) return;
      if (state.retryCount >= 12) {
        _setState(state.copyWith(status: CallConnectionStatus.failed, statusText: 'المضيف غير متاح حالياً.'));
        return;
      }
      _setState(state.copyWith(retryCount: state.retryCount + 1, statusText: 'في انتظار المحامي... (محاولة ${state.retryCount + 1})'));
      _offerSent = false;
      _sendOffer();
    });
  }

  Future<void> _ensurePeerConnection() async {
    if (_pc != null) return;
    _pc = await createPeerConnection({'iceServers': _iceServers});
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _signaling.sendIceCandidate(
        _channel!,
        candidate: candidate.candidate!,
        sdpMid: candidate.sdpMid,
        sdpMLineIndex: candidate.sdpMLineIndex,
        senderId: myId,
      );
    };
    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        _onConnected();
      }
    };
    _pc!.onConnectionState = (rtcState) {
      if (rtcState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          rtcState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        if (state.status == CallConnectionStatus.connected) {
          _setState(state.copyWith(status: CallConnectionStatus.reconnecting, statusText: 'جارٍ إعادة الاتصال...'));
        }
      }
    };
  }

  void _onConnected() {
    _retryTimer?.cancel();
    _timerTick?.cancel();
    _startedAt = DateTime.now();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startedAt != null) _setState(state.copyWith(elapsed: DateTime.now().difference(_startedAt!)));
    });
    _startQualityMonitor();
    _setState(state.copyWith(status: CallConnectionStatus.connected, statusText: '', retryCount: 0));
  }

  void _startQualityMonitor() {
    _qualityTimer?.cancel();
    _qualityTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_pc == null) return;
      try {
        final reports = await _pc!.getStats();
        double rtt = 0;
        for (final r in reports) {
          if (r.type == 'remote-inbound-rtp' && r.values['roundTripTime'] != null) {
            rtt = (r.values['roundTripTime'] as num).toDouble();
          }
        }
        final bars = rtt == 0 ? 3 : (rtt < 0.15 ? 4 : (rtt < 0.3 ? 2 : 1));
        _setState(state.copyWith(connectionQuality: bars));
      } catch (_) {
        _setState(state.copyWith(connectionQuality: 3));
      }
    });
  }

  Future<void> _flushPendingCandidates() async {
    for (final c in _pendingRemoteCandidates) {
      try {
        await _pc!.addCandidate(c);
      } catch (_) {}
    }
    _pendingRemoteCandidates.clear();
  }

  void toggleMic() {
    final next = !state.micOn;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = next);
    _setState(state.copyWith(micOn: next));
  }

  void toggleCam() {
    final next = !state.camOn;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = next);
    _setState(state.copyWith(camOn: next));
  }

  void sendChatMessage(String text) {
    if (text.trim().isEmpty || _channel == null) return;
    final id = '${myId}_${++_msgSeq}';
    _signaling.sendChatMessage(_channel!, msgId: id, senderId: myId, senderName: myName, senderAvatarUrl: myAvatarUrl, text: text.trim());
    final msg = CallChatMessage(id: id, senderId: myId, senderName: myName, senderAvatarUrl: myAvatarUrl, text: text.trim(), sentAt: DateTime.now(), isMe: true);
    _setState(state.copyWith(chatMessages: [...state.chatMessages, msg]));
  }

  void _sendChatRead() {
    if (_channel != null) _signaling.sendChatRead(_channel!, readerId: myId);
  }

  void setChatPanelOpen(bool open) {
    _setState(state.copyWith(chatPanelOpen: open, chatUnread: open ? 0 : state.chatUnread));
    if (open) _sendChatRead();
  }

  Future<void> hangUp() async {
    if (_channel != null) _signaling.sendHangup(_channel!, senderId: myId);
    await _teardown();
    _setState(state.copyWith(status: CallConnectionStatus.ended));
  }

  Future<void> _teardown() async {
    _timerTick?.cancel();
    _qualityTimer?.cancel();
    _retryTimer?.cancel();
    try {
      _localStream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    try {
      await _pc?.close();
    } catch (_) {}
    if (_channel != null) {
      try {
        await _signaling.removeChannel(_channel!);
      } catch (_) {}
    }
  }

  void _setState(CallState next) {
    if (!_disposed) state = next;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_teardown());
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
