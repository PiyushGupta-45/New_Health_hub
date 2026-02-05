// Floating Health Chatbot Widget
// Floating button in bottom right corner

import 'package:flutter/material.dart';
import '../services/health_chatbot_service.dart';

class HealthChatbotWidget
    extends
        StatefulWidget {
  const HealthChatbotWidget({
    super.key,
  });

  @override
  State<
    HealthChatbotWidget
  >
  createState() => _HealthChatbotWidgetState();
}

class _HealthChatbotWidgetState
    extends
        State<
          HealthChatbotWidget
        > {
  final HealthChatbotService _chatbotService = HealthChatbotService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<
    ChatMessage
  >
  _messages = [];
  bool _isExpanded = false;
  bool _isLoading = false;
  double _verticalOffset = 0.0; // Vertical offset for dragging
  double _horizontalOffset = 0.0; // Horizontal offset for dragging

  @override
  void initState() {
    super.initState();
    // Add greeting message - this doesn't require API initialization
    try {
      WidgetsBinding.instance.addPostFrameCallback(
        (
          _,
        ) {
          if (mounted) {
            setState(
              () {
                _messages.add(
                  ChatMessage(
                    text: _chatbotService.getGreeting(),
                    isUser: false,
                    timestamp: DateTime.now(),
                  ),
                );
              },
            );
          }
        },
      );
    } catch (
      e
    ) {
      // If greeting fails, add a simple message
      if (mounted) {
        setState(
          () {
            _messages.add(
              ChatMessage(
                text: 'Hi! I\'m your Health Assistant. How can I help you today?',
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(
          milliseconds: 300,
        ),
        curve: Curves.easeOut,
      );
    }
  }

  Future<
    void
  >
  _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty ||
        _isLoading)
      return;

    // Add user message
    setState(
      () {
        _messages.add(
          ChatMessage(
            text: text,
            isUser: true,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = true;
      },
    );

    _messageController.clear();
    _scrollToBottom();

    // Get bot response from Gemini AI
    final response = await _chatbotService.getResponse(
      text,
    );

    // Add bot response
    if (mounted) {
      setState(
        () {
          _messages.add(
            ChatMessage(
              text: response,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        },
      );
      _scrollToBottom();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    // If used in dialog, show expanded chat directly
    // Otherwise, show as positioned floating button
    final isInDialog =
        context
            .findAncestorWidgetOfExactType<
              Dialog
            >() !=
        null;

    if (isInDialog) {
      return _buildExpandedChat();
    }

    // Position above About button in bottom navigation
    // About button is the 4th item (index 3), positioned on the right side
    // With 4 evenly spaced items, About is centered at 87.5% of screen width
    // Bottom nav is 70px + SafeArea padding
    final bottomNavHeight = 70.0;
    final safeAreaBottom = MediaQuery.of(
      context,
    ).padding.bottom;
    final screenWidth = MediaQuery.of(
      context,
    ).size.width;

    // Position chatbot button above About button (4th item, centered at ~87.5% of width)
    final aboutButtonCenter =
        screenWidth *
        0.875; // Center of 4th item
    final buttonWidth = 60.0;
    final buttonHeight = 56.0;
    final rightPosition =
        screenWidth -
        aboutButtonCenter -
        (buttonWidth /
            2);

    // Place the floating button so its center sits just above the About nav item.
    // Compute bottom as: safe area + half of bottom nav height - half of button height
    // This keeps the button visually aligned with the nav item and slightly overlapping.
    // Add extra space to avoid message input areas (like in community chat) - approximately 100-120px
    final messageInputAreaHeight = 120.0; // Height to avoid message input areas
    final baseBottomPosition =
        safeAreaBottom +
        (bottomNavHeight /
            2) -
        (buttonHeight /
            2);
    // Position higher to avoid send button in chat views
    final baseBottom =
        baseBottomPosition +
        messageInputAreaHeight;

    // Calculate dynamic vertical position based on drag offset
    // Constrain to top and bottom bounds - ensure it stays above navbar
    final screenHeight = MediaQuery.of(
      context,
    ).size.height;
    final safeAreaTop = MediaQuery.of(
      context,
    ).padding.top;
    final widgetHeight = _isExpanded
        ? 500.0
        : buttonHeight;
    // Minimum bottom position: navbar height + safe area + padding (to stay above navbar)
    final minBottomPosition =
        bottomNavHeight +
        safeAreaBottom +
        10; // 10px padding above navbar
    // Maximum top: can move to top of screen (with safe area and padding)
    // Calculate how much we can move up: from baseBottom to top of screen
    final topPadding = 20.0; // Padding from top
    final maxTopOffset =
        (screenHeight -
                baseBottom -
                widgetHeight -
                safeAreaTop -
                topPadding)
            .clamp(
              0.0,
              screenHeight,
            );
    // Maximum bottom: can't go below navbar (positive offset moves down)
    final maxBottomOffset =
        (baseBottom -
                minBottomPosition)
            .clamp(
              0.0,
              screenHeight,
            );
    final constrainedVerticalOffset = _verticalOffset.clamp(
      -maxTopOffset,
      maxBottomOffset,
    );
    // When verticalOffset is negative (moving up), we add it to baseBottom to move up
    // When verticalOffset is positive (moving down), we add it to baseBottom to move down
    final dynamicBottomPosition =
        baseBottom +
        constrainedVerticalOffset;

    // Calculate dynamic horizontal position based on drag offset
    // Constrain to left and right sides
    final expandedWidth =
        (screenWidth -
                32)
            .clamp(
              0.0,
              400.0,
            );
    final widgetWidth = _isExpanded
        ? expandedWidth
        : buttonWidth;
    // To move to left edge: dynamicRightPosition should be (screenWidth - widgetWidth)
    // To move to right edge: dynamicRightPosition should be 0 (or small value)
    // Current: dynamicRightPosition = rightPosition - horizontalOffset
    // For left edge: screenWidth - widgetWidth = rightPosition - maxLeftOffset
    // So: maxLeftOffset = rightPosition - (screenWidth - widgetWidth) = rightPosition - screenWidth + widgetWidth
    // For right edge: 0 = rightPosition - maxRightOffset
    // So: maxRightOffset = rightPosition
    final maxLeftOffset =
        rightPosition -
        screenWidth +
        widgetWidth; // Allows moving to left edge
    final maxRightOffset = rightPosition; // Allows moving to right edge (original position or further)
    final constrainedHorizontalOffset = _horizontalOffset.clamp(
      maxLeftOffset,
      maxRightOffset,
    );
    // When horizontalOffset is negative (moving left), dynamicRightPosition increases (moves left)
    // When horizontalOffset is positive (moving right), dynamicRightPosition decreases (moves right)
    final dynamicRightPosition =
        rightPosition -
        constrainedHorizontalOffset;

    return Positioned(
      bottom: dynamicBottomPosition,
      right: dynamicRightPosition,
      child: GestureDetector(
        onPanUpdate:
            (
              details,
            ) {
              // Allow both vertical and horizontal dragging
              setState(
                () {
                  // Vertical dragging (up/down)
                  _verticalOffset -= details.delta.dy; // Negative because bottom position increases as we go down
                  // Horizontal dragging (left/right)
                  _horizontalOffset += details.delta.dx;

                  // Constrain to screen bounds - recalculate constraints
                  final currentScreenHeight = MediaQuery.of(
                    context,
                  ).size.height;
                  final currentScreenWidth = MediaQuery.of(
                    context,
                  ).size.width;
                  final currentSafeAreaTop = MediaQuery.of(
                    context,
                  ).padding.top;
                  final currentSafeAreaBottom = MediaQuery.of(
                    context,
                  ).padding.bottom;
                  final currentMinBottomPosition =
                      bottomNavHeight +
                      currentSafeAreaBottom +
                      10;
                  final currentBaseBottom =
                      currentSafeAreaBottom +
                      (bottomNavHeight /
                          2) -
                      (buttonHeight /
                          2) +
                      messageInputAreaHeight;
                  final currentWidgetHeight = _isExpanded
                      ? 500.0
                      : buttonHeight;
                  final currentWidgetWidth = _isExpanded
                      ? (currentScreenWidth -
                                32)
                            .clamp(
                              0.0,
                              400.0,
                            )
                      : buttonWidth;

                  // Vertical constraints
                  // Allow movement to top of screen (with safe area padding)
                  final topPadding = 20.0;
                  final currentMaxTopOffset =
                      (currentScreenHeight -
                              currentBaseBottom -
                              currentWidgetHeight -
                              currentSafeAreaTop -
                              topPadding)
                          .clamp(
                            0.0,
                            currentScreenHeight,
                          );
                  // Allow movement down but not below navbar
                  final currentMaxBottomOffset =
                      (currentBaseBottom -
                              currentMinBottomPosition)
                          .clamp(
                            0.0,
                            currentScreenHeight,
                          );
                  _verticalOffset = _verticalOffset.clamp(
                    -currentMaxTopOffset,
                    currentMaxBottomOffset,
                  );

                  // Horizontal constraints
                  // Allow movement to left edge and right edge
                  final currentMaxLeftOffset =
                      rightPosition -
                      currentScreenWidth +
                      currentWidgetWidth; // Allows moving to left edge
                  final currentMaxRightOffset = rightPosition; // Allows moving to right edge
                  _horizontalOffset = _horizontalOffset.clamp(
                    currentMaxLeftOffset,
                    currentMaxRightOffset,
                  );
                },
              );
            },
        child: _isExpanded
            ? _buildExpandedChat()
            : _buildFloatingButton(),
      ),
    );
  }

  Widget _buildFloatingButton() {
    return MouseRegion(
      onEnter:
          (
            _,
          ) {
            if (!_isExpanded) {
              setState(
                () {
                  _isExpanded = true;
                },
              );
              Future.delayed(
                const Duration(
                  milliseconds: 100,
                ),
                _scrollToBottom,
              );
            }
          },
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(
              () {
                _isExpanded = true;
              },
            );
            Future.delayed(
              const Duration(
                milliseconds: 100,
              ),
              _scrollToBottom,
            );
          },
          borderRadius: BorderRadius.circular(
            28,
          ),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(
                    0xFF2563EB,
                  ),
                  Color(
                    0xFF3B82F6,
                  ),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      const Color(
                        0xFF2563EB,
                      ).withOpacity(
                        0.4,
                      ),
                  blurRadius: 12,
                  offset: const Offset(
                    0,
                    4,
                  ),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.chat_bubble,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedChat() {
    return Container(
      width: 400,
      height: 500,
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.of(
              context,
            ).size.width -
            32,
        maxHeight:
            MediaQuery.of(
              context,
            ).size.height *
            0.5,
      ),
      decoration: BoxDecoration(
        color:
            Theme.of(
                  context,
                ).brightness ==
                Brightness.dark
            ? const Color(
                0xFF1E293B,
              )
            : Colors.white,
        borderRadius: BorderRadius.circular(
          20,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.2,
            ),
            blurRadius: 20,
            offset: const Offset(
              0,
              8,
            ),
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(
                    0xFF2563EB,
                  ),
                  Color(
                    0xFF3B82F6,
                  ),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(
                  20,
                ),
                topRight: Radius.circular(
                  20,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(
                    8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.2,
                    ),
                    borderRadius: BorderRadius.circular(
                      8,
                    ),
                  ),
                  child: const Icon(
                    Icons.health_and_safety,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                const Expanded(
                  child: Text(
                    'Health Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    final isInDialog =
                        context
                            .findAncestorWidgetOfExactType<
                              Dialog
                            >() !=
                        null;
                    if (isInDialog) {
                      Navigator.of(
                        context,
                      ).pop();
                    } else {
                      setState(
                        () {
                          _isExpanded = false;
                        },
                      );
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Chat messages
          Expanded(
            child: Container(
              color:
                  Theme.of(
                        context,
                      ).brightness ==
                      Brightness.dark
                  ? const Color(
                      0xFF0F172A,
                    )
                  : const Color(
                      0xFFF8FAFC,
                    ),
              child: _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'Start a conversation...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(
                        16,
                      ),
                      itemCount:
                          _messages.length +
                          (_isLoading
                              ? 1
                              : 0),
                      itemBuilder:
                          (
                            context,
                            index,
                          ) {
                            if (index ==
                                _messages.length) {
                              // Loading indicator
                              return const Padding(
                                padding: EdgeInsets.all(
                                  16.0,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 12,
                                    ),
                                    Text(
                                      'Thinking...',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final message = _messages[index];
                            return _buildMessageBubble(
                              message,
                            );
                          },
                    ),
            ),
          ),
          // Input area
          Container(
            padding: const EdgeInsets.all(
              12,
            ),
            decoration: BoxDecoration(
              color:
                  Theme.of(
                        context,
                      ).brightness ==
                      Brightness.dark
                  ? const Color(
                      0xFF1E293B,
                    )
                  : Colors.white,
              border: Border(
                top: BorderSide(
                  color:
                      Theme.of(
                            context,
                          ).brightness ==
                          Brightness.dark
                      ? Colors.grey.shade700
                      : Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(
                      color:
                          Theme.of(
                                context,
                              ).brightness ==
                              Brightness.dark
                          ? const Color(
                              0xFFF1F5F9,
                            )
                          : const Color(
                              0xFF1E293B,
                            ),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask about health, nutrition, exercise...',
                      hintStyle: TextStyle(
                        color:
                            Theme.of(
                                  context,
                                ).brightness ==
                                Brightness.dark
                            ? Colors.grey.shade400
                            : Colors.grey.shade500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          25,
                        ),
                        borderSide: BorderSide(
                          color:
                              Theme.of(
                                    context,
                                  ).brightness ==
                                  Brightness.dark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          25,
                        ),
                        borderSide: BorderSide(
                          color:
                              Theme.of(
                                    context,
                                  ).brightness ==
                                  Brightness.dark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          25,
                        ),
                        borderSide: const BorderSide(
                          color: Color(
                            0xFF3B82F6,
                          ),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor:
                          Theme.of(
                                context,
                              ).brightness ==
                              Brightness.dark
                          ? const Color(
                              0xFF0F172A,
                            )
                          : Colors.grey.shade50,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted:
                        (
                          _,
                        ) => _sendMessage(),
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(
                            0xFF2563EB,
                          ),
                          Color(
                            0xFF3B82F6,
                          ),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isLoading
                          ? null
                          : _sendMessage,
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(
                        12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(
                8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(
                      0xFF3B82F6,
                    ),
                    Color(
                      0xFF2563EB,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  12,
                ),
              ),
              child: const Icon(
                Icons.health_and_safety,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(
              width: 8,
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(
                        0xFF2563EB,
                      )
                    : (Theme.of(
                                context,
                              ).brightness ==
                              Brightness.dark
                          ? const Color(
                              0xFF334155,
                            )
                          : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(
                    16,
                  ),
                  topRight: const Radius.circular(
                    16,
                  ),
                  bottomLeft: Radius.circular(
                    message.isUser
                        ? 16
                        : 4,
                  ),
                  bottomRight: Radius.circular(
                    message.isUser
                        ? 4
                        : 16,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      0.05,
                    ),
                    blurRadius: 4,
                    offset: const Offset(
                      0,
                      2,
                    ),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white
                      : (Theme.of(
                                  context,
                                ).brightness ==
                                Brightness.dark
                            ? const Color(
                                0xFFF1F5F9,
                              )
                            : Colors.black87),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(
              width: 8,
            ),
            Container(
              padding: const EdgeInsets.all(
                8,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(
                  12,
                ),
              ),
              child: const Text(
                'U',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
