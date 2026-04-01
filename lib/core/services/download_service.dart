import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  final Dio _dio = Dio();

  Future<String?> getLocalPath(int itemId, String type) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = type == 'pdf' ? 'pdf' : 'mp3';
    final file = File('${dir.path}/bts_$itemId.$ext');
    return file.existsSync() ? file.path : null;
  }

  Future<String> download(
    int itemId,
    String url,
    String type, {
    void Function(double)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = type == 'pdf' ? 'pdf' : 'mp3';
    final savePath = '${dir.path}/bts_$itemId.$ext';

    await _dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    return savePath;
  }

  Future<void> delete(int itemId, String type) async {
    final path = await getLocalPath(itemId, type);
    if (path != null) await File(path).delete();
  }
}
