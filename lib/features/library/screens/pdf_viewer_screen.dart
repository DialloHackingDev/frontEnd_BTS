import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/res/styles.dart';

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String url;

  const PdfViewerScreen({super.key, required this.title, required this.url});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMsg = '';
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _downloadAndLoad();
  }

  Future<void> _downloadAndLoad() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'bts_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$fileName';

      await Dio().download(widget.url, filePath);

      if (mounted) setState(() { _localPath = filePath; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _hasError = true; _errorMsg = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title,
            style: const TextStyle(color: AppColors.white, fontSize: 16),
            overflow: TextOverflow.ellipsis),
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('$_currentPage / $_totalPages',
                    style: const TextStyle(color: AppColors.gold, fontSize: 13)),
              ),
            ),
        ],
      ),
      body: _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
                  const SizedBox(height: 16),
                  const Text('Impossible de charger le PDF.',
                      style: TextStyle(color: AppColors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(_errorMsg,
                      style: const TextStyle(color: AppColors.grey, fontSize: 11),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _downloadAndLoad,
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.navy),
                    label: const Text('RÉESSAYER',
                        style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                  ),
                ],
              ),
            )
          : _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.gold),
                      SizedBox(height: 16),
                      Text('Chargement du PDF...', style: TextStyle(color: AppColors.grey)),
                    ],
                  ),
                )
              : PDFView(
                  filePath: _localPath!,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  backgroundColor: AppColors.navy,
                  onRender: (pages) {
                    if (mounted) setState(() { _totalPages = pages ?? 0; _currentPage = 1; });
                  },
                  onViewCreated: (controller) {},
                  onPageChanged: (page, total) {
                    if (mounted) setState(() => _currentPage = (page ?? 0) + 1);
                  },
                  onError: (error) {
                    if (mounted) setState(() { _hasError = true; _errorMsg = error.toString(); });
                  },
                ),
    );
  }
}
