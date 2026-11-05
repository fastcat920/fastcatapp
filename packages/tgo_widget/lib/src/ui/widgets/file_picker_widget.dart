import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../state/chat_provider.dart';

/// File picker helper for selecting and uploading files
class FilePickerHelper {
  static final ImagePicker _imagePicker = ImagePicker();

  /// Show file picker bottom sheet
  static Future<void> showPicker(
    BuildContext context,
    ChatProvider provider,
  ) async {
    final files = await pickFiles();
    if (files.isNotEmpty) await provider.uploadFiles(files);
  }

  /// Pick image from camera
  static Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      debugPrint('[FilePickerHelper] Camera error: $e');
    }
    return null;
  }

  /// Pick image from gallery
  static Future<List<File>> pickImagesFromGallery({int limit = 9}) async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        limit: limit,
      );
      return images.map((xfile) => File(xfile.path)).toList();
    } catch (e) {
      debugPrint('[FilePickerHelper] Gallery error: $e');
    }
    return [];
  }

  /// Pick files
  static Future<List<File>> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null && result.files.isNotEmpty) {
        return result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();
      }
    } catch (e) {
      debugPrint('[FilePickerHelper] File picker error: $e');
    }
    return [];
  }
}
