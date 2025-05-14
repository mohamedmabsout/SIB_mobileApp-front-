import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:sib_expense_app/models/dropdown_item.dart'; // Ensure this exists

// Define enums locally or import
enum TaskStatus { OPEN, IN_PROGRESS, COMPLETED, BLOCKED }
enum Priority { LOW, MEDIUM, HIGH }

class AddEditTaskScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? initialTaskData; // Null for Add

  const AddEditTaskScreen({
    Key? key,
    required this.token,
    this.initialTaskData,
  }) : super(key: key);

  bool get isEditing => initialTaskData != null;

  @override
  _AddEditTaskScreenState createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers
  final _taskNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  // State for Dropdowns - Store the selected DropdownItem object
  DropdownItem? _selectedProject;
  DropdownItem? _selectedUser;
  TaskStatus? _selectedStatus;
  Priority? _selectedPriority;
  DateTime? _dueDate;

  // Data for dropdowns
  List<DropdownItem> _projects = [];
  List<DropdownItem> _users = [];

  bool _isLoading = false; // For submit button
  bool _isFetchingDropdowns = true; // For initial dropdown load
  String? _errorMessage;
  final Dio _dio = createDioClient();
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _fetchDropdownData(); // Fetch lists first
  }

  @override
  void dispose() {
    _taskNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    if (!mounted) return;
    setState(() { _isFetchingDropdowns = true; _errorMessage = null; });

    try {
      print("Fetching dropdown data for tasks...");
      final results = await Future.wait([
        // --- FIX: Use simplified list endpoints ---
        _dio.get('/api/projects/list-simple'), // Expects List<DropdownItemDTO>
        _dio.get('/api/admin/users/list-simple'), // Expects List<DropdownItemDTO>
        // --- END FIX ---
      ]);

      if (!mounted) return;

      // Process Projects
      if (results[0].statusCode == 200 && results[0].data is List) {
        _projects = (results[0].data as List).map((p) {
          // Assuming backend sends id and name directly compatible with DropdownItemDTO
          // If keys are different (e.g., 'projectId', 'projName'), adjust here
          return DropdownItem(id: p['id'] as int? ?? 0, name: p['name'] ?? 'Unknown Project');
        }).toList();
        print("Loaded ${_projects.length} projects.");
      } else {
        print('Failed to load projects: ${results[0].statusCode}');
        // Set error or keep _projects empty, dropdown will show message
        _errorMessage = (_errorMessage ?? '') + '\nFailed to load projects.';
      }

      // Process Users
      if (results[1].statusCode == 200 && results[1].data is List) {
        _users = (results[1].data as List).map((u) {
          // Adjust keys ('id', 'name') if backend sends different names (e.g., 'userId', 'username')
          return DropdownItem(id: u['id'] as int? ?? 0, name: u['name'] ?? 'Unknown User');
        }).toList();
        print("Loaded ${_users.length} users.");
      } else {
        print('Failed to load users: ${results[1].statusCode}');
        _errorMessage = (_errorMessage ?? '') + '\nFailed to load users.';
      }


      // If editing, populate form AFTER dropdowns lists are potentially populated
      if (widget.isEditing && widget.initialTaskData != null) {
        _populateForm(widget.initialTaskData!);
      }

      setState(() { _isFetchingDropdowns = false; _isLoading = false; });

    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'loading dropdown data');
      setState(() { _isFetchingDropdowns = false; _isLoading = false; });
    }
  }

  // Populate form fields from initial data (when editing)
  void _populateForm(Map<String, dynamic> data) {
    _taskNameController.text = data['taskName'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    try {
      _dueDate = data['dueDate'] != null ? DateTime.tryParse(data['dueDate']) : null;

      // Set selected status enum
      if (data['status'] != null && data['status'] is String) {
        _selectedStatus = TaskStatus.values.firstWhere((e) => e.name == data['status'], orElse: () => TaskStatus.OPEN);
      } else { _selectedStatus = TaskStatus.OPEN; } // Default

      // Set selected priority enum
      if (data['priority'] != null && data['priority'] is String) {
        _selectedPriority = Priority.values.firstWhere((e) => e.name == data['priority'], orElse: () => Priority.MEDIUM);
      } else { _selectedPriority = Priority.MEDIUM; } // Default


      // --- FIX: Find matching DropdownItem for Project ---
      final projectData = data['project'] as Map<String, dynamic>?; // Get nested project info
      final projectId = projectData?['id'] as int?; // Get the ID from nested info
      if (projectId != null) {
        try {
          // Find the DropdownItem in the _projects list that has the matching ID
          _selectedProject = _projects.firstWhere((p) => p.id == projectId);
        } catch (e) {
          print("Warning: Initial project ID $projectId not found in fetched list _projects. Current list: $_projects");
          // Keep _selectedProject null if not found
          _selectedProject = null;
        }
      } else { _selectedProject = null; }
      // --- END FIX ---

      // --- FIX: Find matching DropdownItem for User ---
      final userData = data['assignedToUser'] as Map<String, dynamic>?; // Get nested user info
      final userId = userData?['id'] as int?; // Get the ID from nested info
      if (userId != null) {
        try {
          // Find the DropdownItem in the _users list that has the matching ID
          _selectedUser = _users.firstWhere((u) => u.id == userId);
        } catch (e) {
          print("Warning: Initial user ID $userId not found in fetched list _users. Current list: $_users");
          _selectedUser = null;
        }
      } else { _selectedUser = null; }
      // --- END FIX ---

    } catch(e) {
      print("Error parsing initial task data for form: $e");
      setState(() => _errorMessage = "Error loading task details.");
    }
    // No need for setState here if called within setState in _fetchInitialData
  }

  Future<void> _submitTask() async {
    // Validate form AND dropdown selections
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStatus == null || _selectedPriority == null || _selectedProject == null || _selectedUser == null ) {
      setState(() { _errorMessage = 'Please fill all required (*) fields/selections.'; });
      return;
    }
    final String actionVerb = widget.isEditing ? 'updating' : 'adding';
    final String successVerb = widget.isEditing ? 'updated' : 'added';
    setState(() { _isLoading = true; _errorMessage = null; });

    // Prepare data map matching backend DTO
    Map<String, dynamic> taskData = {
      'taskName': _taskNameController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'dueDate': _dueDate != null ? _dateFormatter.format(_dueDate!) : null,
      'status': _selectedStatus!.name,
      'priority': _selectedPriority!.name,
      // Send the IDs from the selected DropdownItems
      'projectId': _selectedProject!.id,
      'assignedUserId': _selectedUser!.id,
    };

    try {
      Response response;
      String actionVerb = widget.isEditing ? 'updating' : 'adding';
      String successVerb = widget.isEditing ? 'updated' : 'added';

      if (widget.isEditing) {
        final taskId = widget.initialTaskData!['id'];
        print('Updating task ID: $taskId with data: $taskData');
        // **VERIFY/MODIFY** PUT endpoint
        response = await _dio.put('/api/tasks/$taskId', data: taskData);
      } else {
        print('Adding new task with data: $taskData');
        // **VERIFY/MODIFY** POST endpoint
        response = await _dio.post('/api/tasks', data: taskData);
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Task $successVerb successfully!'), backgroundColor: Colors.green) );
        Navigator.pop(context, true); // Signal success
      } else {
        _handleApiError(response, 'Failed to $actionVerb task');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, '$actionVerb task');
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  void _handleApiError(Response? response, String defaultMessage) {
    if (!mounted) return; // Check if the widget is still in the tree

    String errorMsg = defaultMessage; // Start with the default message
    int? statusCode = response?.statusCode; // Get status code safely

    // Try to extract a more specific error from the response body
    if (response?.data is Map) {
      // Check common error keys (adjust based on your backend's error structure)
      final responseData = response!.data as Map<String, dynamic>;
      if (responseData.containsKey('error') && responseData['error'] != null && responseData['error'].isNotEmpty) {
        errorMsg = responseData['error'].toString();
      } else if (responseData.containsKey('message') && responseData['message'] != null && responseData['message'].isNotEmpty) {
        // Sometimes errors are in 'message'
        errorMsg = responseData['message'].toString();
      } else if (response.statusMessage != null && response.statusMessage!.isNotEmpty) {
        // Fallback to HTTP status message if available and data wasn't helpful
        errorMsg = response.statusMessage!;
      }
      // You could add more checks for specific backend error structures here
    } else if (response?.data is String && response!.data.isNotEmpty) {
      // Sometimes the error is just a plain string in the body
      errorMsg = response.data;
    } else if (response?.statusMessage != null && response!.statusMessage!.isNotEmpty) {
      // Fallback to HTTP status message if response data is not helpful at all
      errorMsg = response.statusMessage!;
    }

    final statusCodeStr = statusCode ?? 'N/A'; // Display N/A if status code is null

    setState(() {
      // Combine the extracted/default message with the status code
      _errorMessage = '$errorMsg (Status: $statusCodeStr)';
      // _successMessage = null; // Clear any previous success message
    });

    // Log details for debugging
    print('$defaultMessage - Status: $statusCodeStr, Response Body: ${response?.data}');
  }

  // --- Error Handling Helper for General Exceptions (Network, Parsing, etc.) ---
  void _handleGenericError(Object e, String action) {
    if (!mounted) return;

    String errorMsg = 'Error $action'; // Base message

    // Check specifically for DioException (or DioError if using Dio v4)
    if (e is DioException) {
      print('DioException Type: ${e.type}'); // Log Dio exception type
      if (e.response != null && e.response?.data is Map) {
        // Try to get error from response data if available
        final responseData = e.response!.data as Map<String, dynamic>;
        if (responseData.containsKey('error') && responseData['error'] != null && responseData['error'].isNotEmpty) {
          errorMsg = responseData['error'].toString();
        } else if (responseData.containsKey('message') && responseData['message'] != null && responseData['message'].isNotEmpty) {
          errorMsg = responseData['message'].toString();
        } else {
          // Fallback if specific keys aren't found but data exists
          String responsePreview = e.response?.data.toString() ?? '';
          errorMsg = "Server Error (${e.response?.statusCode}): ${responsePreview.substring(0, (responsePreview.length > 100 ? 100 : responsePreview.length)) }..."; // Truncate long errors
        }
      } else if (e.response != null) {
        // Error with response but no usable data map
        errorMsg = 'Server Error: ${e.response?.statusCode} ${e.response?.statusMessage ?? ''}'.trim();
      } else {
        // Error without a response (network, connection, timeout, etc.)
        switch(e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            errorMsg = 'Network Timeout: Please check connection.';
            break;
          case DioExceptionType.connectionError:
          // Try to provide more details if possible from the underlying error
            var originalError = e.error;
            if (originalError is SocketException) {
              errorMsg = 'Network Error: Could not connect (${originalError.osError?.message ?? 'No details'}). Check server address and network.';
            } else {
              errorMsg = 'Network Error: Could not connect to server.';
            }
            break;
          case DioExceptionType.cancel:
            errorMsg = 'Request cancelled.';
            break;
          case DioExceptionType.badCertificate:
            errorMsg = 'Invalid server certificate.';
            break;
          case DioExceptionType.badResponse:
            errorMsg = 'Invalid response from server.';
            break;
          case DioExceptionType.unknown:
          default:
            errorMsg = 'Network Error: An unknown network issue occurred (${e.message})';
            break;
        }
      }
    } else {
      // Handle other non-Dio exceptions
      errorMsg = 'An unexpected error occurred.';
      print('Non-Dio Error type: ${e.runtimeType}');
    }

    setState(() {
      _errorMessage = errorMsg;
      // _successMessage = null; // Clear success message on error
    });

    print('Error during "$action": $e'); // Log the full original exception
  }

  // --- Date Picker Logic ---
  Future<void> _selectDueDate(BuildContext context) async {
    // Suggest an initial date: current selection, or today
    final DateTime initial = _dueDate ?? DateTime.now();
    // Define boundaries: Allow past dates? How far in future?
    final DateTime first = DateTime.now().subtract(const Duration(days: 365)); // Example: 1 year in past
    final DateTime last = DateTime.now().add(const Duration(days: 365 * 5)); // Example: 5 years in future

    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: last
    );

    // Update state only if a date was actually picked and it's different
    if (picked != null && picked != _dueDate && mounted) {
      setState(() {
        _dueDate = picked;
        print("--- Due Date selected and set in state: $_dueDate ---");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = widget.isEditing ? 'Edit Task' : 'Add New Task';
    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle), backgroundColor: Colors.orange),
      body: _isFetchingDropdowns // Show loading while fetching dropdown data
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(controller: _taskNameController, decoration: InputDecoration(labelText: 'Task Name *', border: OutlineInputBorder()), validator: (v)=> v==null||v.isEmpty?'Required':null),
              SizedBox(height: 12),
              TextFormField(controller: _descriptionController, decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder()), maxLines: 3),
              SizedBox(height: 12),
              // --- UPDATED Project Dropdown ---
              DropdownButtonFormField<DropdownItem>(
                value: _selectedProject,
                items: _projects.isEmpty
                    ? [ const DropdownMenuItem(enabled: false, child: Text("Loading or No Projects...")) ]
                    : _projects.map((DropdownItem p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) { setState(() => _selectedProject = v); },
                decoration: InputDecoration(
                  labelText: 'Project *',
                  border: OutlineInputBorder(),
                  hintText: _projects.isEmpty ? 'No projects available' : null,
                ),
                validator: (v) => v == null ? 'Project is required' : null,
                isExpanded: true,
              ),
              // --- END Project Dropdown ---
              SizedBox(height: 12),
              // --- UPDATED User Dropdown ---
              DropdownButtonFormField<DropdownItem>(
                value: _selectedUser,
                items: _users.isEmpty
                    ? [ const DropdownMenuItem(enabled: false, child: Text("Loading or No Users...")) ]
                    : _users.map((DropdownItem u) => DropdownMenuItem(value: u, child: Text(u.name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) { setState(() => _selectedUser = v); },
                decoration: InputDecoration(
                  labelText: 'Assigned User *',
                  border: OutlineInputBorder(),
                  hintText: _users.isEmpty ? 'No users available' : null,
                ),
                validator: (v) => v == null ? 'User is required' : null,
                isExpanded: true,
              ),
              // --- END User Dropdown ---
              SizedBox(height: 12),
              // Due Date Picker Row
              Row(children: [ Expanded(child: InputDecorator(decoration: InputDecoration(labelText: 'Due Date (Optional)', border: OutlineInputBorder()), child: Text(_dueDate != null ? _dateFormatter.format(_dueDate!) : 'Select Date'))), IconButton(icon: Icon(Icons.calendar_month), onPressed:()=> _selectDueDate(context))]),
              SizedBox(height: 12),
              // Status Dropdown
              DropdownButtonFormField<TaskStatus>(value: _selectedStatus, items: TaskStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(), onChanged: (v){setState(()=>_selectedStatus=v);}, decoration: InputDecoration(labelText: 'Status *', border: OutlineInputBorder()), validator:(v)=>v==null?'Required':null),
              SizedBox(height: 12),
              // Priority Dropdown
              DropdownButtonFormField<Priority>(value: _selectedPriority, items: Priority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(), onChanged: (v){setState(()=>_selectedPriority=v);}, decoration: InputDecoration(labelText: 'Priority *', border: OutlineInputBorder()), validator:(v)=>v==null?'Required':null),
              SizedBox(height: 24),
              // Error Message
              if (_errorMessage != null) Padding( padding: const EdgeInsets.only(bottom: 16.0), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center,) ),
              // Submit Button
              ElevatedButton( onPressed: _isLoading ? null : _submitTask, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: _isLoading ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.isEditing ? 'Save Changes' : 'Add Task')),
            ],
          ),
        ),
      ),
    );
  }
} // End of _AddEditTaskScreenState