import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../application/call_controller.dart';
import '../application/call_providers.dart';
import '../application/call_state.dart';
import 'call_chat_panel.dart';

const _mobileBreakpoint = 700.0;

/// شاشة الاتصال — WebRTC أصلي بالكامل (بدون WebView)، بنفس فكرة call.html
/// السابقة: فيديو + تحكم بالكاميرا/الميكروفون + دردشة جلسة بصورة/اسم/مؤشر
/// قراءة، مع طي الدردشة تلقائيًا على شاشات الجوال وفتحها بزر عائم.
class CallViewScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String peerName;
  final bool isHost;
  final String? calleeId;

  const CallViewScreen({super.key, required this.roomId, required this.peerName, this.isHost = true, this.calleeId});

  @override
  ConsumerState<CallViewScreen> createState() => _CallViewScreenState();
}

class _CallViewScreenState extends ConsumerState<CallViewScreen> with WidgetsBindingObserver {
  late final CallParams _params;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _params = CallParams(roomId: widget.roomId, peerName: widget.peerName, isHost: widget.isHost, calleeId: widget.calleeId);
    final controller = ref.read(callControllerProvider(_params).notifier);
    controller.onPeerHangup = () {
      if (mounted) Navigator.of(context).maybePop();
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused || appState == AppLifecycleState.inactive) {
      final width = MediaQuery.sizeOf(context).width;
      if (width < _mobileBreakpoint) {
        ref.read(callControllerProvider(_params).notifier).setChatPanelOpen(false);
      }
    }
  }

  Future<bool> _confirmEnd() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنهاء الاتصال؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('إنهاء'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _endCall(CallController controller) async {
    if (await _confirmEnd()) {
      await controller.hangUp();
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callControllerProvider(_params));
    final controller = ref.read(callControllerProvider(_params).notifier);
    final isMobile = MediaQuery.sizeOf(context).width < _mobileBreakpoint;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmEnd()) {
          await controller.hangUp();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _CallHeader(peerName: widget.peerName, state: state, onEnd: () => _endCall(controller)),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          _VideoArea(controller: controller, state: state, peerName: widget.peerName),
                          if (isMobile)
                            Positioned(
                              top: 14,
                              left: 14,
                              child: _ChatToggleButton(
                                unread: state.chatUnread,
                                onTap: () => controller.setChatPanelOpen(true),
                              ),
                            ),
                          if (isMobile && state.chatPanelOpen)
                            Positioned.fill(
                              child: CallChatPanel(
                                messages: state.chatMessages,
                                onSend: controller.sendChatMessage,
                                isFullscreenOverlay: true,
                                onClose: () => controller.setChatPanelOpen(false),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isMobile)
                      SizedBox(
                        width: 300,
                        child: CallChatPanel(messages: state.chatMessages, onSend: controller.sendChatMessage),
                      ),
                  ],
                ),
              ),
              _CallControlsBar(state: state, controller: controller, onEnd: () => _endCall(controller)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallHeader extends StatelessWidget {
  final String peerName;
  final CallState state;
  final VoidCallback onEnd;
  const _CallHeader({required this.peerName, required this.state, required this.onEnd});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(gradient: AppGradients.tealToDark),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اتصال مع $peerName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                if (state.status == CallConnectionStatus.connected)
                  Text(_fmt(state.elapsed), style: const TextStyle(color: AppColors.gold, fontSize: 12, fontFamily: 'monospace')),
              ],
            ),
          ),
          if (state.status == CallConnectionStatus.connected) _QualityBars(bars: state.connectionQuality),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onEnd,
          ),
        ],
      ),
    );
  }
}

class _QualityBars extends StatelessWidget {
  final int bars;
  const _QualityBars({required this.bars});

  @override
  Widget build(BuildContext context) {
    final color = bars >= 3 ? Colors.greenAccent : (bars == 2 ? Colors.orangeAccent : Colors.redAccent);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(4, (i) {
          final active = i < bars;
          return Container(
            width: 3,
            height: 6.0 + i * 3,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            color: active ? color : Colors.white24,
          );
        }),
      ),
    );
  }
}

class _VideoArea extends StatelessWidget {
  final CallController controller;
  final CallState state;
  final String peerName;
  const _VideoArea({required this.controller, required this.state, required this.peerName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF16213E),
      child: Stack(
        children: [
          Positioned.fill(child: RTCVideoView(controller.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
          if (state.status != CallConnectionStatus.connected)
            Positioned.fill(child: _StatusOverlay(state: state, peerName: peerName)),
          Positioned(
            bottom: 14,
            left: 14,
            width: 100,
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.gold, width: 2), borderRadius: BorderRadius.circular(12)),
                child: state.camOn
                    ? RTCVideoView(controller.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                    : const ColoredBox(color: Color(0xFF2D5869), child: Icon(Icons.videocam_off, color: Colors.white54)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusOverlay extends StatelessWidget {
  final CallState state;
  final String peerName;
  const _StatusOverlay({required this.state, required this.peerName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC0F3460),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PersonAvatar(avatarUrl: null, name: peerName, radius: 42),
          const SizedBox(height: 18),
          if (state.status != CallConnectionStatus.failed) const CircularProgressIndicator(color: AppColors.gold),
          const SizedBox(height: 14),
          Text(
            state.errorMessage ?? state.statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ChatToggleButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;
  const _ChatToggleButton({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(23),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.85), shape: BoxShape.circle),
        child: Stack(
          children: [
            const Center(child: Icon(Icons.chat_bubble, color: Colors.white, size: 20)),
            if (unread > 0)
              Positioned(
                top: 2,
                right: 2,
                child: NotificationCountBadge(count: unread),
              ),
          ],
        ),
      ),
    );
  }
}

class _CallControlsBar extends StatelessWidget {
  final CallState state;
  final CallController controller;
  final VoidCallback onEnd;
  const _CallControlsBar({required this.state, required this.controller, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: const Color(0xFF0F1E2E),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ControlButton(
            icon: state.micOn ? Icons.mic : Icons.mic_off,
            label: 'الميكروفون',
            active: !state.micOn,
            onTap: controller.toggleMic,
          ),
          const SizedBox(width: 24),
          _ControlButton(
            icon: state.camOn ? Icons.videocam : Icons.videocam_off,
            label: 'الكاميرا',
            active: state.camOn,
            onTap: controller.toggleCam,
          ),
          const SizedBox(width: 24),
          _ControlButton(icon: Icons.call_end, label: 'إنهاء', color: AppColors.danger, big: true, onTap: onEnd),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool big;
  final Color? color;
  final VoidCallback onTap;
  const _ControlButton({required this.icon, required this.label, this.active = false, this.big = false, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final size = big ? 56.0 : 48.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? (active ? AppColors.primary : Colors.white12),
            ),
            child: Icon(icon, color: Colors.white, size: big ? 26 : 20),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
