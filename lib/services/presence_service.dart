import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks how many clients are currently online via a shared Supabase
/// Realtime Presence channel (`global_presence`).
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  static const String channelName = 'global_presence';

  final ValueNotifier<int> onlineCount = ValueNotifier<int>(0);

  // Unique per app instance so every tab/device counts once.
  // Avoids `1 << 32`, which evaluates to 0 on the web (32-bit shifts).
  final String _clientKey = _generateClientKey();

  static String _generateClientKey() {
    try {
      return '${DateTime.now().microsecondsSinceEpoch}-'
          '${math.Random().nextInt(0x7FFFFFFF)}';
    } catch (_) {
      return DateTime.now().microsecondsSinceEpoch.toString();
    }
  }

  RealtimeChannel? _channel;
  bool _started = false;

  SupabaseClient get _client => Supabase.instance.client;

  void start() {
    if (_started) return;
    try {
      _started = true;
      WidgetsBinding.instance.addObserver(this);
      _join();
    } catch (error) {
      debugPrint('Presence start failed: $error');
    }
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    await _leave();
  }

  void _join() {
    if (_channel != null) return;
    try {
      final channel = _client.channel(
        channelName,
        opts: RealtimeChannelConfig(key: _clientKey),
      );
      _channel = channel;

      channel
          .onPresenceSync((_) => _updateCount(channel))
          .onPresenceJoin((_) => _updateCount(channel))
          .onPresenceLeave((_) => _updateCount(channel))
          .subscribe((status, error) async {
        try {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await channel.track({
              'online_at': DateTime.now().toUtc().toIso8601String(),
              'user_id': _client.auth.currentUser?.id,
            });
            _updateCount(channel);
          }
        } catch (e) {
          debugPrint('Presence track failed: $e');
        }
      });
    } catch (error) {
      _channel = null;
      debugPrint('Presence join failed: $error');
    }
  }

  Future<void> _leave() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    try {
      await channel.untrack();
    } catch (_) {}
    try {
      await _client.removeChannel(channel);
    } catch (_) {}
    onlineCount.value = 0;
  }

  void _updateCount(RealtimeChannel channel) {
    try {
      if (!identical(channel, _channel)) return;
      var total = 0;
      for (final state in channel.presenceState()) {
        total += state.presences.length;
      }
      onlineCount.value = total;
    } catch (error) {
      debugPrint('Presence count failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _join();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _leave();
        break;
      default:
        break;
    }
  }
}
