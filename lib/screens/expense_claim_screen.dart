import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:http_parser/http_parser.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:exif/exif.dart';
import 'dart:io';

import '../models/OfflineQueue.dart';

class ExpenseClaimScreen extends StatefulWidget {
  final String token;

  ExpenseClaimScreen({required this.token, Map<String, dynamic>? initialClaimData});

  @override
  _ExpenseClaimScreenState createState() => _ExpenseClaimScreenState();
}

class _ExpenseClaimScreenState extends State<ExpenseClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _montantController = TextEditingController();
  File? _selectedFile;
  bool _isSubmitting = false;
  String? _selectedCategory;
  String? _errorMessage;
  String? _lastExpenseId;
  String? _lastImageUrl;
  double _uploadProgress = 0.0;
  final List<String> _categories = ['FOOD', 'OTHER', 'SUPPLIES', 'TRAVEL'];
  final String _submissionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final Dio _dio = createDioClient();

  @override
  void initState() {
    super.initState();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.headers['Authorization'] = 'Bearer ${widget.token}';
        if (options.data is FormData) {
          options.headers['Content-Type'] = 'multipart/form-data';
        }
        return handler.next(options);
      },
    ));
    _initialize();
    _syncOfflineQueue();
  }

  Future<void> _initialize() async {
    await dotenv.load(fileName: '.env');
  }

  Future<void> pickFile() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (file != null) {
      File compressedFile = await _compressAndStripExif(File(file.path));
      setState(() {
        _selectedFile = compressedFile;
      });
    }
  }

  Future<File> _compressAndStripExif(File file) async {
    final img.Image? image = img.decodeImage(await file.readAsBytes());
    if (image == null) return file;

    final compressedBytes = img.encodeJpg(image, quality: 70);
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    File compressedFile = await File(tempPath).writeAsBytes(compressedBytes);

    final exifData = await readExifFromFile(compressedFile);
    if (exifData.isNotEmpty) {
      await compressedFile.writeAsBytes(compressedBytes);
    }

    return compressedFile;
  }

  Future<Map<String, String>?> _uploadClaim(Map<String, dynamic> data) async {
    final file = File(data['filePath']);
    if (!await file.exists()) {
      setState(() {
        _errorMessage = 'Selected file is no longer available.';
      });
      return null;
    }

    const maxFileSize = 5 * 1024 * 1024;
    if (file.lengthSync() > maxFileSize) {
      setState(() {
        _errorMessage = 'File size exceeds 5MB.';
      });
      return null;
    }
    final validExtensions = ['jpg', 'jpeg', 'png'];
    final extension = file.path.split('.').last.toLowerCase();
    if (!validExtensions.contains(extension)) {
      setState(() {
        _errorMessage = 'Only JPG and PNG files are allowed.';
      });
      return null;
    }

    String? imageUrl;
    try {
      final userId = getUserIdFromToken(widget.token);
      final expenseId = DateTime.now().millisecondsSinceEpoch.toString();
      setState(() {
        _uploadProgress = 0.2;
      });
      imageUrl = await uploadImageToCloudinary(file, userId, expenseId);
      setState(() {
        _uploadProgress = 0.5;
      });
      if (imageUrl == null) {
        print('Warning: Cloudinary upload failed, proceeding with MultipartFile only.');
      }

      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        'description': data['description'],
        'amount': data['amount'],
        'category': data['category'],
        'comment': data['description'],
        'image': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: MediaType('image', extension),
        ),
        if (imageUrl != null) 'imageUrl': imageUrl,
      });

      int maxRetries = 3;
      int retryCount = 0;
      while (retryCount < maxRetries) {
        try {
          final response = await _dio.post(
            '/claims',
            data: formData,
            options: Options(
              contentType: 'multipart/form-data',
              receiveTimeout: const Duration(seconds: 30),
            ),
            onSendProgress: (sent, total) {
              setState(() {
                _uploadProgress = 0.5 + (sent / total) * 0.5;
              });
            },
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            _resetForm();
            return {'expenseId': expenseId, 'imageUrl': imageUrl ?? ''};
          } else {
            throw DioException(
              requestOptions: RequestOptions(path: '/claims'),
              response: response,
              error: 'Unexpected status code: ${response.statusCode}',
            );
          }
        } catch (e) {
          retryCount++;
          if (retryCount == maxRetries) {
            throw e;
          }
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }
    } on DioException catch (e) {
      setState(() async {
        _errorMessage = 'Error: ${e.message}';
        if (e.response != null && e.response?.data is Map) {
          _errorMessage = e.response?.data['error'] ?? 'An error occurred.';
        } else if (e.response != null) {
          _errorMessage = 'Server Error: ${e.response?.statusCode}';
        } else {
          _errorMessage = 'Network Error: Could not connect.';
          await OfflineQueue().addToQueue({
            ...data,
            'cloudinaryUploaded': imageUrl != null ? 1 : 0,
            'cloudinaryUrl': imageUrl,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved offline. Will sync when online.'),
              backgroundColor: Colors.orange,
            ),
          );
          _resetForm();
        }
      });
      print('Upload Claim DioException: $e');
      return {'expenseId': DateTime.now().millisecondsSinceEpoch.toString(), 'imageUrl': imageUrl ?? ''};
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
      print('Upload Claim General Error: $e');
      return null;
    } finally {
      setState(() {
        _uploadProgress = 0.0;
      });
    }
  }

  Future<void> _syncOfflineQueue() async {
    final queue = await OfflineQueue().getQueue();
    for (var item in queue) {
      try {
        final file = File(item['filePath']);
        if (!await file.exists()) {
          await OfflineQueue().clearQueue(item['id']);
          continue;
        }

        String? imageUrl = item['cloudinaryUrl'];
        if (item['cloudinaryUploaded'] == 0) {
          final userId = getUserIdFromToken(widget.token);
          final expenseId = DateTime.now().millisecondsSinceEpoch.toString();
          imageUrl = await uploadImageToCloudinary(file, userId, expenseId);
          if (imageUrl != null) {
            final db = await OfflineQueue().database;
            await db.update(
              'queue',
              {'cloudinaryUrl': imageUrl, 'cloudinaryUploaded': 1},
              where: 'id = ?',
              whereArgs: [item['id']],
            );
          }
        }

        await _uploadClaim({
          'description': item['description'],
          'amount': item['amount'],
          'category': item['category'],
          'filePath': item['filePath'],
          'submissionDate': item['submissionDate'],
          'cloudinaryUrl': imageUrl,
        });

        await OfflineQueue().clearQueue(item['id']);
      } catch (e) {
        print('Failed to sync item ${item['id']}: $e');
      }
    }

    final deleteQueue = await OfflineQueue().getDeleteQueue();
    for (var item in deleteQueue) {
      try {
        await deleteCloudinaryImage(item['imageUrl'], item['expenseId']);
        await OfflineQueue().clearDeleteQueue(item['id']);
      } catch (e) {
        print('Failed to delete item ${item['id']}: $e');
      }
    }
  }

  Future<String?> uploadImageToCloudinary(File file, String userId, String expenseId) async {
    final cloudinary = CloudinaryPublic(dotenv.env['CLOUDINARY_CLOUD_NAME']!, dotenv.env['CLOUDINARY_UPLOAD_PRESET']!, cache: false);
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder: 'users/$userId/expenses/$expenseId',
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      print('Cloudinary Upload Error: $e');
      return null;
    }
  }

  String getUserIdFromToken(String token) {
    try {
      final payload = JwtDecoder.decode(token);
      print('JWT Payload: $payload');
      return payload['sub']?.toString() ?? 'anonymous';
    } catch (e) {
      print('Error decoding JWT: $e');
      return 'anonymous';
    }
  }

  Future<void> _submitExpenseClaim() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null || _selectedCategory == null) {
      setState(() {
        _errorMessage = 'Please select a receipt and category.';
      });
      return;
    }

    final data = {
      'description': _descriptionController.text.trim(),
      'amount': _montantController.text.trim(),
      'category': _selectedCategory!,
      'filePath': _selectedFile!.path,
      'submissionDate': _submissionDate,
      'cloudinaryUploaded': 0,
      'cloudinaryUrl': null,
    };

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await InternetAddress.lookup('google.com');
      final result = await _uploadClaim(data);
      if (result != null) {
        setState(() {
          _lastExpenseId = result['expenseId'];
          _lastImageUrl = result['imageUrl'];
        });
      }
    } on SocketException catch (_) {
      await OfflineQueue().addToQueue(data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved offline. Will sync when online.'), backgroundColor: Colors.orange),
      );
      _resetForm();
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _descriptionController.clear();
    _montantController.clear();
    setState(() {
      _selectedFile = null;
      _selectedCategory = null;
    });
  }

  Future<void> deleteCloudinaryImage(String imageUrl, String expenseId) async {
    try {
      await _dio.delete('/claims/$expenseId/image', queryParameters: {'imageUrl': imageUrl});
      print('Image deleted successfully');
    } catch (e) {
      print('Error deleting Cloudinary image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Claim'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Description is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _montantController,
                  decoration: const InputDecoration(
                    labelText: 'Amount *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) => val == null || val.isEmpty ? 'Amount is required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCategory,
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  validator: (value) => value == null ? 'Category is required' : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: pickFile,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture or Select Receipt'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87),
                ),
                if (_selectedFile != null) ...[
                  const SizedBox(height: 8),
                  Text('Selected: ${_selectedFile!.path.split('/').last}'),
                ],
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_isSubmitting) ...[
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('Uploading: ${(_uploadProgress * 100).toStringAsFixed(0)}%'),
                ],
                const SizedBox(height: 16),
                _isSubmitting
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _submitExpenseClaim,
                  child: const Text('Submit'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    backgroundColor: Colors.blueAccent,
                  ),
                ),
                if (_lastExpenseId != null && _lastImageUrl != null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await InternetAddress.lookup('google.com');
                        await deleteCloudinaryImage(_lastImageUrl!, _lastExpenseId!);
                        setState(() {
                          _lastExpenseId = null;
                          _lastImageUrl = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expense deleted'), backgroundColor: Colors.red),
                        );
                      } on SocketException catch (_) {
                        await OfflineQueue().addToDeleteQueue(_lastExpenseId!, _lastImageUrl!);
                        setState(() {
                          _lastExpenseId = null;
                          _lastImageUrl = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Deletion queued. Will sync when online.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    child: const Text('Delete Last Expense'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}