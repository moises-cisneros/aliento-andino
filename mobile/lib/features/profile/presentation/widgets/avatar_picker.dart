import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/upload_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Widget para seleccionar/subir foto de perfil.
/// Abre galería o cámara, sube a Cloud Storage y devuelve la URL pública.
class AvatarPicker extends StatefulWidget {
  final String? currentUrl;
  final String fullName;
  final ValueChanged<String> onUrlChanged;

  const AvatarPicker({
    super.key,
    this.currentUrl,
    required this.fullName,
    required this.onUrlChanged,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  final _picker = ImagePicker();
  File? _localPreview;
  bool _uploading = false;

  Future<void> _pick(ImageSource source) async {
    // Capturar el servicio ANTES de cualquier await (sync use of context).
    final uploadService = context.read<UploadService>();
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() {
        _localPreview = File(picked.path);
        _uploading = true;
      });

      final url = await uploadService.uploadFile(
        filePath: picked.path,
        folder: 'avatars',
      );
      if (!mounted) return;
      widget.onUrlChanged(url);
      setState(() => _uploading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _localPreview = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir el avatar: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            if (widget.currentUrl != null || _localPreview != null)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Quitar foto',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _localPreview = null);
                  widget.onUrlChanged('');
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasAvatar = widget.currentUrl != null || _localPreview != null;

    ImageProvider? imageProvider;
    if (_localPreview != null) {
      imageProvider = FileImage(_localPreview!);
    } else if (widget.currentUrl != null && widget.currentUrl!.isNotEmpty) {
      imageProvider = NetworkImage(widget.currentUrl!);
    }

    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: hasAvatar ? cs.primary : cs.outline,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: cs.surfaceContainerHigh,
                backgroundImage: imageProvider,
                child: !hasAvatar
                    ? Text(
                        widget.fullName.isNotEmpty
                            ? widget.fullName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            // Spinner mientras sube
            if (_uploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            // Botón camara
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: cs.primary,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _uploading ? null : _showSourceSheet,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _uploading ? null : _showSourceSheet,
          child: Text(
            hasAvatar ? 'Cambiar foto' : 'Subir foto',
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
