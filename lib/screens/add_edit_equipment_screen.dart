import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:sib_expense_app/models/dropdown_item.dart';

// ignore_for_file: constant_identifier_names // Add this to ignore enum case warning
enum EquipmentStatus { NEW, ASSIGNED, IN_STORAGE, UNDER_MAINTENANCE, BROKEN, DISPOSED }

class AddEditEquipmentScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? initialEquipmentData;

  const AddEditEquipmentScreen({
    Key? key,
    required this.token,
    this.initialEquipmentData,
  }) : super(key: key);

  bool get isEditing => initialEquipmentData != null;

  @override
  _AddEditEquipmentScreenState createState() => _AddEditEquipmentScreenState();
}

class _AddEditEquipmentScreenState extends State<AddEditEquipmentScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _serialController = TextEditingController();
  final _minStockController = TextEditingController(text: '0');

  // State
  DateTime? _purchaseDate;
  EquipmentStatus? _selectedStatus;
  DropdownItem? _selectedUser; // Now explicitly nullable
  DropdownItem? _selectedProject; // Now explicitly nullable

  // Dropdown Data
  List<DropdownItem> _users = [];
  List<DropdownItem> _projects = [];

  bool _isLoading = false;
  bool _isFetchingDropdowns = true;
  String? _errorMessage;
  final Dio _dio = createDioClient();
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _serialController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    // ... (Keep implementation - fetches users and projects) ...
    if (!mounted) return;
    setState(() { _isFetchingDropdowns = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        _dio.get('/api/admin/users/list-simple'), // **VERIFY Endpoint**
        _dio.get('/api/projects/list-simple'), // **VERIFY Endpoint**
      ]);
      if (!mounted) return;

      // Process Users
      if (results[0].statusCode == 200 && results[0].data is List) {
        _users = (results[0].data as List).map((u) {
          // Adjust keys if backend sends different names (e.g., 'userId', 'username')
          return DropdownItem(id: u['id'] as int? ?? 0, name: u['name'] ?? 'Unknown User');
        }).toList();
      } else { throw Exception('Failed to load users'); }

      // Process Projects
      if (results[1].statusCode == 200 && results[1].data is List) {
        _projects = (results[1].data as List).map((p) {
          // Adjust keys if backend sends different names (e.g., 'projectId', 'projName')
          return DropdownItem(id: p['id'] as int? ?? 0, name: p['name'] ?? 'Unknown Project');
        }).toList();
      } else { throw Exception('Failed to load projects'); }


      if (widget.isEditing && widget.initialEquipmentData != null) {
        _populateForm(widget.initialEquipmentData!);
      }
      setState(() { _isFetchingDropdowns = false; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'loading dropdown data');
      setState(() { _isFetchingDropdowns = false; _isLoading = false; });
    }
  }

  void _populateForm(Map<String, dynamic> data) {
    _nameController.text = data['name'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _serialController.text = data['serialNumber'] ?? '';
    _minStockController.text = (data['minimumStockLevel'] as int?)?.toString() ?? '0';
    try {
      _purchaseDate = data['purchaseDate'] != null ? DateTime.tryParse(data['purchaseDate']) : null;
      if (data['status'] != null) {
        _selectedStatus = EquipmentStatus.values.firstWhere(
                (e) => e.name == data['status'],
            orElse: () => EquipmentStatus.IN_STORAGE // Provide a default fallback
        );
      } else {
        _selectedStatus = EquipmentStatus.IN_STORAGE; // Default if null
      }

      // --- FIX: Update orElse logic for dropdowns ---
      final userData = data['assignedUser'] as Map<String, dynamic>?;
      final userId = userData?['id'] as int?;
      if (userId != null) {
        try {
          _selectedUser = _users.firstWhere((u) => u.id == userId);
        } catch (e) {
          print("Warning: Initial user ID $userId not found in fetched list _users.");
          _selectedUser = null; // Explicitly set to null if not found
        }
      } else {
        _selectedUser = null;
      }

      final projectData = data['project'] as Map<String, dynamic>?;
      final projectId = projectData?['id'] as int?;
      if (projectId != null) {
        try {
          _selectedProject = _projects.firstWhere((p) => p.id == projectId);
        } catch (e) {
          print("Warning: Initial project ID $projectId not found in fetched list _projects.");
          _selectedProject = null; // Explicitly set to null if not found
        }
      } else {
        _selectedProject = null;
      }
      // --- END FIX ---

    } catch (e) { print("Error parsing initial equipment data: $e"); }
  }

  Future<void> _submitEquipment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStatus == null) {
      setState(() => _errorMessage = 'Please select a status.'); return;
    }

    // Define actionVerb before try
    final String actionVerb = widget.isEditing ? 'updating' : 'adding';
    final String successVerb = widget.isEditing ? 'updated' : 'added';

    setState(() { _isLoading = true; _errorMessage = null; });

    Map<String, dynamic> equipmentData = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'serialNumber': _serialController.text.trim().isEmpty ? null : _serialController.text.trim(),
      'purchaseDate': _purchaseDate != null ? _dateFormatter.format(_purchaseDate!) : null,
      'status': _selectedStatus!.name,
      'minimumStockLevel': int.tryParse(_minStockController.text.trim()) ?? 0,
      'assignedUserId': _selectedUser?.id,
      'projectId': _selectedProject?.id,
    };

    try {
      Response response;
      if (widget.isEditing) {
        final equipmentId = widget.initialEquipmentData!['id'];
        print('Updating equipment ID: $equipmentId with data: $equipmentData');
        response = await _dio.put('/api/equipment/$equipmentId', data: equipmentData);
      } else {
        print('Adding new equipment with data: $equipmentData');
        response = await _dio.post('/api/equipment', data: equipmentData);
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Equipment $successVerb successfully!'), backgroundColor: Colors.green) );
        Navigator.pop(context, true);
      } else {
        _handleApiError(response, 'Failed to $actionVerb equipment');
      }
    } catch (e) {
      if (!mounted) return;
      // Use actionVerb here
      _handleGenericError(e, '$actionVerb equipment');
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  // --- Error Handling Helpers ---
  void _handleApiError(Response? response, String defaultMessage) {
    if (!mounted) return;
    String errorMsg = defaultMessage;
    if (response?.data is Map && response!.data.containsKey('error')) { errorMsg = response.data['error']; }
    else if (response?.statusMessage != null && response!.statusMessage!.isNotEmpty) { errorMsg = response.statusMessage!; }
    else if (response?.data != null){ errorMsg = response!.data.toString();}
    setState(() { _errorMessage = '$errorMsg (Status: ${response?.statusCode ?? 'N/A'})'; });
    print('$defaultMessage: ${response?.statusCode}, Response: ${response?.data}');
  }
  void _handleGenericError(Object e, String action) {
    if (!mounted) return;
    String errorMsg = 'Error $action';
    // --- FIX: Ensure DioException usage here ---
    if (e is DioException) {
      errorMsg = _formatDioExceptionMessage(e); // Use helper
    } else { errorMsg = 'An unexpected error occurred: ${e.toString()}'; print('Non-Dio Error type: ${e.runtimeType}'); }
    // --- END FIX ---
    setState(() { _errorMessage = errorMsg; });
    print('Error during "$action": $e');
  }
  // --- FIX: Ensure this helper uses DioException ---
  String _formatDioExceptionMessage(DioException e) {
    String errorMsg;
    if (e.response != null && e.response?.data is Map) {
      final responseData = e.response!.data as Map<String, dynamic>;
      errorMsg = responseData['error'] ?? responseData['message'] ?? 'Server Error (${e.response?.statusCode})';
    } else if (e.response != null) {
      errorMsg = 'Server Error: ${e.response?.statusCode} ${e.response?.statusMessage ?? ''}'.trim();
    } else {
      switch(e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout: errorMsg = 'Network timeout.'; break;
        case DioExceptionType.connectionError: errorMsg = 'Network Error: Could not connect.'; break;
        case DioExceptionType.cancel: errorMsg = 'Request cancelled.'; break;
        case DioExceptionType.badCertificate: errorMsg = 'Invalid server certificate.'; break;
        case DioExceptionType.badResponse: errorMsg = 'Invalid response from server (${e.response?.statusCode}).'; break;
        case DioExceptionType.unknown: default: errorMsg = 'Network Error: Unknown issue.'; break;
      }
    }
    return errorMsg;
  }
  // --- END FIX ---

  // --- Date Picker Logic ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime initial = _purchaseDate ?? DateTime.now();
    final DateTime first = DateTime(2000); final DateTime last = DateTime(2100);
    final DateTime? picked = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (picked != null && picked != _purchaseDate && mounted) { setState(() { _purchaseDate = picked; }); }
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = widget.isEditing ? 'Edit Equipment' : 'Add New Equipment';
    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle), backgroundColor: Colors.brown),
      body: _isFetchingDropdowns
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(controller: _nameController, decoration: InputDecoration(labelText: 'Equipment Name *', border: OutlineInputBorder()), validator:(v)=> v==null||v.isEmpty?'Required':null),
              SizedBox(height: 12),
              TextFormField(controller: _descriptionController, decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder()), maxLines: 3),
              SizedBox(height: 12),
              TextFormField(controller: _serialController, decoration: InputDecoration(labelText: 'Serial Number (Optional)', border: OutlineInputBorder())),
              SizedBox(height: 12),
              Row(children: [ Expanded(child: InputDecorator(decoration: InputDecoration(labelText: 'Purchase Date', border: OutlineInputBorder()), child: Text(_purchaseDate != null ? _dateFormatter.format(_purchaseDate!) : 'Select Date'))), IconButton(icon: Icon(Icons.calendar_month), onPressed:()=> _selectDate(context))]),
              SizedBox(height: 12),
              DropdownButtonFormField<EquipmentStatus>(value: _selectedStatus, items: EquipmentStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(), onChanged: (v){setState(()=>_selectedStatus=v);}, decoration: InputDecoration(labelText: 'Status *', border: OutlineInputBorder()), validator:(v)=>v==null?'Required':null),
              SizedBox(height: 12),
              TextFormField(controller: _minStockController, decoration: InputDecoration(labelText: 'Minimum Stock Level *', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator:(v)=> v==null||v.isEmpty||int.tryParse(v)==null||int.parse(v)<0 ?'Required positive integer':null),
              SizedBox(height: 12),
              // --- Optional Assignment Dropdowns ---
              Text("Assign (Optional)", style: Theme.of(context).textTheme.titleSmall),
              SizedBox(height: 8),
              // --- FIX Dropdown User items ---
              DropdownButtonFormField<DropdownItem?>( // Allow null value
                  value: _selectedUser,
                  items: [
                    // Explicitly add the "Unassigned" option with null value
                    const DropdownMenuItem<DropdownItem?>(value: null, child: Text("-- Unassigned --")),
                    // Map the rest of the users
                    ..._users.map((DropdownItem u) => DropdownMenuItem<DropdownItem?>(value: u, child: Text(u.name, overflow: TextOverflow.ellipsis)))
                  ],
                  onChanged: _isFetchingDropdowns ? null : (v){setState(()=>_selectedUser=v);},
                  decoration: InputDecoration(labelText: 'Assign to User', border: OutlineInputBorder(), hintText: _users.isEmpty && !_isFetchingDropdowns ? 'No users found' : null),
                  isExpanded: true,
                  disabledHint: const Text("Loading Users...")
              ),
              // --- END FIX ---
              SizedBox(height: 12),
              // --- FIX Dropdown Project items ---
              DropdownButtonFormField<DropdownItem?>( // Allow null value
                  value: _selectedProject,
                  items: [
                    // Explicitly add the "No Project" option with null value
                    const DropdownMenuItem<DropdownItem?>(value: null, child: Text("-- No Project --")),
                    // Map the rest of the projects
                    ..._projects.map((DropdownItem p) => DropdownMenuItem<DropdownItem?>(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)))
                  ],
                  onChanged: _isFetchingDropdowns ? null : (v){setState(()=>_selectedProject=v);},
                  decoration: InputDecoration(labelText: 'Assign to Project', border: OutlineInputBorder(), hintText: _projects.isEmpty && !_isFetchingDropdowns ? 'No projects found' : null),
                  isExpanded: true,
                  disabledHint: const Text("Loading Projects...")
              ),
              // --- END FIX ---
              // --- Remove Initial Stock Controller ---
              SizedBox(height: 24),
              if (_errorMessage != null) Padding( padding: const EdgeInsets.only(bottom: 16.0), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center,) ),
              ElevatedButton( onPressed: _isLoading ? null : _submitEquipment, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.brown), child: _isLoading ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.isEditing ? 'Save Changes' : 'Add Equipment')),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Ensure EquipmentStatus Enum is Defined ---
// enum EquipmentStatus { NEW, ASSIGNED, IN_STORAGE, UNDER_MAINTENANCE, BROKEN, DISPOSED }