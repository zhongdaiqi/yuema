import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class AvatarEditScreen extends StatefulWidget {
  final String currentAvatarUrl;

  const AvatarEditScreen({Key? key, required this.currentAvatarUrl})
      : super(key: key);

  @override
  State<AvatarEditScreen> createState() => _AvatarEditScreenState();
}

class _AvatarEditScreenState extends State<AvatarEditScreen> {
  XFile? _pickedImage;
  bool _isUploading = false;
  String? _newAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑头像'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: _isUploading || _pickedImage == null
                  ? null
                  : _uploadAndSaveAvatar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple, // 深紫色背景
                foregroundColor: Colors.white, // 白色文字
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                '保存',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minHeight: constraints.maxHeight -
                    kToolbarHeight -
                    MediaQuery.of(context).padding.top),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // 当前头像展示
                if (widget.currentAvatarUrl.isNotEmpty && _pickedImage == null)
                  Column(
                    children: [
                      const Text('当前头像',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      CircleAvatar(
                        radius: 80,
                        backgroundImage: NetworkImage(widget.currentAvatarUrl),
                        onBackgroundImageError: (exception, stackTrace) {
                          // 处理头像加载失败
                        },
                      ),
                    ],
                  ),

                // 选择的新头像预览
                if (_pickedImage != null)
                  Column(
                    children: [
                      const Text('新头像预览',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      CircleAvatar(
                        radius: 80,
                        // 三元两分支需显式声明 ImageProvider，否则被推断为 Object
                        // （Dart 3.11 analyzer 严格化后报 argument_type_not_assignable）
                        backgroundImage: kIsWeb
                            ? NetworkImage(_pickedImage!.path) as ImageProvider<Object>
                            : FileImage(File(_pickedImage!.path)),
                      ),
                      const SizedBox(height: 16),
                      if (_isUploading)
                        const Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('正在上传...'),
                          ],
                        ),
                    ],
                  ),

                const SizedBox(height: 32),

                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: const Text('选择图片'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 通用提示信息
                const Text(
                  '操作流程：\n'
                  '1. 选择图片\n'
                  '2. 预览新头像\n'
                  '3. 点击右上角"保存"完成修改',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 20), // 底部间距
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedImage != null) {
        setState(() {
          _pickedImage = pickedImage;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<void> _uploadAndSaveAvatar() async {
    if (_pickedImage == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // 获取文件字节和文件名
      Uint8List fileBytes;
      String fileName;

      if (kIsWeb) {
        fileBytes = await _pickedImage!.readAsBytes();
        fileName = _pickedImage!.name;
      } else {
        final fileToUpload = File(_pickedImage!.path);
        fileBytes = await fileToUpload.readAsBytes();
        fileName = fileToUpload.path.split('/').last;
      }

      // 1. 上传头像文件
      final uploadResult = await ApiService.uploadAvatar(
        fileBytes: fileBytes,
        fileName: fileName,
      );

      if (uploadResult == null || !uploadResult['success']) {
        throw Exception(uploadResult?['message'] ?? '上传失败');
      }

      final avatarUrl = uploadResult['url'];
      if (avatarUrl == null) {
        throw Exception('服务器未返回头像URL');
      }

      // 2. 更新用户头像信息
      final updateResult = await ApiService.updateAvatar(avatarUrl: avatarUrl);

      if (updateResult['success'] != true) {
        throw Exception(updateResult['message']);
      }

      setState(() {
        _newAvatarUrl = avatarUrl;
        _isUploading = false;
      });

      // 返回新头像URL给上一个页面
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像更新成功')),
        );

        Navigator.pop(context, avatarUrl);
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像更新失败: $e')),
        );
      }
    }
  }
}
