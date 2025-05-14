import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:intl/intl.dart';
import 'package:sib_expense_app/screens/add_edit_assignment_screen.dart';
import 'package:sib_expense_app/screens/assignment_detail_screen.dart';
// Import screen for adding a new assignment (You'll need to create this)
// import 'package:sib_expense_app/screens/add_assignment_screen.dart';

class AssignmentListScreen extends StatefulWidget {
  final String token;
  // Optional: Pass projectId if needed
  // final int? projectId;

  const AssignmentListScreen({Key? key, required this.token /*, this.projectId */}) : super(key: key);

  @override
  _AssignmentListScreenState createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  List<Map<String, dynamic>> _assignments = []; // List of Maps
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = '';
  int? _userId;

  final Dio _dio = createDioClient();

  @override
  void initState() {
    super.initState();
    _fetchUserRoleAndData();
  }

  Future<void> _fetchUserRoleAndData() async {
    // ... (Same implementation as before) ...
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    _userId = prefs.getInt('user_id');
    if (_userRole.isEmpty || _userId == null) {
      setState(() { _isLoading = false; _errorMessage = "User info missing."; }); return;
    }
    await _fetchAssignments();
  }


  Future<void> _fetchAssignments() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    // **VERIFY/MODIFY Back-End Endpoint Paths**
    String endpoint;
    // Example: Adjust based on filtering needs
    // if (widget.projectId != null) {
    //    endpoint = '/api/projects/${widget.projectId}/assignments';
    // } else
    if (_userRole == 'ADMIN' || _userRole == 'MANAGER') {
      endpoint = '/api/assignments/all'; // Assumed endpoint
    } else {
      endpoint = 'api/assignments/$_userId'; // Assumed endpoint
    }

    try {
      print('Fetching assignments from: $endpoint');
      final response = await _dio.get(endpoint);

      if (!mounted) return;

      if (response.statusCode == 200 && response.data is List) {
        setState(() {
          _assignments = List<Map<String, dynamic>>.from(response.data);
        });
      } else {
        _handleApiError(response, 'Failed to load assignments');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'fetching assignments');
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

  // --- Date Formatter ---
  String _formatDateDisplay(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) { return "Invalid Date"; }
  }
  // --- Get Status Color ---
  Color _getAssignmentStatusColor(String? status) {
    // **MODIFY** based on your actual AssignmentStatus enum values
    switch (status?.toUpperCase()) {
      case 'ACTIVE': return Colors.blue;
      case 'COMPLETED': return Colors.green;
      case 'PENDING': return Colors.grey;
      case 'BLOCKED': return Colors.red;
      case 'AWAITING_VALIDATION': return Colors.orange;
      default: return Colors.grey.shade400;
    }
  }


  @override
  Widget build(BuildContext context) {
    bool canAddAssignment = (_userRole == 'ADMIN' || _userRole == 'MANAGER');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        backgroundColor: Colors.purple, // Example color
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // TODO: Add Search/Filter Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search Assignments...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
              onChanged: (value) { /* TODO: Implement Search */ },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(/* Error Message */)
                  : _assignments.isEmpty
                  ? const Center(child: Text('No assignments found.'))
                  : RefreshIndicator(
                onRefresh: _fetchAssignments,
                child: ListView.builder(
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) {
                    final assignment = _assignments[index]; // assignment is Map<String, dynamic>
                    final projectMap = assignment['project'] as Map<String, dynamic>?;
                    final userMap = assignment['user'] as Map<String, dynamic>?;
                    final assignmentId = assignment['id'] as int; // Correct declaration

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: const Icon(Icons.assignment_ind_outlined, color: Colors.purple),
                        title: Text('Project: ${assignment['projectName'] ?? 'N/A'}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Assigned To: ${assignment['username'] ?? 'N/A'}'),
                            Text('Role/Desc: ${assignment['description'] ?? 'N/A'}'),
                            Text('Dates: ${_formatDateDisplay(assignment['startDate'] as String?)} - ${_formatDateDisplay(assignment['endDate'] as String?)}'),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(assignment['status'] ?? 'N/A', style: TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: _getAssignmentStatusColor(assignment['status'] as String?),
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AssignmentDetailScreen(
                                token: widget.token, assignmentId: assignmentId,),
                            ),
                          ).then((_) { _fetchAssignments();
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: canAddAssignment
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditAssignmentScreen(
                token: widget.token),
            ),
          ).then((_) { _fetchAssignments();
          });
        },
        child: const Icon(Icons.person_add_alt_1),
        tooltip: 'Assign User to Project',
        backgroundColor: Colors.purple,
      )
          : null,
    );
  }
}