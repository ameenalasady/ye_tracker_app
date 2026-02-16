import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateRelease { // GitHub release page

  UpdateRelease({
    required this.tagName,
    required this.body,
    required this.downloadUrl,
    required this.htmlUrl,
  });
  final String tagName; // e.g., "v42"
  final String body; // Release notes
  final String downloadUrl; // APK url
  final String htmlUrl;

  // Extract integer version from "v42" -> 42
  int get versionNumber {
    final clean = tagName.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? 0;
  }
}

class UpdateManager {
  final Dio _dio = Dio();
  // Update this to match your repository
  final String _repoOwner = 'ameenalasady';
  final String _repoName = 'ye_tracker_app';

  Future<UpdateRelease?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final url =
          'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';
      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        final tagName = data['tag_name'] as String; // e.g., "v45"
        final body = data['body'] as String? ?? 'No release notes.';
        final htmlUrl = data['html_url'] as String;
        final assets = data['assets'] as List;

        // Find the APK asset
        final apkAsset = assets.firstWhere(
          (asset) => (asset['name'] as String).endsWith('.apk'),
          orElse: () => null,
        );

        if (apkAsset == null) return null;

        final release = UpdateRelease(
          tagName: tagName,
          body: body,
          downloadUrl: apkAsset['browser_download_url'],
          htmlUrl: htmlUrl,
        );

        // Compare: If Remote Version > Local Version
        if (release.versionNumber > currentBuildNumber) {
          return release;
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
    return null;
  }

  Future<void> downloadAndInstall(
    UpdateRelease release, {
    required Function(double) onProgress,
    required Function(String) onError,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/update_${release.tagName}.apk';

      await _dio.download(
        release.downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      // Trigger installation
      final result = await OpenFile.open(savePath);
      if (result.type != ResultType.done) {
        onError('Could not open APK: ${result.message}');
      }
    } catch (e) {
      onError('Download failed: $e');
    }
  }
}
