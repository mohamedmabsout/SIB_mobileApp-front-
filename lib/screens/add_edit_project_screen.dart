import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:sib_expense_app/models/dropdown_item.dart';
// Define or import ProjectStatus enum
// Ensure this matches backend enum names exactly
enum ProjectStatus { PLANNING, ACTIVE, ON_HOLD, COMPLETED }


class AddEditProjectScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? initialProjectData; // Null for Add, data for Edit

  const AddEditProjectScreen({
    Key? key,
    required this.token,
    this.initialProjectData,
  }) : super(key: key);

  // Helper to check if we are editing
  bool get isEditing => initialProjectData != null;

  @override
  State<AddEditProjectScreen> createState() => _AddEditProjectScreenState();
}

class _AddEditProjectScreenState extends State<AddEditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  // Text Editing Controllers
  final _projectNameController = TextEditingController();
  final _projectCodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  // final _clientIdController = TextEditingController(); // Using Dropdown instead

  // State variables
  DateTime? _startDate;
  DateTime? _endDate;
  ProjectStatus? _selectedStatus;
  DropdownItem? _selectedClient; // Holds selected client {id, name}

  List<DropdownItem> _clients = []; // List of clients for dropdown
  bool _isLoading = false; // General loading/saving state
  bool _isFetchingDropdownData = true; // Specific state for initial data load
  String? _errorMessage;

  final Dio _dio = createDioClient(); // Use centralized Dio client
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd'); // Date formatter

  @override
  void initState() {
    super.initState();
    // Fetch client list first, then populate form if editing
    _fetchDropdownData();
  }

  @override
  void dispose() {
    // Dispose all controllers
    _projectNameController.dispose();
    _projectCodeController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    // _clientIdController.dispose(); // No longer needed if dropdown is used
    super.dispose();
  }

  // Fetch necessary data for dropdowns (only clients in this case)
  Future<void> _fetchDropdownData() async {
    if (!mounted) return;
    // Start loading state for dropdowns specifically
    setState(() { _isFetchingDropdownData = true; _errorMessage = null; });

    try {
      // Fetch clients
      // **MODIFY:** Use your actual endpoint for a simplified client list (ID, Name)
      final clientResponse = await _dio.get('/api/admin/all-clients');

      if (!mounted) return;

      if (clientResponse.statusCode == 200 && clientResponse.data is List) {
        _clients = (clientResponse.data as List).map((clientJson) {
          return DropdownItem(
            // Adjust keys based on your backend response
              id: clientJson['id'] as int? ?? 0,
              name: clientJson['companyName'] as String? ?? 'Unknown Client'
          );
        }).toList();
      } else {
        // Handle client fetch error - maybe allow proceeding without client selection?
        print('Failed to load clients: ${clientResponse.statusCode}');
        setState(() { _errorMessage = 'Could not load client list.'; });
      }

      // If editing, populate form AFTER clients are potentially loaded
      if (widget.isEditing && widget.initialProjectData != null) {
        _populateForm(widget.initialProjectData!);
      }

    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'loading initial data');
    } finally {
      // Mark dropdown loading complete, general loading depends if editing
      if (mounted) {
        setState(() {
          _isFetchingDropdownData = false;
          _isLoading = false; // Initial data load complete (or failed)
        });
      }
    }
  }

  // Populate form fields from initial data (when editing)
  void _populateForm(Map<String, dynamic> data) {
    _projectNameController.text = data['projectName'] ?? '';
    _projectCodeController.text = data['projectCode'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _budgetController.text = (data['budget'] as num?)?.toString() ?? '';

    try {
      _startDate = data['startDate'] != null ? DateTime.tryParse(data['startDate']) : null;
      _endDate = data['endDate'] != null ? DateTime.tryParse(data['endDate']) : null;
      // Set selected status enum
      if (data['status'] != null && data['status'] is String) {
        _selectedStatus = ProjectStatus.values.firstWhere(
                (e) => e.name == data['status'],
            orElse: () => ProjectStatus.PLANNING // Default if parsing fails
        );
      } else {
        _selectedStatus = ProjectStatus.PLANNING; // Default if null
      }

      // Set selected client based on ID from the fetched list
      final clientData = data['client'] as Map<String, dynamic>?;
      final clientId = clientData?['id'] as int?; // Safely get client ID
      if (clientId != null) {
        try {
          _selectedClient = _clients.firstWhere((c) => c.id == clientId);
        } catch (e) {
          print("Warning: Initial client ID $clientId not found in fetched list.");
          // Optionally add it if needed, or show an error, or leave null
          // _clients.add(DropdownItem(id: clientId, name: clientData?['companyName'] ?? 'Unknown (ID: $clientId)'));
          // _selectedClient = _clients.last;
        }
      } else {
        _selectedClient = null;
      }

    } catch (e) {
      print("Error parsing initial project data for form: $e");
      // Set error message state if needed
      // setState(() => _errorMessage = "Error loading project details.");
    }
    // No need for setState here if called within setState in _fetchInitialData
  }

  // --- Submit Project Data (Create or Update) ---
  Future<void> _submitProject() async {
    // Validate the form first
    if (!_formKey.currentState!.validate()) return;
    // Add validation for required dropdowns
    if (_selectedStatus == null) {
      setState(() => _errorMessage = "Please select a status."); return;
    }
    if (_selectedClient == null) {
      setState(() => _errorMessage = "Please select a client."); return;
    }

    setState(() { _isLoading = true; _errorMessage = null; }); // Use general loading flag

    // Prepare data map matching backend DTO
    Map<String, dynamic> projectData = {
      'projectName': _projectNameController.text.trim(),
      'projectCode': _projectCodeController.text.trim().isEmpty ? null : _projectCodeController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'budget': double.tryParse(_budgetController.text.trim()),
      'startDate': _startDate != null ? _dateFormatter.format(_startDate!) : null,
      'endDate': _endDate != null ? _dateFormatter.format(_endDate!) : null,
      'status': _selectedStatus!.name, // Send enum name
      'clientId': _selectedClient!.id, // Send SELECTED Client ID
      // Alternatively, send nested client object if backend expects it:
      // 'client': _selectedClient != null ? {'id': _selectedClient!.id } : null,
    };

    try {
      Response response;
      if (widget.isEditing) {
        final projectId = widget.initialProjectData!['id'];
        print('Updating project ID: $projectId with data: $projectData');
        // **VERIFY/MODIFY** endpoint and ensure backend accepts all fields for update
        response = await _dio.put('/api/projects/$projectId', data: projectData);
      } else {
        print('Adding new project with data: $projectData');
        // **VERIFY/MODIFY** endpoint
        response = await _dio.post('/api/projects', data: projectData);
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Project ${widget.isEditing ? 'updated' : 'added'} successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Pop back and signal success
      } else {
        _handleApiError(response, 'Failed to ${widget.isEditing ? 'update' : 'add'} project');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, '${widget.isEditing ? 'updating' : 'adding'} project');
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
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    // ... (Implementation from previous answer) ...
    final DateTime initial = isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now());
    final DateTime first = DateTime(2000); final DateTime last = DateTime(2100);
    final DateTime? picked = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (picked != null && mounted) { setState(() { if (isStartDate) { _startDate = picked; if (_endDate != null && _endDate!.isBefore(_startDate!)) { _endDate = _startDate; } } else { _endDate = picked; if (_startDate != null && _endDate!.isBefore(_startDate!)) { _startDate = _endDate; } } }); }
  }


  @override
  Widget build(BuildContext context) {
    String appBarTitle = widget.isEditing ? 'Edit Project' : 'Add New Project';

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle), backgroundColor: Colors.indigo),
      body: _isFetchingDropdownData // Show main loading indicator while fetching dropdowns
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _projectNameController,
                decoration: const InputDecoration(labelText: 'Project Name *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Project name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _projectCodeController,
                decoration: const InputDecoration(labelText: 'Project Code (Optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(labelText: 'Budget (Optional)', prefixText: '\$ ', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              // --- UPDATED CLIENT DROPDOWN ---
              DropdownButtonFormField<DropdownItem>(
                value: _selectedClient,
                items: _clients.isEmpty // Handle empty list after loading
                    ? [ const DropdownMenuItem(enabled: false, child: Text("No clients found")) ]
                    : _clients.map((DropdownItem client) {
                  return DropdownMenuItem<DropdownItem>(
                    value: client,
                    child: Text(client.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (DropdownItem? newValue) {
                  setState(() { _selectedClient = newValue; });
                },
                decoration:  InputDecoration(
                  labelText: 'Client *',
                  border: OutlineInputBorder(),
                  // Display hint only if list is empty AND not loading
                  hintText: _clients.isEmpty ? 'Could not load clients' : null,
                ),
                validator: (value) => value == null ? 'Please select a client' : null,
                isExpanded: true,
                disabledHint: const Text("Loading Clients..."), // Hint while loading
              ),
              // --- END CLIENT DROPDOWN ---
              const SizedBox(height: 12),
              // Status Dropdown
              DropdownButtonFormField<ProjectStatus>(
                value: _selectedStatus,
                items: ProjectStatus.values.map((ProjectStatus status) {
                  return DropdownMenuItem<ProjectStatus>(
                    value: status,
                    // Optional: Make names more user-friendly if needed
                    child: Text(status.name.replaceAll('_', ' ')),
                  );
                }).toList(),
                onChanged: (ProjectStatus? newValue) { setState(() { _selectedStatus = newValue; }); },
                decoration: const InputDecoration(labelText: 'Status *', border: OutlineInputBorder()),
                validator: (value) => value == null ? 'Please select a status' : null,
              ),
              const SizedBox(height: 12),
              // Date Pickers Row
              Row(
                children: [
                  Expanded(
                    child: InkWell( // Use InkWell + InputDecorator for tappable field look
                      onTap: () => _selectDate(context, true),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start Date *',
                          border: const OutlineInputBorder(),
                          // Show error from FormField if needed later
                        ),
                        child: Text(
                          _startDate != null ? _dateFormatter.format(_startDate!) : 'Select Date',
                          style: TextStyle(color: _startDate == null ? Colors.grey[600] : null),
                        ),
                      ),
                    ),
                  ),
                  IconButton( // Separate button for clarity
                    icon: const Icon(Icons.calendar_month, color: Colors.indigo),
                    tooltip: "Select Start Date",
                    onPressed: () => _selectDate(context, true),
                  ),
                  const SizedBox(width: 4), // Reduced space
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Date (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _endDate != null ? _dateFormatter.format(_endDate!) : 'Select Date',
                          style: TextStyle(color: _endDate == null ? Colors.grey[600] : null),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_month, color: Colors.indigo),
                    tooltip: "Select End Date",
                    onPressed: () => _selectDate(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitProject,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo, // Match AppBar
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading // General loading/saving state
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.isEditing ? 'Save Changes' : 'Add Project'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Ensure ProjectStatus Enum is Defined ---
// enum ProjectStatus { PLANNING, ACTIVE, ON_HOLD, COMPLETED }