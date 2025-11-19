import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'community_service.dart';
import 'notification_service.dart';

class CommunityNotificationController {
  CommunityNotificationController({
    CommunityService? communityService,
  }) : _communityService = communityService ?? CommunityService();

  final CommunityService _communityService;
  final NotificationService _notificationService = NotificationService();

  Timer? _pollTimer;
  bool _initialized = false;
  bool _isPolling = false;
  String? _userId;
  List<Map<String, dynamic>> _communities = [];
  final Map<String, String> _lastMessageIds = {};
  String? _activeCommunityId;

  Future<void> initialize({
    Function(NotificationResponse)? onNotificationResponse,
  }) async {
    if (_initialized) return;
    await _notificationService.initialize();
    if (onNotificationResponse != null) {
      _notificationService.setGlobalResponseHandler(onNotificationResponse);
    }
    _initialized = true;
  }

  void setActiveCommunity(String? communityId) {
    _activeCommunityId = communityId;
  }

  void updateMembership({
    required String userId,
    required List<Map<String, dynamic>> communities,
  }) {
    _userId = userId;
    _communities = communities;
    _syncLastSeenCache();
    _restartPolling();
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
    _lastMessageIds.clear();
  }

  void dispose() {
    stop();
  }

  void _syncLastSeenCache() {
    final validIds = _communities
        .map(
          (community) => community['_id']?.toString(),
        )
        .whereType<String>()
        .toSet();

    _lastMessageIds.removeWhere(
      (key, value) => !validIds.contains(key),
    );
  }

  void _restartPolling() {
    _pollTimer?.cancel();
    if (_userId == null || _communities.isEmpty) {
      return;
    }

    _pollTimer = Timer.periodic(
      const Duration(
        seconds: 25,
      ),
      (
        _,
      ) {
        _pollLatestMessages();
      },
    );

    _pollLatestMessages(
      bootstrap: true,
    );
  }

  Future<void> _pollLatestMessages({
    bool bootstrap = false,
  }) async {
    if (_isPolling ||
        _userId ==
            null ||
        _communities.isEmpty) {
      return;
    }

    _isPolling = true;
    try {
      for (final community in _communities) {
        final communityId = community['_id']?.toString();
        if (communityId ==
                null ||
            communityId.isEmpty) {
          continue;
        }

        final response = await _communityService.getMessages(
          communityId,
          limit: 1,
          sortOrder: 'desc',
        );

        if (response['success'] !=
            true) {
          continue;
        }

        final data = response['data'] as List? ?? [];
        if (data.isEmpty) continue;

        final latestRaw = data.first;
        if (latestRaw is! Map) continue;
        final latestMessage = Map<String, dynamic>.from(
          latestRaw as Map,
        );

        final messageId = latestMessage['_id']?.toString();
        final senderId = latestMessage['userId']?.toString();
        final body = latestMessage['message']?.toString() ?? '';

        if (messageId ==
                null ||
            body.isEmpty) {
          continue;
        }

        if (bootstrap) {
          _lastMessageIds[communityId] = messageId;
          continue;
        }

        if (_lastMessageIds[communityId] ==
            messageId) {
          continue;
        }

        _lastMessageIds[communityId] = messageId;

        if (senderId ==
                _userId ||
            _activeCommunityId ==
                communityId) {
          continue;
        }

        final senderName = latestMessage['userName']?.toString() ?? 'Someone';
        final communityName = community['name']?.toString() ?? 'Community';

        final notificationId = NotificationService.stableIdFromKey(
          '${communityId}_$messageId',
          scope: 'chat',
        );

        await _notificationService.showChatNotification(
          id: notificationId,
          title: '$senderName in $communityName',
          body: body,
          communityId: communityId,
          communityName: communityName,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Community notification poll failed: $error');
      debugPrint('$stackTrace');
    } finally {
      _isPolling = false;
    }
  }
}

