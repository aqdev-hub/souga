// lib/services/image_service.dart
// هذا الملف يُوجِّه جميع عمليات الصور إلى ImageKit

import 'dart:io';
import 'imagekit_service.dart';

class ImageService {
  // اختيار صورة من الجهاز
  static Future<File?> pickImage({bool fromCamera = false}) {
    return ImageKitService.pickImage(fromCamera: fromCamera);
  }

  // رفع صورة — يستخدم ImageKit
  static Future<String?> uploadImage(File imageFile, String folder) {
    return ImageKitService.uploadImage(imageFile, folder);
  }

  // رابط محسن للصورة
  static String optimized(String url, {int width = 400, int height = 400}) {
    if (url.isEmpty) return url;
    if (ImageKitService.isImageKitUrl(url)) {
      return ImageKitService.buildOptimizedUrl(url, width: width, height: height);
    }
    return url;
  }
}
