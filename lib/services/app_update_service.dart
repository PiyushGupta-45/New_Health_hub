import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ReleaseUpdateInfo {
  const ReleaseUpdateInfo({
    required this.versionTag,
    required this.notes,
    required this.apkUrl,
    required this.releaseTitle,
  });

  final String versionTag;
  final String notes;
  final String apkUrl;
  final String releaseTitle;
}

class AppUpdateService {
  static const MethodChannel _installerChannel = MethodChannel(
    'com.example.health/app_update',
  );

  Future<ReleaseUpdateInfo?> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('[Update] Skipped: platform is not Android app runtime.');
      return null;
    }

    final repo = dotenv.maybeGet('GITHUB_REPO')?.trim();
    if (repo == null || repo.isEmpty || !repo.contains('/')) {
      debugPrint('[Update] Skipped: invalid GITHUB_REPO value.');
      return null;
    }

    final uri = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
    final response = await http.get(
      uri,
      headers: const <String, String>{
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'HealthHub-Updater',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );

    if (response.statusCode != 200) {
      debugPrint(
        '[Update] GitHub latest release API failed: ${response.statusCode} ${response.body}',
      );
      return null;
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] ?? '').toString().trim();
    if (tag.isEmpty) {
      return null;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final currentBuild = packageInfo.buildNumber;
    debugPrint(
      '[Update] Current app version: $currentVersion+$currentBuild, latest tag: $tag',
    );

    if (!_isNewerVersion(tag, currentVersion, currentBuild)) {
      debugPrint('[Update] Skipped: current app is up-to-date.');
      return null;
    }

    final assets = (data['assets'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    final apkAsset = assets.firstWhere((asset) {
      final url = (asset['browser_download_url'] ?? '').toString();
      return url.toLowerCase().endsWith('.apk');
    }, orElse: () => <String, dynamic>{});

    final apkUrl = (apkAsset['browser_download_url'] ?? '').toString().trim();
    if (apkUrl.isEmpty) {
      debugPrint('[Update] Skipped: latest release has no APK asset.');
      return null;
    }

    final notes = (data['body'] ?? '').toString().trim();
    final releaseTitle = (data['name'] ?? tag).toString();

    return ReleaseUpdateInfo(
      versionTag: tag,
      notes: notes.isEmpty ? 'A new update is available.' : notes,
      apkUrl: apkUrl,
      releaseTitle: releaseTitle,
    );
  }

  Stream<OtaEvent> startUpdate(String apkUrl, String versionTag) {
    final safeTag = versionTag.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final safeFileName = 'healthhub_update_$safeTag.apk';
    return OtaUpdate().execute(apkUrl, destinationFilename: safeFileName);
  }

  Future<void> cleanupDownloadedApks() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      await _installerChannel.invokeMethod<Map<dynamic, dynamic>>(
        'cleanupDownloadedApks',
      );
    } catch (_) {
      // Best effort only.
    }
  }

  Future<bool> isInstalledVersionAtLeast(String versionTag) async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }
    final packageInfo = await PackageInfo.fromPlatform();
    // True when requested tag is not newer than installed version/build.
    return !_isNewerVersion(
      versionTag,
      packageInfo.version,
      packageInfo.buildNumber,
    );
  }

  Future<bool> canRequestPackageInstalls() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    try {
      final allowed = await _installerChannel.invokeMethod<bool>(
        'canRequestPackageInstalls',
      );
      return allowed ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openInstallUnknownAppsSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _installerChannel.invokeMethod('openInstallUnknownAppsSettings');
    } catch (_) {
      // Best effort only.
    }
  }

  bool _isNewerVersion(
    String remoteTag,
    String currentVersion,
    String currentBuild,
  ) {
    final remote = _normalizeVersion(remoteTag);
    final current = _normalizeVersion('$currentVersion+$currentBuild');

    final maxLen = remote.length > current.length
        ? remote.length
        : current.length;
    for (var i = 0; i < maxLen; i++) {
      final r = i < remote.length ? remote[i] : 0;
      final c = i < current.length ? current[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  List<int> _normalizeVersion(String raw) {
    final cleaned = raw.toLowerCase().replaceFirst('v', '');
    final normalized = cleaned.replaceAll('-', '.').replaceAll('+', '.');
    return normalized
        .split('.')
        .map(
          (part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        )
        .toList();
  }
}
