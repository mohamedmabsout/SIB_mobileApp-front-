import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:sib_expense_app/models/dropdown_item.dart';

// Define or Import AssignmentStatus Enum
enum AssignmentStatus { PENDING, ACTIVE, BLOCKED, AWAITING_VALIDATION, COMPLETED }


class AddEditAssignmentScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? initialAssignmentData; // Null for Add

  const AddEditAssignmentScreen({
    Key? key,
    required this.token,
    this.initialAssignmentData,
  }) : super(key: key);

  bool get isEditing => initialAssignmentData != null;

  @override
  _AddEditAssignmentScreenState createState() => _AddEditAssignmentScreenState();
}

class _AddEditAssignmentScreenState extends State<AddEditAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers
  final _descriptionController = TextEditingController();
  // State for Dropdowns
  DropdownItem? _selectedUser;
  DropdownItem? _selectedProject;
  AssignmentStatus? _selectedStatus; // Only relevant for editing generally
  DateTime? _startDate;
  DateTime? _endDate;

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
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    // ... (Implementation remains the same - fetch users & projects) ...
    if (!mounted) return;
    setState(() { _isFetchingDropdowns = true; _errorMessage = null; });
    try { /* ... Fetch users and projects ... */
      final results = await Future.wait([
        _dio.get('/api/admin/users/list-simple'),
        _dio.get('/api/projects/list-simple'),
      ]);
      if (!mounted) return;
      if (results[0].statusCode == 200 && results[0].data is List) {
        _users = (results[0].data as List).map((u) => DropdownItem(id: u['id'], name: u['name'] ?? 'Unknown')).toList();
      } else { throw Exception('Failed to load users'); }
      if (results[1].statusCode == 200 && results[1].data is List) {
        _projects = (results[1].data as List).map((p) => DropdownItem(id: p['id'], name: p['name'] ?? 'Unknown')).toList();
      } else { throw Exception('Failed to load projects'); }
      if (widget.isEditing && widget.initialAssignmentData != null) { _populateForm(widget.initialAssignmentData!); }
      setState(() { _isFetchingDropdowns = false; _isLoading = false; });
    } catch (e) { if (!mounted) return; _handleGenericError(e, 'loading dropdown data'); setState(() { _isFetchingDropdowns = false; _isLoading = false; }); }
  }

  void _populateForm(Map<String, dynamic> data) {
    // ... (Implementation remains the same - populate controllers and state) ...
    _descriptionController.text = data['description'] ?? '';
    try {
      _startDate = data['startDate'] != null ? DateTime.tryParse(data['startDate']) : null;
      _endDate = data['endDate'] != null ? DateTime.tryParse(data['endDate']) : null;
      if (data['status'] != null) { _selectedStatus = AssignmentStatus.values.firstWhere((e) => e.name == data['status'], orElse: () => AssignmentStatus.PENDING); }
      final projectData = data['project'] as Map<String, dynamic>?;
      final projectId = projectData?['id'] as int?;
      if (projectId != null) {
        try { _selectedProject = _projects.firstWhere((p) => p.id == projectId); }
        catch (e) { print("Warning: Initial project ID $projectId not found."); _selectedProject = null;}
      } else { _selectedProject = null; }

      final userData = data['user'] as Map<String, dynamic>?;
      final userId = userData?['id'] as int?;
      if (userId != null) {
        try { _selectedUser = _users.firstWhere((u) => u.id == userId); }
        catch (e) { print("Warning: Initial user ID $userId not found."); _selectedUser = null; }
      } else { _selectedUser = null; }} catch(e) { print("Error parsing initial assignment data: $e"); }
  }

  Future<void> _submitAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUser == null || _selectedProject == null || _startDate == null ) { setState(() { _errorMessage = 'User, Project, and Start Date are required.'; }); return; }
    if (widget.isEditing && _selectedStatus == null) { setState(() { _errorMessage = 'Status is required when editing.'; }); return; }

    // --- FIX: Define actionVerb BEFORE try ---
    final String actionVerb = widget.isEditing ? 'updating' : 'adding';
    final String successVerb = widget.isEditing ? 'updated' : 'created';
    // --- END FIX ---

    setState(() { _isLoading = true; _errorMessage = null; });

    Map<String, dynamic> assignmentData = {
      'userId': _selectedUser!.id,
      'projectId': _selectedProject!.id,
      'assignmentDescription': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'startDate': _dateFormatter.format(_startDate!),
      'endDate': _endDate != null ? _dateFormatter.format(_endDate!) : null,
      // Only send status for updates, backend usually sets default on create
      if (widget.isEditing) 'status': _selectedStatus!.name,
    };

    try {
      Response response;
      // String actionVerb = ... // Moved outside
      // String successVerb = ... // Moved outside

      if (widget.isEditing) {
        final assignmentId = widget.initialAssignmentData!['id'];
        print('Updating assignment ID: $assignmentId with data: $assignmentData');
        // **VERIFY/MODIFY** PUT endpoint
        response = await _dio.put('/api/assignments/$assignmentId', data: assignmentData);
      } else {
        print('Adding new assignment with data: $assignmentData');
        // **VERIFY/MODIFY** POST endpoint (e.g., /api/assignments/assign)
        response = await _dio.post('/api/assignments/assign', data: assignmentData);
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Assignment $successVerb successfully!'), backgroundColor: Colors.green) );
        Navigator.pop(context, true);
      } else {
        _handleApiError(response, 'Failed to $actionVerb assignment'); // Use actionVerb
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, '$actionVerb assignment'); // Use actionVerb
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
    if (e is DioException) {
      if (e.response != null && e.response?.data is Map && e.response?.data['error'] != null) { errorMsg = e.response?.data['error'];}
      else if (e.response != null && e.response?.data != null) { errorMsg = "Server Error (${e.response?.statusCode}): ${e.response?.data.toString().substring(0, (e.response!.data.toString().length > 100 ? 100 : e.response!.data.toString().length)) }..."; }
      else if (e.response != null) { errorMsg = 'Server Error: ${e.response?.statusCode}'; }
      else { errorMsg = 'Network Error. Please check connection.'; }
    } else { errorMsg = 'An unexpected error occurred.'; print('Non-Dio Error type: ${e.runtimeType}'); }
    setState(() { _errorMessage = errorMsg; });
    print('Error during "$action": $e');
  }
  // --- End Error Handling ---


  // --- Date Picker Logic ---
  Future<void> _selectDate(BuildContext context, bool isStartDate) async { /* ... Same ... */ }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = widget.isEditing ? 'Edit Assignment' : 'Assign User to Project';
    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle), backgroundColor: Colors.purple),
      body: Stack( // Add Stack for background
        children: [
          Image.asset( // Background Image
            'assets/dashboard_background2.jpg',
            fit: BoxFit.cover,
            width: double.infinity, height: double.infinity,
          ),
          SafeArea( // Keep SafeArea
            child: _isFetchingDropdowns
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User Dropdown
                    DropdownButtonFormField<DropdownItem?>(
                      value: _selectedUser,
                      items: [ const DropdownMenuItem<DropdownItem?>(value: null, child: Text("-- Select User --")), ..._users.map((u) => DropdownMenuItem<DropdownItem?>(value: u, child: Text(u.name))) ],
                      onChanged: widget.isEditing ? null : (v){setState(()=>_selectedUser=v);},
                      decoration: InputDecoration(labelText: 'User *', border: OutlineInputBorder(), filled: true, fillColor: Colors.white70, hintText: _users.isEmpty && !_isFetchingDropdowns ? 'No users found' : null),
                      validator: (v)=>v==null?'Required':null,
                      isExpanded: true,
                      disabledHint: Text(widget.isEditing ? (_selectedUser?.name ?? 'Select User') : "Loading Users..."),
                    ),
                    SizedBox(height: 12),
                    // Project Dropdown
                    DropdownButtonFormField<DropdownItem?>(
                      value: _selectedProject,
                      items: [ const DropdownMenuItem<DropdownItem?>(value: null, child: Text("-- Select Project --")), ..._projects.map((p) => DropdownMenuItem<DropdownItem?>(value: p, child: Text(p.name))) ],
                      onChanged: widget.isEditing ? null : (v){setState(()=>_selectedProject=v);},
                      decoration: InputDecoration(labelText: 'Project *', border: OutlineInputBorder(), filled: true, fillColor: Colors.white70, hintText: _projects.isEmpty && !_isFetchingDropdowns ? 'No projects found' : null),
                      validator: (v)=>v==null?'Required':null,
                      isExpanded: true,
                      disabledHint: Text(widget.isEditing ? (_selectedProject?.name ?? 'Select Project') : "Loading Projects..."),
                    ),
                    SizedBox(height: 12),
                    TextFormField(controller: _descriptionController, decoration: InputDecoration(labelText: 'Role/Description in Project', border: OutlineInputBorder(), filled: true, fillColor: Colors.white70), maxLines: 3),
                    SizedBox(height: 12),
                    // Start Date Picker
                    Row(children: [ Expanded(child: InputDecorator(decoration: InputDecoration(labelText: 'Start Date *', border: OutlineInputBorder(), filled: true, fillColor: Colors.white70), child: Text(_startDate != null ? _dateFormatter.format(_startDate!) : 'Select Date'))), IconButton(icon: Icon(Icons.calendar_month, color: Colors.purple), onPressed:()=> _selectDate(context, true))]),
                    SizedBox(height: 12),
                    // End Date Picker
                    Row(children: [ Expanded(child: InputDecorator(decoration: InputDecoration(labelText: 'End Date (Optional)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white70), child: Text(_endDate != null ? _dateFormatter.format(_endDate!) : 'Select Date'))), IconButton(icon: Icon(Icons.calendar_month, color: Colors.purple), onPressed:()=> _selectDate(context, false))]),
                    SizedBox(height: 12),
                    // Status Dropdown - Only show when editing
                    if(widget.isEditing)
                      DropdownButtonFormField<AssignmentStatus>(
                          value: _selectedStatus,
                          items: AssignmentStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                          onChanged: (v){setState(()=>_selectedStatus=v);},
                          decoration: InputDecoration(labelText: 'Status *', border: OutlineInputBorder(), filled: true, fillColor: Colors.white70),
                          validator:(v)=>v==null?'Required':null
                      ),
                    SizedBox(height: 24),
                    // Error Message
                    if (_errorMessage != null) Padding( padding: const EdgeInsets.only(bottom: 16.0), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center,) ),
                    // Submit Button
                    ElevatedButton( onPressed: _isLoading ? null : _submitAssignment, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.purple, foregroundColor: Colors.white), child: _isLoading ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.isEditing ? 'Save Changes' : 'Create Assignment')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}