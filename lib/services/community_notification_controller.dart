class CommunityNotificationController {
  Future<void> initialize() async {}
  void setActiveCommunity(String? communityId) {}
  void updateMembership({
    required String userId,
    required List<Map<String, dynamic>> communities,
  }) {}
  void stop() {}
  void dispose() {}
}

