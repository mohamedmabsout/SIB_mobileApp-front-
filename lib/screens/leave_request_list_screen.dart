import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:sib_expense_app/screens/leave_request_screen.dart'; // Screen to create new request
import 'package:sib_expense_app/config/dio_client.dart';

import 'leave_request_details_screen.dart'; // Import the helper

// Ensure this enum definition is accessible, either here or in a models file
// Match these values EXACTLY (case-sensitive) with your backend enum names
enum LeaveType { PAID, SICK_LEAVE, EXCEPTIONAL, VACATION }
enum LeaveStatus { PENDING, APPROVED, REJECTED }

class LeaveRequestListScreen extends StatefulWidget {
  final String token;

  const LeaveRequestListScreen({Key? key, required this.token}) : super(key: key);

  @override
  _LeaveRequestListScreenState createState() => _LeaveRequestListScreenState();
}

class _LeaveRequestListScreenState extends State<LeaveRequestListScreen> {
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = '';
  int? _userId;
  Set<int> _processingRequests = {}; // Track processing requests

  final Dio _dio = createDioClient(); // Get the configured Dio instance

  @override
  void initState() {
    super.initState();
    // Add interceptor for Authorization header
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Ensure Content-Type is set if not done globally in BaseOptions
        // options.headers['Content-Type'] = 'application/json';
        options.headers['Authorization'] = 'Bearer ${widget.token}';
        return handler.next(options);
      },
    ));
    _fetchUserRoleAndData();
  }

  Future<void> _fetchUserRoleAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedRole = prefs.getString('user_role');
    final int? storedUserId = prefs.getInt('user_id'); // **CRITICAL**

    if (storedRole == null || storedUserId == null) {
      if (!mounted) return; // Check if widget is still mounted
      setState(() {
        _isLoading = false;
        _errorMessage = "User role or ID not found. Please login again.";
      });
      // Consider popping back to login: Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    setState(() {
      _userRole = storedRole;
      _userId = storedUserId;
    });

    await _fetchLeaveRequests();
  }

  Future<void> _fetchLeaveRequests() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String endpoint;

    // Determine endpoint based on role
    if (_userRole == 'ADMIN' || _userRole == 'MANAGER') {
      endpoint = '/leave/all';
    } else { // EMPLOYEE
      endpoint = '/leave/user/$_userId';
    }

    try {
      print('Fetching leave requests from endpoint: $endpoint');
      final response = await _dio.get(endpoint);

      if (!mounted) return; // Check after await

      if (response.statusCode == 200) {
        // Ensure the response data is actually a List
        if (response.data is List) {
          List<Map<String, dynamic>> leaveRequests = List<Map<String, dynamic>>.from(response.data);
          for (var request in leaveRequests) {
            int userId = request['userId'];
            // Fetch user details
            final userResponse = await _dio.get('/api/users/$userId');
            if (userResponse.statusCode == 200) {
              request['user'] = userResponse.data;
            }
          }
          setState(() {
            _leaveRequests = leaveRequests;
          });
        } else {
          print('Unexpected response data format: ${response.data.runtimeType}');
          setState(() { _errorMessage = 'Received invalid data format from server.'; });
        }
      } else {
        setState(() { _errorMessage = 'Failed to load requests: ${response.statusCode}';});
        print('Failed to load leave requests: ${response.statusCode}');
      }
    } on DioError catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'fetching requests'); // Use helper
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = 'An unexpected error occurred: $e'; });
      print('Fetch Leave Requests Error: $e');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // --- Approve Leave Request ---
  Future<void> _approveRequest(int requestId) async {
    if (_processingRequests.contains(requestId)) return;
    if (!mounted) return;
    setState(() { _processingRequests.add(requestId); _errorMessage = null; });

    try {
      // **VERIFY BACKEND ENDPOINT AND METHOD (POST/PUT)**
      final response = await _dio.put('/leave/$requestId/approve');

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request Approved'), backgroundColor: Colors.green),
        );
        _updateLocalStatus(requestId, 'APPROVED'); // Update local state
      } else {
        _handleApiError(response, 'Failed to approve request');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'approving request');
    } finally {
      if (mounted) {
        setState(() { _processingRequests.remove(requestId); });
      }
    }
  }

  // --- Reject Leave Request ---
  Future<void> _rejectRequest(int requestId) async {
    if (_processingRequests.contains(requestId)) return;
    if (!mounted) return;
    setState(() { _processingRequests.add(requestId); _errorMessage = null; });

    try {
      // **VERIFY BACKEND ENDPOINT AND METHOD (POST/PUT)**
      final response = await _dio.put('/leave/$requestId/reject');

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request Rejected'), backgroundColor: Colors.orange),
        );
        _updateLocalStatus(requestId, 'REJECTED'); // Update local state
      } else {
        _handleApiError(response, 'Failed to reject request');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'rejecting request');
    } finally {
      if (mounted) {
        setState(() { _processingRequests.remove(requestId); });
      }
    }
  }

  // --- Delete Leave Request ---
  Future<void> _deleteRequest(int requestId) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        // ... (Confirmation Dialog remains the same) ...
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this leave request? This cannot be undone.'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete'), style: TextButton.styleFrom(foregroundColor: Colors.red)),
          ],
        );
      },
    ) ?? false;

    if (!confirmDelete || !mounted) return;

    if (_processingRequests.contains(requestId)) return;
    setState(() { _processingRequests.add(requestId); _errorMessage = null; });

    try {
      // **VERIFY BACKEND ENDPOINT**
      final response = await _dio.delete('/leave/update-claim/$requestId');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request Deleted'), backgroundColor: Colors.grey),
        );
        // Remove locally for immediate feedback instead of full refresh
        setState(() {
          _leaveRequests.removeWhere((req) => req['id'] == requestId);
        });
        // Or await _fetchLeaveRequests();
      } else {
        _handleApiError(response, 'Failed to delete request');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'deleting request');
    } finally {
      if (mounted) {
        setState(() { _processingRequests.remove(requestId); });
      }
    }
  }

  // --- Helper to update local state ---
  void _updateLocalStatus(int requestId, String newStatus) {
    setState(() {
      final index = _leaveRequests.indexWhere((req) => req['id'] == requestId);
      if (index != -1) {
        // Create a new map to ensure widget rebuilds
        Map<String, dynamic> updatedRequest = Map.from(_leaveRequests[index]);
        updatedRequest['status'] = newStatus;
        _leaveRequests[index] = updatedRequest;
      }
    });
  }

  // --- Helper for API Error Handling ---
  void _handleApiError(Response? response, String defaultMessage) {
    if (!mounted) return;
    String errorMsg = defaultMessage;
    if (response?.data is Map && response!.data.containsKey('error')) {
      errorMsg = response.data['error'];
    } else if (response?.statusMessage != null && response!.statusMessage!.isNotEmpty) {
      errorMsg = response.statusMessage!;
    } else if (response?.data != null){
      errorMsg = response!.data.toString(); // Show raw response data as last resort
    }
    setState(() {
      _errorMessage = '$errorMsg (Status: ${response?.statusCode ?? 'N/A'})';
    });
    print('$defaultMessage: ${response?.statusCode}, Response: ${response?.data}');
  }

  // --- Helper for Generic Error Handling ---
  void _handleGenericError(Object e, String action) {
    if (!mounted) return;
    String errorMsg = 'Error $action: ${e.toString()}';
    if (e is DioError) { // Correct Type
      if (e.response != null && e.response?.data is Map && e.response?.data['error'] != null) {
        errorMsg = e.response?.data['error'];
      } else if (e.response != null && e.response?.data != null) {
        errorMsg = "Server Error (${e.response?.statusCode}): ${e.response?.data.toString().substring(0,100)}..."; // Truncate long errors
      }
      else if (e.response != null) {
        errorMsg = 'Server Error: ${e.response?.statusCode}';
      }
      else {
        errorMsg = 'Network Error. Please check connection.';
      }
    }
    setState(() { _errorMessage = errorMsg; });
    print('Error $action: $e');
  }

  // Helper to format dates for display
  String _formatDateDisplay(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      // Attempt parsing common ISO formats
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(dateTime); // Your desired display format
    } catch (e) {
      print("Error parsing date '$dateString': $e");
      return "Invalid Date"; // Indicate parsing error
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canManage = (_userRole == 'ADMIN' || _userRole == 'MANAGER');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Requests'),
        backgroundColor: Colors.blue, // Consistent AppBar color
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center)))
                  : _leaveRequests.isEmpty
                  ? const Center(child: Text('No leave requests found.'))
                  : RefreshIndicator(
                onRefresh: _fetchLeaveRequests,
                child: ListView.builder(
                  itemCount: _leaveRequests.length,
                  itemBuilder: (context, index) {
                    final request = _leaveRequests[index];
                    final user = request['user'] as Map<String, dynamic>?;
                    final username = user?['username'] ?? 'N/A';
                    final leaveTypeRaw = request['leaveType'];
                    final startDateRaw = request['startDate'];
                    final endDateRaw = request['endDate'];

                    // Attempt to parse leaveType string into Enum, fallback to N/A
                    LeaveType? parsedLeaveType;
                    if (leaveTypeRaw is String) {
                      try {
                        parsedLeaveType = LeaveType.values.firstWhere(
                              (e) => e.name == leaveTypeRaw,
                          // orElse: () => null, // Return null if no match
                        );
                      } catch (e) {
                        print("Warning: Could not parse LeaveType '$leaveTypeRaw'");
                        // parsedLeaveType remains null
                      }
                    }
                    final leaveType = parsedLeaveType?.name ?? 'N/A'; // Display name or N/A

                    final startDate = _formatDateDisplay(startDateRaw?.toString()); // Use robust formatter
                    final endDate = _formatDateDisplay(endDateRaw?.toString());   // Use robust formatter
                    final status = request['status'] ?? 'N/A';
                    final requestId = request['id'] as int?;
                    final bool isProcessing = requestId != null && _processingRequests.contains(requestId);

                    if (requestId == null) return const SizedBox.shrink();

                    // Ensure status comparison is robust (case-insensitive)
                    final bool isPending = (status.toUpperCase() == 'PENDING' || status.toUpperCase() == 'SUBMITTED');
                    final bool canEmployeeDelete = (_userRole == 'EMPLOYEE' && isPending);

                    return GestureDetector(
                        onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LeaveRequestDetailsScreen( leaveRequest: request // Passez le claim entier ou un ID
                          ),
                        ),
                      );
                    },
                    child:Card(
                      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (canManage)
                                  Flexible(child: Text('User: $username', style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                if (!canManage)
                                  Flexible(child: Text('Type: $leaveType', style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                Chip(
                                  label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  backgroundColor: _getStatusColor(status),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  labelPadding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                            const Divider(height: 15),
                            if(canManage) // Show type for managers/admins as well
                              Text('Type: $leaveType'),
                            Text('Dates: $startDate - $endDate'),
                            if (request['description'] != null && request['description'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('Reason: ${request['description']}'),
                              ),

                            // Conditional Action Buttons
                            if (isPending) // Show actions only if pending/submitted
                              Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: isProcessing
                                    ? const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Approve/Reject only for Manager/Admin
                                    if (canManage) ...[
                                      TextButton.icon(
                                        icon: const Icon(Icons.check_circle, size: 20, color: Colors.green),
                                        label: const Text('Approve', style: TextStyle(color: Colors.green)),
                                        onPressed: () => _approveRequest(requestId),
                                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(50, 30)),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        icon: const Icon(Icons.cancel, size: 20, color: Colors.orange),
                                        label: const Text('Reject', style: TextStyle(color: Colors.orange)),
                                        onPressed: () => _rejectRequest(requestId),
                                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(50, 30)),
                                      ),
                                      const SizedBox(width: 8), // Space before delete
                                    ],

                                    // Delete Button shown for Employee OR Manager/Admin if pending
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      onPressed: () => _deleteRequest(requestId),
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(50, 30)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LeaveRequestScreen(token: widget.token),
            ),
          ).then((success) {
            if (success == true) { _fetchLeaveRequests();}
            else { _fetchLeaveRequests();}
          });
        },
        child: const Icon(Icons.add),
        tooltip: 'Request Leave',
        backgroundColor: Colors.blue, // Match AppBar color
      ),
    );
  }

  // Helper to get color based on status
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING': return Colors.blueGrey;
      case 'SUBMITTED': return Colors.blueGrey; // Treat same as pending
      case 'APPROVED': return Colors.green;
      case 'REJECTED': return Colors.red;
      default: return Colors.grey;
    }
  }
}
