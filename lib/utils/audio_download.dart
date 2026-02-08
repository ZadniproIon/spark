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
  final colors = context.sparkColors;
  try {
    if (!Platform.isAndroid) {
      _showSnack(context, 'Downloads are only supported on Android for now.');
      return;
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt <= 28) {
      final status = await Permission.storage.request();
      if (!status.isGranted && !status.isLimited) {
        _showSnack(
          context,
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
        _showSnack(context, 'Audio file not found on device.');
        return;
      }
      await sourceFile.copy(tempPath);
    }

    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'Spark';
    final saved = await MediaStore().saveFile(
      tempFilePath: tempPath,
      dirType: DirType.download,
      dirName: DirName.download,
    );
    if (saved == null) {
      _showSnack(context, 'Unable to save voice note.');
      return;
    }

    _showSnack(context, 'Saved to Downloads.');
  } catch (_) {
    _showSnack(context, 'Unable to save voice note.');
  }
}

void _showSnack(BuildContext context, String message) {
  final colors = context.sparkColors;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: AppTextStyles.secondary.copyWith(color: colors.textPrimary),
      ),
      backgroundColor: colors.bgCard,
    ),
  );
}
