import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';

class LibraryUploadScreen extends StatefulWidget {
  final String initialType;
  const LibraryUploadScreen({super.key, this.initialType = 'pdf'});

  @override
  State<LibraryUploadScreen> createState() => _LibraryUploadScreenState();
}

class _LibraryUploadScreenState extends State<LibraryUploadScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _titleController = TextEditingController();
  late String _selectedType;
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  List<String> get _allowedExtensions {
    switch (_selectedType) {
      case 'pdf': return ['pdf'];
      case 'audio': return ['mp3', 'wav', 'm4a'];
      case 'video': return ['mp4', 'mov', 'avi'];
      default: return ['pdf'];
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (result != null) {
      setState(() => _selectedFile = result.files.single);
    }
  }

  Future<void> _startUpload() async {
    if (_selectedFile == null || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir le titre et selectionner un fichier')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      http.StreamedResponse response;

      // Sur Android, path peut etre un URI content:// — on utilise les bytes si disponibles
      if (_selectedFile!.bytes != null) {
        response = await _apiService.uploadFileBytes(
          '/library/upload',
          _selectedFile!.bytes!,
          _selectedFile!.name,
          _titleController.text.trim(),
        );
      } else if (_selectedFile!.path != null) {
        response = await _apiService.uploadFile(
          '/library/upload',
          _selectedFile!.path!,
          _titleController.text.trim(),
        );
      } else {
        throw Exception('Impossible de lire le fichier. Reessayez.');
      }

      final body = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fichier uploade sur Supabase Storage !'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final data = jsonDecode(body);
        throw Exception(data['error'] ?? 'Erreur serveur (${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(title: const Text('AJOUTER DU CONTENU')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_done_rounded, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stockage Supabase — accessible par tous les utilisateurs',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text('Type de contenu',
                style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTypeChip('pdf', '📄', 'PDF'),
                const SizedBox(width: 12),
                _buildTypeChip('audio', '🎵', 'Audio'),
                const SizedBox(width: 12),
                _buildTypeChip('video', '🎬', 'Video'),
              ],
            ),
            const SizedBox(height: 28),

            const Text('Titre de la ressource',
                style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                hintText: _selectedType == 'pdf'
                    ? 'Ex: Guide Strategique BTS'
                    : _selectedType == 'audio'
                        ? 'Ex: Masterclass Leadership'
                        : 'Ex: Conference Marketing',
              ),
            ),
            const SizedBox(height: 28),

            const Text('Fichier',
                style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Formats: ${_allowedExtensions.map((e) => e.toUpperCase()).join(', ')}',
              style: const TextStyle(color: AppColors.grey, fontSize: 11),
            ),
            const SizedBox(height: 12),
            _buildFileSelector(),
            const SizedBox(height: 40),

            _isUploading
                ? _buildUploadProgress()
                : ElevatedButton.icon(
                    onPressed: _startUpload,
                    icon: const Icon(Icons.cloud_upload_rounded, color: AppColors.navy),
                    label: const Text('UPLOADER SUR SUPABASE',
                        style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String emoji, String label) {
    final isActive = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedType = type;
          _selectedFile = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? AppColors.gold : AppColors.darkBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? AppColors.gold : AppColors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.navy : AppColors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileSelector() {
    return InkWell(
      onTap: _isUploading ? null : _pickFile,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.darkBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedFile != null ? AppColors.gold : AppColors.white.withOpacity(0.1),
            width: 2,
          ),
        ),
        child: _selectedFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file_rounded, color: AppColors.gold.withOpacity(0.5), size: 44),
                  const SizedBox(height: 10),
                  const Text('Appuyez pour choisir un fichier',
                      style: TextStyle(color: AppColors.grey)),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedType == 'pdf'
                        ? Icons.picture_as_pdf_rounded
                        : _selectedType == 'audio'
                            ? Icons.audiotrack_rounded
                            : Icons.videocam_rounded,
                    color: AppColors.gold,
                    size: 36,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _selectedFile!.name,
                      style: const TextStyle(
                          color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_formatSize(_selectedFile!.size),
                      style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                  TextButton(
                    onPressed: _pickFile,
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                    child: const Text('Changer',
                        style: TextStyle(color: AppColors.gold, fontSize: 12)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    return const Column(
      children: [
        LinearProgressIndicator(
          backgroundColor: AppColors.darkBlue,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_rounded, color: AppColors.gold, size: 18),
            SizedBox(width: 8),
            Text('Upload vers Supabase en cours...',
                style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 4),
        Text("Ne fermez pas l'application",
            style: TextStyle(color: AppColors.grey, fontSize: 12)),
      ],
    );
  }
}
