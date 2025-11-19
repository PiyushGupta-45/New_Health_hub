import 'package:flutter/material.dart';
import '../services/community_service.dart';
import '../services/auth_service.dart';

class CommunityInfoPage
    extends
        StatefulWidget {
  final Map<
    String,
    dynamic
  >
  community;

  const CommunityInfoPage({
    super.key,
    required this.community,
  });

  @override
  State<
    CommunityInfoPage
  >
  createState() => _CommunityInfoPageState();
}

class _CommunityInfoPageState
    extends
        State<
          CommunityInfoPage
        > {
  final CommunityService _communityService = CommunityService();
  final AuthService _authService = AuthService();

  bool _isOwner = false;
  String? _userId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<
    void
  >
  _setup() async {
    final user = await _authService.getStoredUser();
    if (user ==
        null)
      return;

    setState(
      () {
        _userId = user['id']?.toString();
        // Compare as strings to handle both ObjectId and string formats
        final communityOwnerId = widget.community['ownerId']?.toString();
        _isOwner = communityOwnerId != null && communityOwnerId == _userId;
      },
    );
  }

  Future<
    void
  >
  _leaveCommunity() async {
    setState(
      () => _loading = true,
    );

    final res = await _communityService.leaveCommunity(
      widget.community['_id'] ??
          widget.community['id'],
    );

    setState(
      () => _loading = false,
    );

    if (res['success']) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Left community successfully',
          ),
        ),
      );
      Navigator.pop(
        context,
        true,
      );
    } else {
      _showError(
        res['error'] ??
            "Failed to leave",
      );
    }
  }

  Future<
    void
  >
  _deleteCommunity() async {
    setState(
      () => _loading = true,
    );

    final res = await _communityService.deleteCommunity(
      widget.community['_id'] ??
          widget.community['id'],
    );

    setState(
      () => _loading = false,
    );

    if (res['success']) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Community deleted successfully',
          ),
        ),
      );
      Navigator.pop(
        context,
        true,
      );
    } else {
      _showError(
        res['error'] ??
            "Failed to delete",
      );
    }
  }

  Future<
    void
  >
  _transferOwnership(
    String newOwnerId,
  ) async {
    setState(
      () => _loading = true,
    );

    final res = await _communityService.transferOwnership(
      widget.community['_id'] ??
          widget.community['id'],
      newOwnerId,
    );

    setState(
      () => _loading = false,
    );

    if (res['success']) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Ownership transferred successfully',
          ),
        ),
      );
      Navigator.pop(
        context,
        true,
      );
    } else {
      _showError(
        res['error'] ??
            "Failed to transfer ownership",
      );
    }
  }

  void _showError(
    String? msg,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          msg ??
              "Unknown error",
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final community = widget.community;
    final members =
        community['members'] ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          community['name'],
        ),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(
                16,
              ),
              children: [
                // Community Details
                Card(
                  child: ListTile(
                    title: Text(
                      community['name'],
                    ),
                    subtitle: Text(
                      "${community['memberCount']} members • ${community['isPublic'] ? 'Public' : 'Private'}",
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),

                // Members List
                const Text(
                  "Members",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...members.map(
                  (
                    m,
                  ) {
                    return ListTile(
                      title: Text(
                        m['userName'] ??
                            "User",
                      ),
                      trailing:
                          (m['userId'] ==
                              community['ownerId'])
                          ? const Chip(
                              label: Text(
                                "Owner",
                              ),
                              backgroundColor: Colors.orange,
                            )
                          : null,
                      onTap: _isOwner
                          ? () {
                              if (m['userId'] !=
                                  _userId) {
                                _showTransferDialog(
                                  m,
                                );
                              }
                            }
                          : null,
                    );
                  },
                ).toList(),
                const SizedBox(
                  height: 40,
                ),

                // Buttons
                if (!_isOwner)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: _leaveCommunity,
                    child: const Text(
                      "Leave Community",
                    ),
                  ),

                if (_isOwner) ...[
                  ElevatedButton(
                    onPressed: () => _showDeleteDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      "Delete Community",
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder:
          (
            _,
          ) => AlertDialog(
            title: const Text(
              "Delete Community?",
            ),
            content: const Text(
              "This action cannot be undone.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                ),
                child: const Text(
                  "Cancel",
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                  );
                  _deleteCommunity();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text(
                  "Delete",
                ),
              ),
            ],
          ),
    );
  }

  void _showTransferDialog(
    member,
  ) {
    showDialog(
      context: context,
      builder:
          (
            _,
          ) => AlertDialog(
            title: const Text(
              "Transfer Ownership",
            ),
            content: Text(
              "Make ${member['userName']} the new owner?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                ),
                child: const Text(
                  "Cancel",
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                  );
                  _transferOwnership(
                    member['userId'],
                  );
                },
                child: const Text(
                  "Transfer",
                ),
              ),
            ],
          ),
    );
  }
}
