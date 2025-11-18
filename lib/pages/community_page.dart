// Community page with create/join community and chat functionality

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/community_service.dart';
import '../services/auth_service.dart';
import 'dart:async';

// IMPORT the Community Info Page
import 'community_info_page.dart';

class CommunityPage
    extends
        StatefulWidget {
  const CommunityPage({
    super.key,
  });

  @override
  State<
    CommunityPage
  >
  createState() => _CommunityPageState();
}

class _CommunityPageState
    extends
        State<
          CommunityPage
        > {
  final CommunityService _communityService = CommunityService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _communityNameController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<
    Map<
      String,
      dynamic
    >
  >
  _myCommunities = [];
  List<
    Map<
      String,
      dynamic
    >
  >
  _publicCommunities = [];
  List<
    Map<
      String,
      dynamic
    >
  >
  _messages = [];
  Map<
    String,
    dynamic
  >?
  _selectedCommunity;
  bool _isLoading = false;
  bool _isLoadingMessages = false;
  bool _isAuthenticated = false;
  String? _userId;
  Timer? _messageRefreshTimer;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    // Refresh auth status periodically in case user signs in/out elsewhere
    _checkTimer = Timer.periodic(
      const Duration(
        seconds: 2,
      ),
      (
        timer,
      ) {
        if (!_isAuthenticated &&
            mounted) {
          _checkAuthStatus();
        } else {
          timer.cancel();
        }
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _communityNameController.dispose();
    _joinCodeController.dispose();
    _scrollController.dispose();
    _messageRefreshTimer?.cancel();
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<
    void
  >
  _checkAuthStatus() async {
    final user = await _authService.getStoredUser();
    final token = await _authService.getAuthToken();

    if (!mounted) return;

    if (user ==
            null ||
        token ==
            null ||
        token.isEmpty) {
      setState(
        () {
          _isAuthenticated = false;
          _userId = null;
          _myCommunities.clear();
          _publicCommunities.clear();
          _messages.clear();
          _selectedCommunity = null;
        },
      );
      return;
    }

    setState(
      () {
        _userId = user['id']?.toString();
        _isAuthenticated = true;
      },
    );

    await _loadMyCommunities();
    await _loadPublicCommunities();
  }

  bool _isAuthError(
    String? error,
  ) {
    if (error ==
        null)
      return false;
    final normalized = error.toLowerCase();
    return normalized.contains(
          'auth',
        ) ||
        normalized.contains(
          'token',
        ) ||
        normalized.contains(
          'sign in',
        ) ||
        normalized.contains(
          'signin',
        ) ||
        normalized.contains(
          'unauthorized',
        ) ||
        normalized.contains(
          'expired',
        );
  }

  Future<
    void
  >
  _loadMyCommunities() async {
    if (!_isAuthenticated) return;
    setState(
      () => _isLoading = true,
    );

    final result = await _communityService.getMyCommunities();
    if (result['success'] ==
            true &&
        mounted) {
      setState(
        () {
          _myCommunities =
              List<
                Map<
                  String,
                  dynamic
                >
              >.from(
                result['data'] ??
                    [],
              );
          _isLoading = false;
        },
      );
    } else {
      final error = result['error']?.toString();
      if (_isAuthError(
        error,
      )) {
        await _authService.clearUser();
        if (mounted) {
          setState(
            () {
              _isAuthenticated = false;
              _userId = null;
            },
          );
        }
      }
      setState(
        () => _isLoading = false,
      );
      if (mounted &&
          error !=
              null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              error,
            ),
          ),
        );
      }
    }
  }

  Future<
    void
  >
  _loadPublicCommunities() async {
    if (!_isAuthenticated) return;

    final result = await _communityService.getPublicCommunities();
    if (result['success'] ==
            true &&
        mounted) {
      setState(
        () {
          _publicCommunities =
              List<
                Map<
                  String,
                  dynamic
                >
              >.from(
                result['data'] ??
                    [],
              );
        },
      );
    } else {
      final error = result['error']?.toString();
      if (_isAuthError(
        error,
      )) {
        await _authService.clearUser();
        if (mounted) {
          setState(
            () {
              _isAuthenticated = false;
              _userId = null;
            },
          );
        }
      }
      if (mounted &&
          error !=
              null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              error,
            ),
          ),
        );
      }
    }
  }

  Future<
    void
  >
  _loadMessages() async {
    if (_selectedCommunity ==
            null ||
        _isLoadingMessages)
      return;
    setState(
      () => _isLoadingMessages = true,
    );

    final result = await _communityService.getMessages(
      _selectedCommunity!['_id'],
    );
    if (result['success'] ==
            true &&
        mounted) {
      setState(
        () {
          _messages =
              List<
                Map<
                  String,
                  dynamic
                >
              >.from(
                result['data'] ??
                    [],
              );
          _isLoadingMessages = false;
        },
      );
      // Auto-scroll to bottom
      if (_scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback(
          (
            _,
          ) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(
                  milliseconds: 300,
                ),
                curve: Curves.easeOut,
              );
            }
          },
        );
      }
    } else {
      setState(
        () => _isLoadingMessages = false,
      );
    }
  }

  Future<
    void
  >
  _sendMessage() async {
    if (_selectedCommunity ==
        null)
      return;
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    final result = await _communityService.sendMessage(
      message,
      _selectedCommunity!['_id'],
    );
    if (result['success'] ==
        true) {
      _loadMessages();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              result['error'] ??
                  'Failed to send message',
            ),
          ),
        );
      }
    }
  }

  Future<
    void
  >
  _createCommunity() async {
    final name = _communityNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a community name',
          ),
        ),
      );
      return;
    }

    bool? isPublic;
    await showDialog(
      context: context,
      builder:
          (
            context,
          ) {
            bool selectedIsPublic = true;
            return StatefulBuilder(
              builder:
                  (
                    context,
                    setState,
                  ) => AlertDialog(
                    title: const Text(
                      'Create Community',
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<
                          bool
                        >(
                          title: const Text(
                            'Public',
                          ),
                          subtitle: const Text(
                            'Anyone can join',
                          ),
                          value: true,
                          groupValue: selectedIsPublic,
                          onChanged:
                              (
                                value,
                              ) {
                                setState(
                                  () => selectedIsPublic = value!,
                                );
                              },
                        ),
                        RadioListTile<
                          bool
                        >(
                          title: const Text(
                            'Private',
                          ),
                          subtitle: const Text(
                            'Only people with code can join',
                          ),
                          value: false,
                          groupValue: selectedIsPublic,
                          onChanged:
                              (
                                value,
                              ) {
                                setState(
                                  () => selectedIsPublic = value!,
                                );
                              },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(),
                        child: const Text(
                          'Cancel',
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          isPublic = selectedIsPublic;
                          Navigator.of(
                            context,
                          ).pop();
                        },
                        child: const Text(
                          'Create',
                        ),
                      ),
                    ],
                  ),
            );
          },
    );

    if (isPublic !=
        null) {
      await _doCreateCommunity(
        name,
        isPublic!,
      );
    }
  }

  Future<
    void
  >
  _doCreateCommunity(
    String name,
    bool isPublic,
  ) async {
    setState(
      () => _isLoading = true,
    );

    final result = await _communityService.createCommunity(
      name: name,
      isPublic: isPublic,
    );

    if (result['success'] ==
            true &&
        mounted) {
      _communityNameController.clear();
      await _loadMyCommunities();
      await _loadPublicCommunities();

      // Select the newly created community
      final newCommunity = result['data'];
      setState(
        () {
          _selectedCommunity = newCommunity;
          _isLoading = false;
        },
      );

      _startMessageRefresh();
      _loadMessages();

      // Show join code if private
      if (!isPublic &&
          newCommunity['joinCode'] !=
              null) {
        _showJoinCodeDialog(
          newCommunity['joinCode'],
        );
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Community created successfully!',
          ),
        ),
      );
    } else {
      setState(
        () => _isLoading = false,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              result['error'] ??
                  'Failed to create community',
            ),
          ),
        );
      }
    }
  }

  Future<
    void
  >
  _joinPublicCommunity(
    String communityId,
  ) async {
    setState(
      () => _isLoading = true,
    );

    final result = await _communityService.joinCommunity(
      communityId,
    );
    if (result['success'] ==
            true &&
        mounted) {
      await _loadMyCommunities();
      final community = result['data'];
      setState(
        () {
          _selectedCommunity = {
            '_id': community['_id'],
            'name': community['name'],
          };
          _isLoading = false;
        },
      );
      _startMessageRefresh();
      _loadMessages();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Successfully joined the community!',
          ),
        ),
      );
    } else {
      setState(
        () => _isLoading = false,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              result['error'] ??
                  'Failed to join community',
            ),
          ),
        );
      }
    }
  }

  Future<
    void
  >
  _joinWithCode() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a join code',
          ),
        ),
      );
      return;
    }

    setState(
      () => _isLoading = true,
    );

    final result = await _communityService.joinWithCode(
      code,
    ); // placeholder, will be replaced below
  }

  // Note: The above accidental placeholder is replaced with the real call:
  Future<
    void
  >
  _joinWithCode_fixed() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a join code',
          ),
        ),
      );
      return;
    }
    setState(
      () => _isLoading = true,
    );
    final result = await _communityService.joinWithCode(
      code,
    );
    if (result['success'] ==
            true &&
        mounted) {
      _joinCodeController.clear();
      await _loadMyCommunities();
      final community = result['data'];
      setState(
        () {
          _selectedCommunity = {
            '_id': community['_id'],
            'name': community['name'],
          };
          _isLoading = false;
        },
      );
      _startMessageRefresh();
      _loadMessages();
      Navigator.of(
        context,
      ).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Successfully joined the community!',
          ),
        ),
      );
    } else {
      setState(
        () => _isLoading = false,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              result['error'] ??
                  'Failed to join community',
            ),
          ),
        );
      }
    }
  }

  void _selectCommunity(
    Map<
      String,
      dynamic
    >
    community,
  ) {
    setState(
      () {
        _selectedCommunity = community;
      },
    );
    _startMessageRefresh();
    _loadMessages();
  }

  void _startMessageRefresh() {
    _messageRefreshTimer?.cancel();
    _messageRefreshTimer = Timer.periodic(
      const Duration(
        seconds: 5,
      ),
      (
        _,
      ) => _loadMessages(),
    );
  }

  void _showJoinCodeDialog(
    String joinCode,
  ) {
    showDialog(
      context: context,
      builder:
          (
            context,
          ) => AlertDialog(
            title: const Text(
              'Private Community Join Code',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Share this code with others to let them join:',
                ),
                const SizedBox(
                  height: 16,
                ),
                Container(
                  padding: const EdgeInsets.all(
                    16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(
                      8,
                    ),
                    border: Border.all(
                      color: Colors.indigo.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        joinCode,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: joinCode,
                            ),
                          );
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Code copied to clipboard!',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(),
                child: const Text(
                  'OK',
                ),
              ),
            ],
          ),
    );
  }

  void _showJoinCodeInputDialog() {
    showDialog(
      context: context,
      builder:
          (
            context,
          ) => AlertDialog(
            title: const Text(
              'Join Private Community',
            ),
            content: TextField(
              controller: _joinCodeController,
              decoration: const InputDecoration(
                labelText: 'Enter Join Code',
                hintText: 'ABC123',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _joinCodeController.clear();
                  Navigator.of(
                    context,
                  ).pop();
                },
                child: const Text(
                  'Cancel',
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  // call fixed implementation
                  await _joinWithCode_fixed();
                },
                child: const Text(
                  'Join',
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    // Check if user is signed in
    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: const Color(
          0xFFF4F6F9,
        ),
        appBar: AppBar(
          title: const Text(
            'Community',
          ),
          backgroundColor: Colors.indigo.shade600,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.refresh,
              ),
              onPressed: () {
                _checkAuthStatus();
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(
              24.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(
                  height: 16,
                ),
                Text(
                  'Sign-In Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  'Please sign in to access the community features.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(
                  height: 24,
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _checkAuthStatus();
                  },
                  icon: const Icon(
                    Icons.refresh,
                  ),
                  label: const Text(
                    'Check Again',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  'If you just signed in, click "Check Again" to refresh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Chat view - shown when a community is selected
    if (_selectedCommunity !=
        null) {
      return Scaffold(
        backgroundColor: const Color(
          0xFFF4F6F9,
        ),
        appBar: AppBar(
          title: Text(
            _selectedCommunity!['name'] ??
                'Community',
          ),
          backgroundColor: Colors.indigo.shade600,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
            ),
            onPressed: () {
              setState(
                () {
                  _selectedCommunity = null;
                  _messages = [];
                },
              );
              _messageRefreshTimer?.cancel();
            },
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child:
                  _isLoadingMessages &&
                      _messages.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet. Start the conversation!',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(
                        16,
                      ),
                      itemCount: _messages.length,
                      itemBuilder:
                          (
                            context,
                            index,
                          ) {
                            final message = _messages[index];
                            final isMe =
                                message['userId']?.toString() ==
                                _userId;
                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.indigo.shade600
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    20,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        0.1,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(
                                        0,
                                        2,
                                      ),
                                    ),
                                  ],
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(
                                        context,
                                      ).size.width *
                                      0.7,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Text(
                                        message['userName'] ??
                                            'User',
                                        style: TextStyle(
                                          color: Colors.indigo.shade600,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(
                                      message['message'] ??
                                          '',
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(
                                      _formatTime(
                                        message['createdAt'],
                                      ),
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.grey,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(
                16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      0.1,
                    ),
                    blurRadius: 4,
                    offset: const Offset(
                      0,
                      -2,
                    ),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            25,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted:
                          (
                            _,
                          ) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.indigo.shade600,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                      ),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Community selection view - shown when no community is selected
    return Scaffold(
      backgroundColor: const Color(
        0xFFF4F6F9,
      ),
      appBar: AppBar(
        title: const Text(
          'Community',
        ),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadMyCommunities();
                await _loadPublicCommunities();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Create Community Section
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Create Community',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            TextField(
                              controller: _communityNameController,
                              decoration: const InputDecoration(
                                labelText: 'Community Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            ElevatedButton.icon(
                              onPressed: _createCommunity,
                              icon: const Icon(
                                Icons.add,
                              ),
                              label: const Text(
                                'Create Community',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    // Join with Code Section
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Join Private Community',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            ElevatedButton.icon(
                              onPressed: _showJoinCodeInputDialog,
                              icon: const Icon(
                                Icons.vpn_key,
                              ),
                              label: const Text(
                                'Join with Code',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 24,
                    ),
                    // My Communities
                    if (_myCommunities.isNotEmpty) ...[
                      const Text(
                        'My Communities',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      ..._myCommunities.map(
                        (
                          community,
                        ) => Card(
                          margin: const EdgeInsets.only(
                            bottom: 12,
                          ),
                          elevation: 2,
                          child: ListTile(
                            title: Text(
                              community['name'] ??
                                  'Untitled',
                            ),
                            subtitle: Text(
                              '${community['memberCount'] ?? 0} members • ${community['isPublic'] == true ? 'Public' : 'Private'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // If owner and private show share icon
                                if (community['isOwner'] ==
                                        true &&
                                    community['isPublic'] ==
                                        false &&
                                    community['joinCode'] !=
                                        null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.share,
                                    ),
                                    onPressed: () => _showJoinCodeDialog(
                                      community['joinCode'],
                                    ),
                                    tooltip: 'Share Join Code',
                                  ),

                                // Chat button (opens chat view)
                                IconButton(
                                  icon: const Icon(
                                    Icons.chat_bubble_outline,
                                  ),
                                  onPressed: () {
                                    // Open chat (previously onTap)
                                    _selectCommunity(
                                      community,
                                    );
                                  },
                                  tooltip: 'Open Chat',
                                ),
                              ],
                            ),
                            // TILE TAP -> open Community Info Page
                            onTap: () async {
                              final changed = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (
                                        _,
                                      ) => CommunityInfoPage(
                                        community: community,
                                      ),
                                ),
                              );

                              if (changed ==
                                  true) {
                                // Refresh lists after leave/delete/transfer
                                await _loadMyCommunities();
                                await _loadPublicCommunities();
                                setState(
                                  () {
                                    _selectedCommunity = null;
                                  },
                                );
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 24,
                      ),
                    ],
                    // Public Communities
                    const Text(
                      'Public Communities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    if (_publicCommunities.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(
                          24.0,
                        ),
                        child: Text(
                          'No public communities available',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      )
                    else
                      ..._publicCommunities.map(
                        (
                          community,
                        ) {
                          final isMember = _myCommunities.any(
                            (
                              c,
                            ) =>
                                c['_id'] ==
                                community['_id'],
                          );
                          return Card(
                            margin: const EdgeInsets.only(
                              bottom: 12,
                            ),
                            elevation: 2,
                            child: ListTile(
                              title: Text(
                                community['name'] ??
                                    'Untitled',
                              ),
                              subtitle: Text(
                                '${community['memberCount'] ?? 0} members • Created by ${community['ownerName'] ?? 'Unknown'}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  isMember
                                      ? const Chip(
                                          label: Text(
                                            'Joined',
                                          ),
                                          backgroundColor: Colors.green,
                                        )
                                      : ElevatedButton(
                                          onPressed: () => _joinPublicCommunity(
                                            community['_id'],
                                          ),
                                          child: const Text(
                                            'Join',
                                          ),
                                        ),
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.chat_bubble_outline,
                                    ),
                                    onPressed: () {
                                      // Open chat (select community)
                                      _selectCommunity(
                                        community,
                                      );
                                    },
                                    tooltip: 'Open Chat',
                                  ),
                                ],
                              ),
                              // TILE TAP -> open Community Info Page
                              onTap: () async {
                                final changed = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (
                                          _,
                                        ) => CommunityInfoPage(
                                          community: community,
                                        ),
                                  ),
                                );

                                if (changed ==
                                    true) {
                                  // Refresh lists after leave/delete/transfer
                                  await _loadMyCommunities();
                                  await _loadPublicCommunities();
                                  setState(
                                    () {
                                      _selectedCommunity = null;
                                    },
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatTime(
    dynamic timestamp,
  ) {
    if (timestamp ==
        null)
      return '';
    try {
      final date =
          timestamp
              is String
          ? DateTime.parse(
              timestamp,
            )
          : DateTime.fromMillisecondsSinceEpoch(
              timestamp,
            );
      final now = DateTime.now();
      final difference = now.difference(
        date,
      );

      if (difference.inMinutes <
          1) {
        return 'Just now';
      } else if (difference.inHours <
          1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays <
          1) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (
      e
    ) {
      return '';
    }
  }
}
