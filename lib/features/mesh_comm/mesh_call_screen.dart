import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../l10n/app_localizations.dart';
import 'mesh_call_service.dart';
import 'mesh_models.dart';
import '../../app/theme.dart';

/// Full-screen in-call UI for an active offline voice call.
///
/// Shows the peer name, call duration, mute / speaker / end-call controls.
/// Pops automatically when the call ends or hangs up.
class MeshCallScreen extends StatefulWidget {
  final MeshPeer peer;
  final bool isIncoming;

  const MeshCallScreen({super.key, required this.peer, this.isIncoming = false});

  @override
  State<MeshCallScreen> createState() => _MeshCallScreenState();
}

class _MeshCallScreenState extends State<MeshCallScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _stateSub;
  late final AnimationController _pulseCtrl;
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;
  CallState _state = meshCallService.state;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _stateSub = meshCallService.callStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      if (s == CallState.active && _durationTimer == null) {
        _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _callDuration += const Duration(seconds: 1));
        });
      }
      if (s == CallState.idle) {
        Navigator.of(context).pop();
      }
    });

    // If incoming, just wait for user to accept/reject.
    // If outgoing, call is already initiated by the chat screen.
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _pulseCtrl.dispose();
    _durationTimer?.cancel();
    if (_state == CallState.ringing || _state == CallState.active) {
      meshCallService.hangUp();
    }
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isRinging = _state == CallState.ringing;
    final isActive = _state == CallState.active;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            // ── Avatar pulse ──────────────────────────────────────
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                final scale = isRinging
                    ? 1.0 + (_pulseCtrl.value * 0.08)
                    : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primaryContainer,
                      boxShadow: isRinging
                          ? [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.3 * _pulseCtrl.value),
                                blurRadius: 40,
                                spreadRadius: 20,
                              )
                            ]
                          : [],
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 60,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // ── Name ─────────────────────────────────────────────
            Text(
              widget.peer.displayName,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            // ── Status / duration ────────────────────────────────
            Text(
              isActive
                  ? _formatDuration(_callDuration)
                  : widget.isIncoming
                      ? l10n.meshIncomingCall
                      : l10n.meshCalling,
              style: TextStyle(
                fontSize: 16,
                color: cs.onSurfaceVariant,
              ),
            ),

            const Spacer(),

            // ── Incoming accept / reject row ─────────────────────
            if (isRinging && widget.isIncoming)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallButton(
                      icon: Icons.call_end_rounded,
                      color: cs.error,
                      label: l10n.meshRejectCall,
                      onTap: () {
                        HapticService.warn();
                        meshCallService.reject();
                      },
                    ),
                    _CallButton(
                      icon: Icons.call_rounded,
                      // Pairs with cs.error on the reject button above, so
                      // both call actions come from the token layer.
                      color: ShongjogTheme.toneFill(context, SemanticTone.success),
                      label: l10n.meshAcceptCall,
                      onTap: () {
                        HapticService.lightTap();
                        meshCallService.accept();
                      },
                    ),
                  ],
                ),
              ),

            // ── Active call controls ──────────────────────────────
            if (!isRinging || !widget.isIncoming)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallButton(
                      icon: meshCallService.muted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      color: meshCallService.muted
                          ? cs.error
                          : cs.surfaceContainerHighest,
                      iconColor: meshCallService.muted
                          ? cs.onError
                          : cs.onSurface,
                      label: meshCallService.muted ? l10n.meshMuted : l10n.meshMute,
                      onTap: () {
                        HapticService.lightTap();
                        setState(() => meshCallService.toggleMute());
                      },
                    ),
                    _CallButton(
                      icon: Icons.call_end_rounded,
                      color: cs.error,
                      iconColor: cs.onError,
                      label: l10n.meshEndCall,
                      onTap: () async {
                        HapticService.warn();
                        await meshCallService.hangUp();
                      },
                    ),
                    _CallButton(
                      icon: meshCallService.speakerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      color: meshCallService.speakerOn
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      iconColor: meshCallService.speakerOn
                          ? cs.onPrimaryContainer
                          : cs.onSurface,
                      label: meshCallService.speakerOn ? l10n.meshSpeaker : l10n.meshEarpiece,
                      onTap: () {
                        HapticService.lightTap();
                        setState(() => meshCallService.toggleSpeaker());
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.color,
    this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            child: Icon(icon, color: iconColor ?? cs.onSurface, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
