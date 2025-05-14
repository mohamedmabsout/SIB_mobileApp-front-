import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:intl/intl.dart';
import 'package:sib_expense_app/screens/add_task_screen.dart';
import 'package:sib_expense_app/screens/task_detail_screen.dart';
// Import screen for adding a new task (You'll need to create this)
// import 'package:sib_expense_app/screens/add_task_screen.dart';

class TaskListScreen extends StatefulWidget {
  final String token;
  // Optional: Pass projectId if showing tasks for a specific project
  // final int? projectId;

  const TaskListScreen({Key? key, required this.token /*, this.projectId */}) : super(key: key);

  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Map<String, dynamic>> _tasks = []; // List of Maps
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
    // ... (Same implementation as in ProjectListScreen) ...
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    _userId = prefs.getInt('user_id');
    if (_userRole.isEmpty || _userId == null) {
      setState(() { _isLoading = false; _errorMessage = "User info missing."; }); return;
    }
    await _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    // **VERIFY/MODIFY Back-End Endpoint Paths**
    String endpoint;
    // Example: Adjust based on whether filtering by project or role
    // if (widget.projectId != null) {
    //    endpoint = '/api/projects/${widget.projectId}/tasks';
    // } else
    if (_userRole == 'ADMIN' || _userRole == 'MANAGER') {
      endpoint = '/api/admin/all-tasks'; // Assumed endpoint for admin/manager
    } else {
      endpoint = '/api/tasks/my'; // Assumed endpoint for employee's tasks
    }

    try {
      print('Fetching tasks from: $endpoint');
      final response = await _dio.get(endpoint);

      if (!mounted) return;

      if (response.statusCode == 200 && response.data is List) {
        setState(() {
          // Directly store the list of maps
          _tasks = List<Map<String, dynamic>>.from(response.data);
        });
      } else {
        _handleApiError(response, 'Failed to load tasks');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'fetching tasks');
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
  // --- Get Status/Priority Color/Icon Helpers ---
  Color _getTaskStatusColor(String? status) {
    // **MODIFY** based on your actual TaskStatus enum values
    switch (status?.toUpperCase()) {
      case 'OPEN': return Colors.blue;
      case 'IN_PROGRESS': return Colors.orange;
      case 'COMPLETED': return Colors.green;
      case 'BLOCKED': return Colors.red;
      default: return Colors.grey;
    }
  }
  IconData _getPriorityIcon(String? priority) {
    // **MODIFY** based on your actual Priority enum values
    switch (priority?.toUpperCase()) {
      case 'HIGH': return Icons.priority_high_rounded;
      case 'MEDIUM': return Icons.remove_rounded;
      case 'LOW': return Icons.low_priority_rounded;
      default: return Icons.horizontal_rule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canAddTask = (_userRole == 'ADMIN' || _userRole == 'MANAGER'); // Example permission

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        backgroundColor: Colors.orange, // Example color
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // TODO: Add Search/Filter Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search Tasks...',
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
                  : _tasks.isEmpty
                  ? const Center(child: Text('No tasks found.'))
                  : RefreshIndicator(
                onRefresh: _fetchTasks,
                child: ListView.builder(
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index]; // task is a Map<String, dynamic>
                    final projectMap = task['project'] as Map<String, dynamic>?;
                    final userMap = task['assignedToUser'] as Map<String, dynamic>?;
                    final taskId = task['id'] as int?; // Correct declaration

                    if (taskId == null) {
                      print("Warning: Skipping task with missing ID at index $index");
                      return const SizedBox.shrink(); // Skip if no ID
                    }
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: Icon(_getPriorityIcon(task['priority'] as String?), color: Colors.black54),
                        title: Text(task['taskName'] ?? 'Unnamed Task', style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if(projectMap != null) Text('Project: ${projectMap['projectName'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            if(userMap != null) Text('Assigned: ${userMap['username'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            Text('Due: ${_formatDateDisplay(task['dueDate'] as String?)}', style: TextStyle(fontSize: 12)),
                            if(task['description'] != null && task['description'].isNotEmpty)
                              Text('Desc: ${task['description']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(task['status'] ?? 'N/A', style: TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: _getTaskStatusColor(task['status'] as String?),
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TaskDetailScreen(
                                token: widget.token,
                                // Use the correctly spelled variable name 'projectId'
                                taskId: taskId, // Pass the project ID
                              ),
                            ),
                          ).then((_) { _fetchTasks();
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
      floatingActionButton: canAddTask // Add task permission check
          ? FloatingActionButton(
        onPressed: (){
          Navigator.push(context, MaterialPageRoute(
              builder: (context) => AddEditTaskScreen(
                token: widget.token
               )
          )).then((success) { // Refresh on return
            if(success == true) _fetchTasks();
          });
        },
        child: const Icon(Icons.add_task), // Different Icon
        tooltip: 'Add Task',
        backgroundColor: Colors.orange,
      )
          : null,
    );
  }
}