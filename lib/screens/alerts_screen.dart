import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:sib_expense_app/models/dashboard_data_dto.dart';
import 'package:sib_expense_app/screens/equipment_detail_screen.dart';
import 'package:sib_expense_app/screens/project_list_screen.dart';
import 'package:sib_expense_app/screens/task_detail_screen.dart';

import 'affectations_screen.dart';
import 'expense_claim_detail_screen.dart';
import 'leave_request_list_screen.dart'; // For AlertDto

class AlertsScreen extends StatefulWidget {
  final String token;

  const AlertsScreen({Key? key, required this.token}) : super(key: key);

  @override
  _AlertsScreenState createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<AlertDto> _alerts = [];
  bool _isLoading = true;
  String? _errorMessage;
  // String _userRole = ''; // Not strictly needed here if alerts are always user-specific

  final Dio _dio = createDioClient();

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // Assuming your /api/dashboard/data endpoint returns the alerts
      // specific to the authenticated user (based on the JWT token).
      // If you had a separate /api/alerts/my endpoint, you'd use that.
      print('Fetching alerts from /api/dashboard/data ...');
      final response = await _dio.get('/api/dashboard/data');

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final dashboardDto = DashboardDataDto.fromJson(response.data);
        setState(() {
          _alerts = dashboardDto.alerts ?? []; // Use the alerts list from the DTO
          _isLoading = false;
        });
      } else {
        _handleApiError(response, 'Failed to load alerts');
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'fetching alerts');
      setState(() { _isLoading = false; });
    }
  }

  // --- Error Handling Helpers (Copy from other screens) ---
  void _handleApiError(Response? response, String defaultMessage) {
     if (!mounted) return; String errorMsg = defaultMessage;
     if (response?.data is Map && response!.data.containsKey('error')) { errorMsg = response.data['error']; }
     else if (response?.statusMessage != null && response!.statusMessage!.isNotEmpty) { errorMsg = response.statusMessage!; }
     else if (response?.data != null){ errorMsg = response!.data.toString();}
     setState(() { _errorMessage = '$errorMsg (Status: ${response?.statusCode ?? 'N/A'})'; });
     print('$defaultMessage: ${response?.statusCode}, Response: ${response?.data}');
   }
  void _handleGenericError(Object e, String action) {
    if (!mounted) return; String errorMsg = 'Error $action';
    if (e is DioException) { errorMsg = _formatDioExceptionMessage(e); }
    else { errorMsg = 'An unexpected error occurred: ${e.toString()}'; print('Non-Dio Error type: ${e.runtimeType}'); }
    setState(() { _errorMessage = errorMsg; });
    print('Error during "$action": $e');
   }
  String _formatDioExceptionMessage(DioException e) {
     String errorMsg;
     if (e.response != null && e.response?.data is Map) {final responseData = e.response!.data as Map<String, dynamic>; errorMsg = responseData['error'] ?? responseData['message'] ?? 'Server Error (${e.response?.statusCode})';}
     else if (e.response != null) {errorMsg = 'Server Error: ${e.response?.statusCode} ${e.response?.statusMessage ?? ''}'.trim();}
     else {switch(e.type) { case DioExceptionType.connectionTimeout: case DioExceptionType.sendTimeout: case DioExceptionType.receiveTimeout: errorMsg = 'Network timeout.'; break; case DioExceptionType.connectionError: errorMsg = 'Network Error: Could not connect.'; break; case DioExceptionType.cancel: errorMsg = 'Request cancelled.'; break; case DioExceptionType.badCertificate: errorMsg = 'Invalid server certificate.'; break; case DioExceptionType.badResponse: errorMsg = 'Invalid response (${e.response?.statusCode}).'; break; case DioExceptionType.unknown: default: errorMsg = 'Unknown network issue.'; break;}}
     return errorMsg;
   }
  // --- End Error Handling ---
  void _navigateToTarget(AlertDto alert) {
    if (alert.targetType == null || (alert.targetId == null && !alert.targetType!.contains("LIST"))) {
      print("Alert has no valid target: ${alert.title}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No specific action defined for '${alert.title}'.")),
      );
      return;
    }

    Widget? targetScreen; // Use Widget? for nullable screen

    // Use uppercase for consistent comparison
    switch (alert.targetType!.toUpperCase()) {
      case 'TASK':
        if (alert.targetId != null) {
          targetScreen = TaskDetailScreen(token: widget.token, taskId: alert.targetId!);
        }
        break;
      case 'EXPENSE_CLAIM':
        if (alert.targetId != null) {
          // Assuming you have an ExpenseClaimDetailScreen
          targetScreen = ExpenseClaimDetailScreen(token: widget.token, claimId: alert.targetId!);
        }
        break;
        case 'EQUIPEMENT':
        if (alert.targetId != null) {
          targetScreen = EquipmentDetailScreen(token: widget.token, equipmentId: alert.targetId!);
        }
        break;
        case 'PROJECT':
        if (alert.targetId != null) {
          targetScreen = ProjectListScreen(token: widget.token);
        }
        break;
      case 'LEAVE_REQUEST':
        if (alert.targetId != null) {
          // Assuming you have a LeaveRequestDetailScreen
          // targetScreen = LeaveRequestDetailScreen(token: widget.token, requestId: alert.targetId!);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Leave Request Detail screen not yet implemented for navigation.")));
        }
        break;
      case 'EXPENSE_CLAIM_LIST_PENDING':
      // Navigate to the list screen, potentially passing a filter
        targetScreen = AffectationsScreen(token: widget.token /*, initialFilter: 'PENDING' */);
        break;
      case 'LEAVE_REQUEST_LIST_PENDING':
        targetScreen = LeaveRequestListScreen(token: widget.token /*, initialFilter: 'PENDING' */);
        break;
    // Add more cases for other targetTypes like "PROJECT", "USER_PROFILE", "NOTIFICATION_LIST" etc.
      default:
        print("Unknown alert targetType: ${alert.targetType}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No action defined for this type of alert: ${alert.targetType}")),
        );
    }

    if (targetScreen != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => targetScreen!),
      ).then((_){
        // Optionally refresh alerts if viewing them might mark them as read
        // or if an action on the target screen could generate new alerts.
        // _fetchAlerts();
      });
    }
  }

  // --- Alert Display Helpers (Copied from previous dashboard code) ---
  IconData _getAlertIcon(String priority) {
     switch (priority.toUpperCase()) {
       case 'HIGH': return Icons.error_rounded;
       case 'MEDIUM': case 'WARNING': return Icons.warning_amber_rounded;
       case 'INFO': default: return Icons.info_rounded;
     }
  }

  Color _getAlertColor(String priority) {
     switch (priority.toUpperCase()) {
       case 'HIGH': return Colors.red.shade700;
       case 'MEDIUM': case 'WARNING': return Colors.orange.shade800;
       case 'INFO': default: return Colors.blue.shade700;
     }
  }
  // --- End Alert Display Helpers ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications & Alerts'),
        backgroundColor: Theme.of(context).colorScheme.primary, // Use theme color
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAlerts,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
                    ),
                  )
                : _alerts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none_outlined, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('No new alerts or notifications.', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _alerts.length,
                        itemBuilder: (context, index) {
                          final alert = _alerts[index];
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              leading: Icon(
                                _getAlertIcon(alert.priority),
                                color: _getAlertColor(alert.priority),
                                size: 30,
                              ),
                              title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(alert.description),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _navigateToTarget(alert),

                            ),
                          );
                        },
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                      ),
      ),
    );
  }
}