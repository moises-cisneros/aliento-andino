import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/upload_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/social_repository.dart';
import '../bloc/create_post/create_post_bloc.dart';
import '../bloc/create_post/create_post_event.dart';
import '../bloc/create_post/create_post_state.dart';

/// Pantalla para crear una nueva publicación.
class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          CreatePostBloc(socialRepository: ctx.read<SocialRepository>()),
      child: const _CreatePostView(),
    );
  }
}

class _CreatePostView extends StatefulWidget {
  const _CreatePostView();

  @override
  State<_CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<_CreatePostView> {
  final _contentController = TextEditingController();
  final _picker = ImagePicker();
  String _postType = 'text';
  File? _pickedImage;
  bool _uploading = false;
  String? _uploadedUrl;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() {
        _pickedImage = File(picked.path);
        _uploadedUrl = null;
        _postType = 'image';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la imagen: $e')),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _uploadedUrl = null;
      _postType = 'text';
    });
  }

  Future<void> _submit() async {
    final text = _contentController.text.trim();
    if (text.isEmpty && _pickedImage == null) return;

    String? mediaUrl = _uploadedUrl;

    // Subir imagen si hay una pendiente
    if (_pickedImage != null && mediaUrl == null) {
      setState(() => _uploading = true);
      try {
        mediaUrl = await context.read<UploadService>().uploadFile(
          filePath: _pickedImage!.path,
          folder: 'posts',
        );
        if (!mounted) return;
        _uploadedUrl = mediaUrl;
      } catch (e) {
        if (!mounted) return;
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir la imagen: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _uploading = false);
    }

    if (!mounted) return;
    context.read<CreatePostBloc>().add(
      CreatePostSubmit(
        content: text.isEmpty ? '📷' : text,
        postType: _postType,
        mediaUrl: mediaUrl,
      ),
    );
  }

  void _showImageSourceSheet() {
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
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreatePostBloc, CreatePostState>(
      listener: (context, state) {
        if (state is CreatePostSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Publicación creada'),
              backgroundColor: AppTheme.success,
            ),
          );
          context.pop(true);
        } else if (state is CreatePostError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Crear publicación'),
          actions: [
            BlocBuilder<CreatePostBloc, CreatePostState>(
              builder: (context, state) {
                final isSubmitting =
                    state is CreatePostSubmitting || _uploading;
                return TextButton(
                  onPressed: isSubmitting ? null : _submit,
                  child: isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : Text(
                          'Publicar',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Selector de tipo (solo si no hay imagen)
              if (_pickedImage == null)
                Row(
                  children: [
                    _typeChip('text', 'Texto', Icons.text_fields),
                    const SizedBox(width: 8),
                    _typeChip('achievement', 'Logro', Icons.emoji_events),
                    const SizedBox(width: 8),
                    _typeChip('practice_result', 'Práctica', Icons.music_note),
                  ],
                ),
              if (_pickedImage == null) const SizedBox(height: 16),

              // Preview de imagen
              if (_pickedImage != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _pickedImage!,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _removeImage,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Campo de texto
              Expanded(
                child: TextField(
                  controller: _contentController,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: '¿Qué estás practicando?',
                    hintStyle: TextStyle(color: Theme.of(context).hintColor),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Botón agregar imagen
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _showImageSourceSheet,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    _pickedImage == null ? 'Agregar foto' : 'Cambiar foto',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String type, String label, IconData icon) {
    final selected = _postType == type;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? Colors.white : Theme.of(context).hintColor,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Theme.of(context).hintColor,
      ),
      onSelected: (_) => setState(() => _postType = type),
    );
  }
}
