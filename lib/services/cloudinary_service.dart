import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/constants/cloudinary_config.dart';

class CloudinaryService {
  Future<String> uploadImage({
    required XFile image,
    String folder = 'smart_expense/receipts',
  }) async {
    final uri = Uri.parse(CloudinaryConfig.uploadUrl);

    final bytes = await image.readAsBytes();

    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
    request.fields['folder'] = folder;

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: image.name),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Upload Cloudinary thất bại: $responseBody');
    }

    final data = jsonDecode(responseBody);
    final secureUrl = data['secure_url'];

    if (secureUrl == null || secureUrl.toString().isEmpty) {
      throw Exception('Cloudinary không trả về URL ảnh');
    }

    return secureUrl.toString();
  }

  Future<List<String>> uploadImages({
    required List<XFile> images,
    String folder = 'smart_expense/receipts',
  }) async {
    final urls = <String>[];

    for (final image in images) {
      final url = await uploadImage(image: image, folder: folder);

      urls.add(url);
    }

    return urls;
  }
}
