import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/config/dio_client.dart'; // Use your centralized Dio client
import 'package:sib_expense_app/screens/add_edit_project_screen.dart'; // Screen for Add/Edit
import 'package:intl/intl.dart';
import 'package:sib_expense_app/screens/project_detail_screen.dart'; // For date formatting

// Define ProjectStatus enum locally or import from your models file
// Ensure these values EXACTLY match the strings returned by your backend API
enum ProjectStatus { PLANNING, ACTIVE, ON_HOLD, COMPLETED }

class ProjectListScreen extends StatefulWidget {
  final String token;

  const ProjectListScreen({Key? key, required this.token}) : super(key: key);

  @override
  _ProjectListScreenState createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  List<Map<String, dynamic>> _projects = []; // List of project maps
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = '';
  int? _userId; // Logged-in user's ID
  String _searchQuery = ''; // State for search query

  final Dio _dio = createDioClient(); // Use the centralized Dio client

  @override
  void initState() {
    super.initState();
    _fetchUserRoleAndData(); // Fetch role first, then data
  }
  void _confirmDelete(BuildContext context, int projectId) { // Needs context
    showDialog<bool>( // Add type argument
      context: context,
      builder: (BuildContext dialogContext) { // Use different context name
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this project? This may affect related tasks and assignments.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false), // Use dialog context
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Pop with true to confirm
              },
            ),
          ],
        );
      },
    ).then((confirmed) { // Handle the result of the dialog
      if (confirmed == true) {
        _deleteProject(projectId); // Call delete only if confirmed
      }
    });
  }
  Future<void> _fetchUserRoleAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    _userId = prefs.getInt('user_id');
    if (!mounted) return;
    if (_userRole.isEmpty || _userId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "User role or ID not found. Please login again.";
      });
      // Optionally navigate back to login here
      return;
    }
    await _fetchProjects(); // Fetch data after getting role
  }

  Future<void> _fetchProjects() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Determine the correct API endpoint based on the user's role
    // **VERIFY THESE ENDPOINTS WITH YOUR BACKEND**
    String endpoint = (_userRole == 'ADMIN' || _userRole == 'MANAGER')
        ? '/api/projects/all'        // Endpoint for admins/managers to get all projects
        : '/api/projects/my';       // Endpoint for employees to get their assigned projects

    // Optional: Add search query parameter if backend supports it
    Map<String, dynamic> queryParams = {};
    if (_searchQuery.isNotEmpty) {
      queryParams['search'] = _searchQuery; // Example parameter name
    }


    try {
      print('Fetching projects from: $endpoint with query: $_searchQuery');
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null, // Add query params if searching
      );

      if (!mounted) return;

      if (response.statusCode == 200 && response.data is List) {
        setState(() {
          // Store the fetched list of project maps
          _projects = List<Map<String, dynamic>>.from(response.data);
          _isLoading = false;
        });
      } else {
        // Handle API errors (non-200 status code)
        _handleApiError(response, 'Failed to load projects');
        setState(() { _isLoading = false; }); // Ensure loading stops on API error
      }
    } catch (e) {
      // Handle network/parsing errors
      if (!mounted) return;
      _handleGenericError(e, 'fetching projects');
      setState(() { _isLoading = false; }); // Ensure loading stops on generic error
    }
  }

  // --- Error Handling Helper Methods ---
  // (Ensure these methods are present and correctly implemented in this class)
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
    } else { errorMsg = 'An unexpected error occurred: ${e.toString()}'; print('Non-Dio Error type: ${e.runtimeType}'); }
    setState(() { _errorMessage = errorMsg; });
    print('Error during "$action": $e');
  }
  // --- End Error Handling ---

  // --- Date Formatter ---
  String _formatDateDisplay(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString); // Assumes ISO 8601 format (YYYY-MM-DD)
      return DateFormat('dd/MM/yyyy').format(date); // Display format
    } catch (e) { return "Invalid Date"; }
  }

  // --- Get Status Color ---
  Color _getStatusColor(String? status) {
    // Match case-insensitively with your backend enum string values
    switch (status?.toUpperCase()) {
      case 'ACTIVE': return Colors.green;
      case 'PLANNING': return Colors.blue;
      case 'ON_HOLD': return Colors.orange;
      case 'COMPLETED': return Colors.grey;
      default: return Colors.grey.shade400; // Default color
    }
  }

  // --- Delete Project Logic (including confirmation) ---
  Future<void> _deleteProject(int projectId) async {
    bool confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this project? This may affect related tasks and assignments.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    ) ?? false; // Default to false if dialog dismissed

    if (!confirmDelete || !mounted) return;

    setState(() { _isLoading = true; }); // Indicate processing

    try {
      // **VERIFY/MODIFY** Backend endpoint for deleting projects
      final response = await _dio.delete('/api/projects/$projectId');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) { // OK or No Content
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project Deleted'), backgroundColor: Colors.grey),
        );
        await _fetchProjects(); // Refresh the list after successful deletion
      } else {
        _handleApiError(response, 'Failed to delete project');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'deleting project');
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  // --- Debounce Search (Optional but recommended for better performance) ---
  // Timer? _debounce;
  //
  // @override
  // void dispose() {
  //   _debounce?.cancel();
  //   super.dispose();
  // }
  //
  // void _onSearchChanged(String query) {
  //   if (_debounce?.isActive ?? false) _debounce!.cancel();
  //   _debounce = Timer(const Duration(milliseconds: 500), () {
  //     if (!mounted) return;
  //     setState(() {
  //       _searchQuery = query;
  //     });
  //     _fetchProjects(); // Refetch with the new query
  //   });
  // }
  // --- End Debounce Search ---


  @override
  Widget build(BuildContext context) {
    // Determine permissions based on role
    bool canManageProjects = (_userRole == 'ADMIN' || _userRole == 'MANAGER');
    bool canAddProject = canManageProjects; // Or specific 'project.create' permission check

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        backgroundColor: Colors.indigo, // Consistent color
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search Projects...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                  isDense: true, // Make it slightly more compact
                ),
                onChanged: (value) {
                  // **IMPLEMENT SEARCH:**
                  // Option 1 (Client-side filter - simpler for small lists):
                  // setState(() { _searchQuery = value; });
                  // Then filter _projects in the ListView.builder based on _searchQuery

                  // Option 2 (Server-side search - better for large lists):
                  // _onSearchChanged(value); // Use debounce function
                  setState(() { _searchQuery = value; }); // Simple version without debounce
                  _fetchProjects(); // Trigger API call immediately (can be inefficient)
                },
              ),
            ),
            const SizedBox(height: 8),
            // List View Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center)
                  )
              )
                  : _projects.isEmpty
                  ? Center(child: Text(_searchQuery.isEmpty ? 'No projects found.' : 'No projects match your search.'))
                  : RefreshIndicator(
                onRefresh: _fetchProjects,
                child: ListView.builder(
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    final clientMap = project['client'] as Map<String, dynamic>?;
                    final status = project['status'] as String?;
                    final projectId = project['id'] as int?;

                    if (projectId == null) return const SizedBox.shrink();

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: Tooltip( // Add tooltip to status icon
                          message: status ?? 'Unknown Status',
                          child: CircleAvatar(
                            backgroundColor: _getStatusColor(status),
                            radius: 18, // Slightly smaller
                            child: Text(status?.substring(0,1).toUpperCase() ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        title: Text(project['projectName'] ?? 'Unknown Project', style: const TextStyle(fontWeight: FontWeight.w500)), // Slightly less bold
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if(project['projectCode'] != null) Text('Code: ${project['projectCode']}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            Text('Client: ${clientMap?['companyName'] ?? 'Internal'}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            Text('Dates: ${_formatDateDisplay(project['startDate'] as String?)} - ${_formatDateDisplay(project['endDate'] as String?)}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          ],
                        ),
                        trailing: canManageProjects ? PopupMenuButton<String>( // Use PopupMenu for actions
                          icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                          tooltip: "Actions",
                          onSelected: (String choice) {
                            if (choice == 'Edit') {
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (context) => AddEditProjectScreen(
                                    token: widget.token,
                                    initialProjectData: project,
                                  )
                              )).then((success) { if(success == true) _fetchProjects(); });
                            } else if (choice == 'Delete') {
                              _confirmDelete(context, projectId); // Call confirmation dialog
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return {'Edit', 'Delete'}.map((String choice) {
                              return PopupMenuItem<String>(
                                value: choice,
                                child: Text(choice),
                              );
                            }).toList();
                          },
                        ) : null, // No actions for non-managers
                        onTap: () {
                          print("Navigating to details for Project ID: $projectId");
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProjectDetailScreen(
                                token: widget.token,
                                projectId: projectId,
                              ),
                            ),
                          ).then((_) => _fetchProjects()); // Refresh on return
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
      floatingActionButton: canAddProject
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(
              builder: (context) => AddEditProjectScreen(token: widget.token) // Navigate to Add Screen
          )).then((success) { if(success == true) _fetchProjects(); }); // Refresh on return
        },
        child: const Icon(Icons.add),
        tooltip: 'Add Project',
        backgroundColor: Colors.indigo, // Match AppBar
      )
          : null,
    );
  }
}