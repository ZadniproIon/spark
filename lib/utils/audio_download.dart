import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

Future<void> saveVoiceNoteToDownloads({
  required BuildContext context,
  required String source,
  required String fileNameBase,
}) async {
  final toastHost = _ToastHost.capture(context);
  try {
    if (!Platform.isAndroid) {
      _showSnack(toastHost, 'Downloads are only supported on Android for now.');
      return;
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt <= 28) {
      final status = await Permission.storage.request();
      if (!status.isGranted && !status.isLimited) {
        _showSnack(
          toastHost,
          'Storage permission is required to save downloads.',
        );
        return;
      }
    }

    final safeBase = fileNameBase.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final fileName = '$safeBase.m4a';
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/$fileName';
    final tempFile = File(tempPath);

    if (source.startsWith('http://') || source.startsWith('https://')) {
      final request = await HttpClient().getUrl(Uri.parse(source));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }
      await response.pipe(tempFile.openWrite());
    } else {
      final sourceFile = File(source);
      if (!await sourceFile.exists()) {
        _showSnack(toastHost, 'Audio file not found on device.');
        return;
      }
      await sourceFile.copy(tempPath);
    }

    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'Spark';
    final mediaStore = MediaStore();
    SaveInfo? saved;
    try {
      saved = await mediaStore.saveFile(
        tempFilePath: tempPath,
        dirType: DirType.download,
        dirName: DirName.download,
      );
    } on FormatException {
      // media_store_plus may return an empty payload even when the write
      // succeeded. We'll verify by checking whether the target file exists.
      saved = null;
    }

    bool existsAfterSave = false;
    if (saved == null) {
      try {
        existsAfterSave = await mediaStore.isFileExist(
          fileName: fileName,
          dirType: DirType.download,
          dirName: DirName.download,
        );
      } catch (_) {
        existsAfterSave = false;
      }
    }

    if (saved == null && !existsAfterSave) {
      _showSnack(toastHost, 'Unable to save voice note.');
      return;
    }

    _showSnack(toastHost, 'Saved to Downloads.');
  } catch (_) {
    _showSnack(toastHost, 'Unable to save voice note.');
  }
}

void _showSnack(_ToastHost host, String message) {
  final overlay = host.overlay;
  if (overlay != null) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          left: 16,
          right: 16,
          bottom: host.bottomOffset,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: host.colors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: host.colors.border),
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.secondary.copyWith(
                      color: host.colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
    return;
  }

  final messenger = host.messenger;
  if (messenger == null) {
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: AppTextStyles.secondary.copyWith(color: host.colors.textPrimary),
      ),
      backgroundColor: host.colors.bgCard,
    ),
  );
}

class _ToastHost {
  const _ToastHost({
    required this.colors,
    required this.overlay,
    required this.messenger,
    required this.bottomOffset,
  });

  final SparkColors colors;
  final OverlayState? overlay;
  final ScaffoldMessengerState? messenger;
  final double bottomOffset;

  factory _ToastHost.capture(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final bottomInset = mediaQuery?.viewInsets.bottom ?? 0.0;
    final safeBottom = mediaQuery?.viewPadding.bottom ?? 0.0;
    return _ToastHost(
      colors: context.sparkColors,
      overlay: Overlay.maybeOf(context, rootOverlay: true),
      messenger: ScaffoldMessenger.maybeOf(context),
      bottomOffset: 24.0 + safeBottom + bottomInset,
    );
  }
}
