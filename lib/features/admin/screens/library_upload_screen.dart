import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';

class LibraryUploadScreen extends StatefulWidget {
  const LibraryUploadScreen({super.key});

  @override
  State<LibraryUploadScreen> createState() => _LibraryUploadScreenState();
}

class _LibraryUploadScreenState extends State<LibraryUploadScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _titleController = TextEditingController();
  File? _selectedFile;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'mp3', 'wav', 'mp4'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _startUpload() async {
    if (_selectedFile == null || _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir le titre et sélectionner un fichier')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final response = await _apiService.uploadFile(
        '/library/upload',
        _selectedFile!.path,
        _titleController.text,
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fichier ajouté à la bibliothèque avec succès !'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Erreur lors de l\'upload');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: const Text('AJOUTER DU CONTENU'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Titre de la ressource',
              style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(
                hintText: 'Ex: Guide Stratégique PDF',
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Fichier (PDF, Audio)',
              style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFileSelector(),
            const SizedBox(height: 48),
            _isUploading
                ? _buildUploadProgress()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startUpload,
                      child: const Text('LANCER L\'UPLOAD'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelector() {
    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.darkBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedFile != null ? AppColors.gold : AppColors.white.withOpacity(0.1),
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: _selectedFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_rounded, color: AppColors.gold.withOpacity(0.5), size: 48),
                  const SizedBox(height: 12),
                  const Text('Cliquez pour choisir un fichier', style: TextStyle(color: AppColors.grey)),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.insert_drive_file_rounded, color: AppColors.gold, size: 48),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _selectedFile!.path.split('/').last,
                      style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _pickFile,
                    child: const Text('Changer de fichier', style: TextStyle(color: AppColors.gold)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Column(
      children: [
        const LinearProgressIndicator(
          backgroundColor: AppColors.darkBlue,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Upload en cours...',
          style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Veuillez patienter',
          style: TextStyle(color: AppColors.grey, fontSize: 12),
        ),
      ],
    );
  }
}
