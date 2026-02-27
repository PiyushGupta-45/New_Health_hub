import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'controllers/health_sync_controller.dart';
import 'controllers/auth_controller.dart';
import 'pages/features_view.dart';
import 'pages/home_page.dart';
import 'pages/community_page.dart';
import 'pages/auth_page.dart';
import 'pages/progress_dashboard_view.dart';
import 'widgets/health_chatbot_widget.dart';
import 'services/app_update_service.dart';

// Chatbot Dialog Wrapper
class HealthChatbotDialog extends StatelessWidget {
  const HealthChatbotDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const HealthChatbotWidget(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const String _pendingUpdateTagKey = 'pending_update_tag';
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final HealthSyncController _healthSyncController = HealthSyncController();
  final AuthController _authController = AuthController();
  final AppUpdateService _appUpdateService = AppUpdateService();
  final GlobalKey<CommunityPageState> _communityPageKey =
      GlobalKey<CommunityPageState>();
  StreamSubscription<OtaEvent>? _updateSubscription;
  bool _isUpdateDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _authController.addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    if (kIsWeb || _isUpdateDialogVisible || !mounted) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      var pendingTag = prefs.getString(_pendingUpdateTagKey);
      if (pendingTag != null) {
        final alreadyInstalled = await _appUpdateService
            .isInstalledVersionAtLeast(pendingTag);
        if (alreadyInstalled) {
          await prefs.remove(_pendingUpdateTagKey);
          await _appUpdateService.cleanupDownloadedApks();
          pendingTag = null;
          debugPrint(
            '[Update] Cleared pending tag because installed app already has it.',
          );
        }
      }

      final updateInfo = await _appUpdateService.checkForUpdate();
      if (!mounted || updateInfo == null) return;

      if (pendingTag == updateInfo.versionTag) {
        _showPendingInstallDialog(updateInfo);
        return;
      }

      _showUpdateDialog(updateInfo);
    } catch (_) {
      // Keep startup uninterrupted if the update check fails.
    }
  }

  Future<void> _showUpdateDialog(ReleaseUpdateInfo info) async {
    if (!mounted || _isUpdateDialogVisible) return;
    _isUpdateDialogVisible = true;

    var isDownloading = false;
    var statusText = 'Ready to download';
    var progress = 0.0;
    var dialogAlive = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              title: const Text('Update Available'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${info.releaseTitle} (${info.versionTag})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: const Row(
                        children: <Widget>[
                          Icon(
                            Icons.bolt_rounded,
                            size: 18,
                            color: Color(0xFFEA580C),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Download now for better experience.',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9A3412),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('What is new:'),
                    const SizedBox(height: 6),
                    Text(info.notes),
                    if (isDownloading) ...<Widget>[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 8),
                      Text(statusText),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isDownloading
                                ? null
                                : () {
                                    Navigator.of(context).pop();
                                  },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Download Later'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isDownloading
                                ? null
                                : () async {
                                    final canInstall = await _appUpdateService
                                        .canRequestPackageInstalls();
                                    if (!canInstall) {
                                      await _appUpdateService
                                          .openInstallUnknownAppsSettings();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Enable "Install unknown apps" for HealthHub, then tap Update Now again.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    setDialogState(() {
                                      isDownloading = true;
                                      statusText = 'Starting download...';
                                      progress = 0;
                                    });

                                    await _appUpdateService
                                        .cleanupDownloadedApks();
                                    _updateSubscription?.cancel();
                                    _updateSubscription = _appUpdateService
                                        .startUpdate(
                                          info.apkUrl,
                                          info.versionTag,
                                        )
                                        .listen(
                                          (event) {
                                            if (!mounted || !dialogAlive)
                                              return;
                                            final rawValue = (event.value ?? '')
                                                .trim();
                                            final progressValue =
                                                double.tryParse(rawValue);
                                            final normalizedStatus = event
                                                .status
                                                .name
                                                .toUpperCase();

                                            setDialogState(() {
                                              if (progressValue != null) {
                                                progress = (progressValue / 100)
                                                    .clamp(0.0, 1.0);
                                              }

                                              switch (normalizedStatus) {
                                                case 'DOWNLOADING':
                                                  statusText =
                                                      'Downloading... ${(progress * 100).toStringAsFixed(0)}%';
                                                  SharedPreferences.getInstance()
                                                      .then((prefs) {
                                                        prefs.setString(
                                                          _pendingUpdateTagKey,
                                                          info.versionTag,
                                                        );
                                                      });
                                                  break;
                                                case 'INSTALLING':
                                                  statusText =
                                                      'Installing update...';
                                                  dialogAlive = false;
                                                  Navigator.of(context).pop();
                                                  break;
                                                default:
                                                  statusText = rawValue.isEmpty
                                                      ? normalizedStatus
                                                      : rawValue;
                                              }
                                            });
                                          },
                                          onError: (error) {
                                            if (!mounted || !dialogAlive)
                                              return;
                                            setDialogState(() {
                                              isDownloading = false;
                                              statusText = 'Update failed';
                                            });
                                            SharedPreferences.getInstance()
                                                .then(
                                                  (prefs) => prefs.remove(
                                                    _pendingUpdateTagKey,
                                                  ),
                                                );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Update failed: $error',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          },
                                        );
                                  },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Update Now'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    dialogAlive = false;
    _isUpdateDialogVisible = false;
  }

  Future<void> _showPendingInstallDialog(ReleaseUpdateInfo info) async {
    if (!mounted || _isUpdateDialogVisible) return;
    _isUpdateDialogVisible = true;
    var isInstalling = false;
    var statusText = 'Ready to install downloaded update';
    var dialogAlive = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('Install Update'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update ${info.versionTag} was downloaded. Install now to replace your current app.',
                  ),
                  const SizedBox(height: 12),
                  if (isInstalling) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(statusText),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isInstalling
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: isInstalling
                      ? null
                      : () async {
                          final canInstall = await _appUpdateService
                              .canRequestPackageInstalls();
                          if (!canInstall) {
                            await _appUpdateService
                                .openInstallUnknownAppsSettings();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Enable "Install unknown apps" for HealthHub, then tap Install Now again.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isInstalling = true;
                            statusText = 'Opening installer...';
                          });

                          await _appUpdateService.cleanupDownloadedApks();
                          _updateSubscription?.cancel();
                          _updateSubscription = _appUpdateService
                              .startUpdate(info.apkUrl, info.versionTag)
                              .listen(
                                (event) {
                                  final normalizedStatus = event.status.name
                                      .toUpperCase();
                                  if (!mounted || !dialogAlive) return;
                                  setDialogState(() {
                                    switch (normalizedStatus) {
                                      case 'DOWNLOADING':
                                        statusText =
                                            'Preparing installer... ${event.value ?? ''}';
                                        break;
                                      case 'INSTALLING':
                                        statusText = 'Installer opened';
                                        break;
                                      default:
                                        final value = event.value ?? '';
                                        statusText = value.isEmpty
                                            ? normalizedStatus
                                            : value;
                                    }
                                  });

                                  if (normalizedStatus == 'INSTALLING') {
                                    dialogAlive = false;
                                    Navigator.of(dialogContext).pop();
                                  }
                                },
                                onError: (error) {
                                  if (!mounted || !dialogAlive) return;
                                  setDialogState(() {
                                    isInstalling = false;
                                    statusText = 'Install failed';
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Install failed. Tap Install Now again. Error: $error',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                },
                              );
                        },
                  child: const Text('Install Now'),
                ),
              ],
            );
          },
        );
      },
    );

    dialogAlive = false;
    _isUpdateDialogVisible = false;
  }

  void _onAuthChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onItemTapped(int index) {
    if (_authController.isGuest && (index == 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in required to access Community and Challenges.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2563EB).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : Colors.grey.shade500,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : Colors.grey.shade500,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_authController.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_authController.isAuthenticated && !_authController.isGuest) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: AuthPage(
          authController: _authController,
          isEntryFlow: true,
          onAuthenticated: () {
            if (mounted) {
              setState(() {});
            }
          },
        ),
      );
    }

    return PopScope(
      // Allow pop only if on home page
      // For Community tab: CommunityPage's PopScope handles all back navigation
      canPop: _selectedIndex == 0,
      onPopInvoked: (didPop) {
        if (!didPop && _selectedIndex != 0) {
          if (_selectedIndex == 1) {
            final handledByCommunity =
                _communityPageKey.currentState?.handleBackFromSystem() ?? false;
            if (handledByCommunity) {
              return;
            }
          }
          // Handle back button - go to previous tab
          setState(() {
            _selectedIndex--;
          });

          _pageController.animateToPage(
            _selectedIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        body: Stack(
          children: [
            // Page content
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: [
                HomePage(
                  controller: _healthSyncController,
                  authController: _authController,
                ),
                CommunityPage(
                  key: _communityPageKey,
                  authController: _authController,
                  healthSyncController: _healthSyncController,
                ),
                FeaturesView(
                  controller: _healthSyncController,
                  authController: _authController,
                ),
                ProgressDashboardView(
                  controller: _healthSyncController,
                  authController: _authController,
                ),
              ],
            ),
            // Floating Health Chatbot - positioned above About button
            const HealthChatbotWidget(),
          ],
        ),

        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_rounded, 'Home', 0),
                  _buildNavItem(Icons.people_rounded, 'Community', 1),
                  _buildNavItem(Icons.star_rounded, 'Features', 2),
                  _buildNavItem(Icons.insights_rounded, 'Dashboard', 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _authController.removeListener(_onAuthChanged);
    _pageController.dispose();
    _healthSyncController.dispose();
    _authController.dispose();
    super.dispose();
  }
}
