import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hostelapp/services/banner_service.dart';

class BannerManagementScreen extends StatefulWidget {
  const BannerManagementScreen({super.key});

  @override
  State<BannerManagementScreen> createState() => _BannerManagementScreenState();
}

class _BannerManagementScreenState extends State<BannerManagementScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Manage Banners',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _isUploading ? null : () => _addNewBanner(context),
            icon: _isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate),
            label: Text(_isUploading ? 'Uploading...' : 'Add'),
          ),
        ],
      ),
      body: Consumer<BannerService>(
        builder: (context, bannerService, child) {
          return StreamBuilder<List<BannerImage>>(
            stream: bannerService.streamAllBanners(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final banners = snapshot.data ?? [];

              if (banners.isEmpty) {
                return _buildEmptyState();
              }

              return ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: banners.length,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  final reordered = List<BannerImage>.from(banners);
                  final item = reordered.removeAt(oldIndex);
                  reordered.insert(newIndex, item);
                  bannerService.reorderBanners(reordered);
                },
                itemBuilder: (context, index) {
                  return _buildBannerCard(banners[index], bannerService);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.blue[300],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Banners Yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add images to display on the dashboard',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _addNewBanner(context),
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Add First Banner'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1a1a2e),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerCard(BannerImage banner, BannerService bannerService) {
    return Card(
      key: ValueKey(banner.id),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Preview
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: banner.imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, size: 48),
                  ),
                ),
              ),
              // Status Badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: banner.isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    banner.isActive ? 'ACTIVE' : 'HIDDEN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Drag Handle
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.drag_handle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          // Details and Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner.title ?? 'No title',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: banner.title != null
                              ? Colors.black
                              : Colors.grey,
                        ),
                      ),
                      if (banner.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          banner.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Edit Button
                IconButton(
                  onPressed: () => _editBanner(context, banner, bannerService),
                  icon: Icon(Icons.edit_outlined, color: Colors.blue[600]),
                  tooltip: 'Edit',
                ),
                // Toggle Active
                IconButton(
                  onPressed: () {
                    bannerService.toggleBannerActive(
                      banner.id,
                      !banner.isActive,
                    );
                  },
                  icon: Icon(
                    banner.isActive ? Icons.visibility : Icons.visibility_off,
                    color: banner.isActive ? Colors.green : Colors.grey,
                  ),
                  tooltip: banner.isActive ? 'Hide' : 'Show',
                ),
                // Delete Button
                IconButton(
                  onPressed: () =>
                      _deleteBanner(context, banner, bannerService),
                  icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewBanner(BuildContext context) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image == null) return;

    // Show dialog to add title and description
    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => _AddBannerDialog(),
    );

    if (result == null) return;

    setState(() => _isUploading = true);

    try {
      final bannerService = Provider.of<BannerService>(context, listen: false);
      await bannerService.addBanner(
        imageFile: File(image.path),
        title: result['title'],
        description: result['description'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banner added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _editBanner(
    BuildContext context,
    BannerImage banner,
    BannerService bannerService,
  ) {
    final titleController = TextEditingController(text: banner.title);
    final descController = TextEditingController(text: banner.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Banner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Title (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              bannerService.updateBanner(
                bannerId: banner.id,
                title: titleController.text.isEmpty
                    ? null
                    : titleController.text,
                description: descController.text.isEmpty
                    ? null
                    : descController.text,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Banner updated!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteBanner(
    BuildContext context,
    BannerImage banner,
    BannerService bannerService,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Banner?'),
        content: const Text(
          'This action cannot be undone. The image will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await bannerService.deleteBanner(banner.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Banner deleted'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AddBannerDialog extends StatefulWidget {
  @override
  State<_AddBannerDialog> createState() => _AddBannerDialogState();
}

class _AddBannerDialogState extends State<_AddBannerDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Banner Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title (optional)',
              hintText: 'e.g., Special Offer',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'e.g., 10% off this month',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'title': _titleController.text.isEmpty
                  ? null
                  : _titleController.text,
              'description': _descController.text.isEmpty
                  ? null
                  : _descController.text,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1a1a2e),
          ),
          child: const Text('Add Banner'),
        ),
      ],
    );
  }
}
