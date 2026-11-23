import 'dart:convert';
import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../screens/personal_note_detail_screen.dart';

class NoteEditScreen extends StatefulWidget {
  final PersonalNoteDetail noteDetail;

  const NoteEditScreen({Key? key, required this.noteDetail}) : super(key: key);

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // 控制器
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _addressController;

  // 表单数据
  late String _selectedType;
  late String _selectedTag;
  late List<String> _notePhotos;
  late String? _coverImageUrl;
  final ImagePicker _picker = ImagePicker(); // 图片选择器

  // 标签选项
  final List<String> _tags = [
    '羽毛球',
    '篮球',
    '足球',
    '爬山',
    '逛街',
    '旅游',
    '看电影',
    '健身',
    '饭搭子',
    '剧本杀',
    '密室逃脱',
    '聚会',
    '电影',
    '游戏',
    '运动',
    '飞盘',
    '排球',
    '台球',
    '乒乓球',
    '春游',
    '美食',
    '通信',
    '其他'
  ];

  bool _isLoading = false;

  // 格式化日期时间
  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return '';

    try {
      DateTime dateTime;
      // 尝试解析ISO 8601格式
      if (dateTimeStr.contains('T')) {
        dateTime = DateTime.parse(dateTimeStr);
      } else {
        // 尝试解析其他格式，如 "2024-01-01 12:00:00"
        dateTime = DateTime.parse(dateTimeStr.replaceAll(' ', 'T'));
      }
      // 格式化为标准格式: YYYY-MM-DD HH:mm:ss
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:00';
    } catch (e) {
      // 如果解析失败，返回原字符串
      return dateTimeStr;
    }
  }

  @override
  void initState() {
    super.initState();

    // 初始化表单数据
    _titleController = TextEditingController(text: widget.noteDetail.noteTitle);
    _contentController =
        TextEditingController(text: widget.noteDetail.noteContent);
    _selectedType = widget.noteDetail.noteType;
    _selectedTag = widget.noteDetail.noteTag;
    _notePhotos = List<String>.from(widget.noteDetail.notePhotos);
    _coverImageUrl = widget.noteDetail.coverImgUrl;

    // 活动类型特有字段
    if (widget.noteDetail.noteType == '活动') {
      _startTimeController =
          TextEditingController(text: _formatDateTime(widget.noteDetail.startTime));
      _endTimeController =
          TextEditingController(text: _formatDateTime(widget.noteDetail.endTime));
      _addressController =
          TextEditingController(text: widget.noteDetail.address ?? '');
    } else {
      _startTimeController = TextEditingController();
      _endTimeController = TextEditingController();
      _addressController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // 验证标题
  String? _validateTitle(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入笔记标题';
    }

    if (value.length > 60) {
      return '标题不能超过60个字符';
    }

    // 仅限中文、数字、字母、下划线、中划线、英文句号、空格
    final titleRegex = RegExp(r'^[\u4e00-\u9fa5a-zA-Z0-9_\-. ]+$');
    if (!titleRegex.hasMatch(value)) {
      return '标题只能包含中文、数字、字母、下划线、中划线、英文句号、空格';
    }

    return null;
  }

  // 验证内容
  String? _validateContent(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入笔记内容';
    }

    if (value.length > 2000) {
      return '内容不能超过2000个字符';
    }

    return null;
  }

  // 选择图片
  void _selectImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();

      if (pickedFiles.isNotEmpty) {
        // 限制最多18张图片
        final maxAllowed = 18 - _notePhotos.length;
        final actualFiles = pickedFiles.length > maxAllowed
            ? pickedFiles.sublist(0, maxAllowed)
            : pickedFiles;

        // 上传图片
        for (var file in actualFiles) {
          final uploadedUrl = await _uploadImage(file);
          print('Uploaded image URL: $uploadedUrl');

          if (uploadedUrl != null) {
            setState(() {
              _notePhotos.add(uploadedUrl);
              if (_coverImageUrl == null && _notePhotos.isNotEmpty) {
                _coverImageUrl = _notePhotos[0];
              }
            });
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('图片上传失败')),
              );
            }
          }
        }
      }
    } catch (e) {
      print('选择图片时出错: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片时出错: $e')),
        );
      }
    }
  }

  // 上传图片
  Future<String?> _uploadImage(XFile image) async {
    try {
      // 获取会话信息
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        print('用户未登录，无法上传图片');
        return null;
      }

      // 在Web平台上使用不同的上传方式
      if (kIsWeb) {
        // Web平台使用bytes上传
        final url = Uri.parse('${ApiService.baseUrl}/api/user/picture/upload');
        final request = http.MultipartRequest('POST', url);

        // 添加认证头
        request.headers['Authorization'] = 'Bearer ${session.authToken}';

        // 读取文件字节
        final bytes = await image.readAsBytes();

        // 根据文件扩展名确定内容类型
        String contentType = 'image/jpeg';
        if (image.name.contains('.')) {
          final extension = image.name.split('.').last.toLowerCase();
          switch (extension) {
            case 'png':
              contentType = 'image/png';
              break;
            case 'gif':
              contentType = 'image/gif';
              break;
            case 'jpeg':
            case 'jpg':
              contentType = 'image/jpeg';
              break;
            default:
              contentType = 'image/jpeg';
          }
        }

        // 添加文件
        final file = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: image.name,
          contentType:
              MediaType(contentType.split('/')[0], contentType.split('/')[1]),
        );
        request.files.add(file);

        // 发送请求
        final response = await request.send();
        final responseBody = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          final result = jsonDecode(responseBody);
          if (result['success'] == true) {
            return result['url'];
          } else {
            print('图片上传失败: ${result['message']}');
            return null;
          }
        } else {
          print('图片上传HTTP错误: ${response.statusCode}');
          return null;
        }
      } else {
        // 移动平台使用文件上传
        final url = Uri.parse('${ApiService.baseUrl}/api/user/picture/upload');
        final request = http.MultipartRequest('POST', url);

        // 添加认证头
        request.headers['Authorization'] = 'Bearer ${session.authToken}';

        // 添加文件
        final file = await http.MultipartFile.fromPath(
          'file',
          image.path,
          filename: image.name,
        );
        request.files.add(file);

        // 发送请求
        final response = await request.send();
        final responseBody = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          final result = jsonDecode(responseBody);
          if (result['success'] == true) {
            return result['url'];
          } else {
            print('图片上传失败: ${result['message']}');
            return null;
          }
        } else {
          print('图片上传HTTP错误: ${response.statusCode}');
          return null;
        }
      }
    } catch (e) {
      print('图片上传异常: $e');
      return null;
    }
  }

  // 提交笔记更新
  Future<void> _updateNote() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 验证必要字段
        if (_coverImageUrl == null || _coverImageUrl!.isEmpty) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请选择封面图片')),
            );
          }
          return;
        }

        // 活动类型需要验证时间和地点
        if (_selectedType == '活动') {
          if (_startTimeController.text.isEmpty) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请选择活动开始时间')),
              );
            }
            return;
          }

          if (_endTimeController.text.isEmpty) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请选择活动结束时间')),
              );
            }
            return;
          }

          if (_addressController.text.isEmpty) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入活动地点')),
              );
            }
            return;
          }
        }

        // 调用API更新笔记
        final result = await ApiService.updateNote(
          noteId: widget.noteDetail.noteId,
          noteTitle: _titleController.text,
          noteContent: _contentController.text,
          coverImgUrl: _coverImageUrl!,
          notePhotos: _notePhotos,
          noteType: _selectedType,
          noteTag: _selectedTag,
          noteStatus: 1, // 正常状态
          startTime: _selectedType == '活动' ? _startTimeController.text : null,
          endTime: _selectedType == '活动' ? _endTimeController.text : null,
          address: _selectedType == '活动' ? _addressController.text : null,
        );

        if (result['success'] == true) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            // 显示成功消息
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('笔记更新成功')),
            );

            // 返回个人笔记详情页面
            Navigator.pop(context, true); // 返回true表示更新成功
          }
        } else {
          final errorMessage = result['message'] ?? '更新失败';
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新过程中出现错误: $e')),
          );
        }
      }
    }
  }

  // 选择日期时间
  Future<void> _selectDateTime(TextEditingController controller) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final DateTime dateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // 格式化为 yyyy-MM-dd HH:mm:ss
        final formatted =
            "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} "
            "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:00";

        setState(() {
          controller.text = formatted;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑笔记'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _updateNote,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片选择区域
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '笔记图集',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '最多可选择18张图片，第一张为封面图片',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // 显示已选择的图片
                          ..._notePhotos.asMap().entries.map((entry) {
                            final index = entry.key;
                            final photoUrl = entry.value;
                            print('Displaying image: $photoUrl');
                            return Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _coverImageUrl == photoUrl
                                          ? Colors.deepPurple
                                          : Colors.grey,
                                      width: _coverImageUrl == photoUrl ? 3 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: (photoUrl.startsWith('http') ||
                                            photoUrl.startsWith('https'))
                                        ? Image.network(
                                            photoUrl,
                                            fit: BoxFit.cover,
                                            loadingBuilder:
                                                (BuildContext context,
                                                    Widget child,
                                                    ImageChunkEvent?
                                                        loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  value: loadingProgress
                                                              .expectedTotalBytes !=
                                                          null
                                                      ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                      : null,
                                                ),
                                              );
                                            },
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              print(
                                                  'Network image load error: $error');
                                              // 显示更友好的错误信息
                                              return const Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.warning,
                                                      color: Colors.orange),
                                                  Text(
                                                    '加载失败',
                                                    style:
                                                        TextStyle(fontSize: 10),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              );
                                            },
                                          )
                                        : Image.file(
                                            File(photoUrl),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              print(
                                                  'File image load error: $error');
                                              return const Icon(Icons.error);
                                            },
                                          ),
                                  ),
                                ),
                                // 删除按钮
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _notePhotos.removeAt(index);
                                        if (_coverImageUrl == photoUrl) {
                                          _coverImageUrl =
                                              _notePhotos.isNotEmpty
                                                  ? _notePhotos[0]
                                                  : null;
                                        }
                                      });
                                    },
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                // 设置为封面按钮
                                if (_coverImageUrl != photoUrl)
                                  Positioned(
                                    left: 0,
                                    bottom: 0,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _coverImageUrl = photoUrl;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '设为封面',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                          // 添加图片按钮
                          if (_notePhotos.length < 18)
                            GestureDetector(
                              onTap: _selectImages,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, size: 30),
                                    Text('添加图片',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_coverImageUrl == null)
                        const Text(
                          '请至少选择一张图片作为封面',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 标题输入
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '笔记标题 *',
                  border: OutlineInputBorder(),
                ),
                validator: _validateTitle,
                maxLength: 60,
              ),

              const SizedBox(height: 16),

              // 内容输入
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '笔记内容 *',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: _validateContent,
                maxLines: 6,
                maxLength: 2000,
              ),

              const SizedBox(height: 16),

              // 类型选择
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '笔记类型',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('打卡'),
                              leading: Radio<String>(
                                value: '打卡',
                                groupValue: _selectedType,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedType = value!;
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedType = '打卡';
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              title: const Text('活动'),
                              leading: Radio<String>(
                                value: '活动',
                                groupValue: _selectedType,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedType = value!;
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedType = '活动';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 标签选择
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '笔记标签',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedTag,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: _tags.map((tag) {
                          return DropdownMenuItem(
                            value: tag,
                            child: Text(tag),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedTag = value;
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请选择标签';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 活动特定字段
              if (_selectedType == '活动')
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '活动信息',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 开始时间
                        TextFormField(
                          controller: _startTimeController,
                          decoration: const InputDecoration(
                            labelText: '活动开始时间 *',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () => _selectDateTime(_startTimeController),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请选择活动开始时间';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // 结束时间
                        TextFormField(
                          controller: _endTimeController,
                          decoration: const InputDecoration(
                            labelText: '活动结束时间 *',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () => _selectDateTime(_endTimeController),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请选择活动结束时间';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // 地点
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: '活动地点 *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入活动地点';
                            }
                            if (value.length > 255) {
                              return '活动地点不能超过255个字符';
                            }
                            return null;
                          },
                          maxLength: 255,
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // 提交按钮
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateNote,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            '保存',
                            style: TextStyle(fontSize: 16),
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
}
