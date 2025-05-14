// lib/screens/manager_dashboard.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/components/dashboard_card.dart';
import 'package:sib_expense_app/screens/dashboard_template.dart';
import 'package:sib_expense_app/screens/affectations_screen.dart';
import 'package:sib_expense_app/screens/leave_request_list_screen.dart';
import 'package:sib_expense_app/screens/employees_screen.dart';
import 'package:sib_expense_app/config/dio_client.dart'; // Import centralized Dio
import 'package:sib_expense_app/models/dashboard_data_dto.dart'; // Import DTO
import 'package:sib_expense_app/screens/leave_request_screen.dart';
import 'package:sib_expense_app/screens/project_list_screen.dart';
import 'package:sib_expense_app/screens/record_stock_movement_screen.dart';
import 'package:sib_expense_app/screens/task_list_screen.dart';

import 'assignment_list_screen.dart';
import 'client_list_screen.dart';
import 'equipment_list_screen.dart';
import 'login_screen.dart'; // Import leave request form screen

class ManagerDashboard extends StatefulWidget {
  final String token;
  const ManagerDashboard({Key? key, required this.token}) : super(key: key);

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  DashboardDataDto? _kpiData; // State for KPI data
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage; // Renamed for clarity

  final Dio _dio = createDioClient(); // Use centralized Dio

  @override
  void initState() {
    super.initState();
    _refreshDashboardData(); // Fetch data initially
  }

  Future<void> _refreshDashboardData() async {
    if (_isRefreshing || !mounted) return;

    if (!_isLoading) {
      setState(() { _isRefreshing = true; });
    }
    setState(() { _errorMessage = null; });

    try {
      print("Refreshing Manager Dashboard KPIs...");
      // Fetch the general dashboard data - backend service should provide manager-specific data
      final response = await _dio.get('/api/dashboard/data');

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _kpiData = DashboardDataDto.fromJson(response.data);
        });
      } else {
        _handleApiError(response, "Failed to refresh dashboard data");
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, "refreshing dashboard data");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Initial load complete
          _isRefreshing = false;
        });
      }
    }
  }

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
    String errorMsg = 'Error $action: ${e.toString()}';
    if (e is DioError) {
      if (e.response != null && e.response?.data is Map && e.response?.data['error'] != null) { errorMsg = e.response?.data['error'];}
      else if (e.response != null && e.response?.data != null) { errorMsg = "Server Error (${e.response?.statusCode}): ${e.response?.data.toString().substring(0,100)}..."; }
      else if (e.response != null) { errorMsg = 'Server Error: ${e.response?.statusCode}'; }
      else { errorMsg = 'Network Error. Please check connection.'; }
    }
    setState(() { _errorMessage = errorMsg; });
    print('Error $action: $e');
  }
  String _formatDioExceptionMessage(DioException e) {
    // ... (Implementation from previous answer) ...
    String errorMsg;
    if (e.response != null && e.response?.data is Map) {
      final responseData = e.response!.data as Map<String, dynamic>;
      errorMsg = responseData['error'] ?? responseData['message'] ?? 'Server Error (${e.response?.statusCode})';
    } else if (e.response != null) {
      errorMsg = 'Server Error: ${e.response?.statusCode} ${e.response?.statusMessage ?? ''}'.trim();
    } else {
      switch(e.type) {
        case DioExceptionType.connectionTimeout: /*...*/ errorMsg = 'Network timeout.'; break;
        case DioExceptionType.sendTimeout: /*...*/ errorMsg = 'Network timeout.'; break;
        case DioExceptionType.receiveTimeout: /*...*/ errorMsg = 'Network timeout.'; break;
        case DioExceptionType.connectionError: errorMsg = 'Network Error: Could not connect.'; break;
        case DioExceptionType.cancel: errorMsg = 'Request cancelled.'; break;
        case DioExceptionType.badCertificate: errorMsg = 'Invalid server certificate.'; break;
        case DioExceptionType.badResponse: errorMsg = 'Invalid response (${e.response?.statusCode}).'; break;
        case DioExceptionType.unknown: default: errorMsg = 'Unknown network issue.'; break;
      }
    }
    return errorMsg;
  }
  // --- End Error Handling ---
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
    );
  }
  @override
  Widget build(BuildContext context) {
    // Define colors
    const Color orangeStart = Color(0xFFFDC830); const Color orangeEnd = Color(0xFFF37335);
    const Color redStart = Color(0xFFEB5757); const Color redEnd = Color(0xFFB82E1F);
    const Color indigoStart = Color(0xFF5C6BC0); const Color indigoEnd = Color(0xFF283593);
    const Color tealStart = Color(0xFF4DB6AC); const Color tealEnd = Color(0xFF00695C);
    const Color cyanStart = Color(0xFF4DD0E1); const Color cyanEnd = Color(0xFF0097A7);
    const Color purpleStart = Color(0xFF8E2DE2); const Color purpleEnd = Color(0xFF4A00E0); // For personal leave request
    const Color greenStart = Color(0xFF6DD5FA); const Color greenEnd = Color(0xFF23A6D5); // For project card
    const Color brownStart = Color(0xFFA1887F); const Color brownEnd = Color(0xFF6D4C41); // For equipment card
    String pendingClaimsValue = _isLoading ? "..." : (_kpiData?.pendingExpenseClaims?.toString() ?? "0");
    String pendingLeaveValue = _isLoading ? "..." : (_kpiData?.pendingLeaveRequests?.toString() ?? "0");
    String activeAssignmentsValue = _isLoading ? "..." : (_kpiData?.teamAssignments?['ACTIVE']?.toString() ?? "0");
    String totalEmployeesValue = _isLoading ? "..." : (_kpiData?.totalUsers?.toString() ?? "0");
    String activeProjectsValue = _isLoading ? "..." : (_kpiData?.totalActiveProjects?.toString() ?? "0");
    String myOpenTasks = _isLoading ? "..." : (_kpiData?.myOpenTasks?.toString() ?? "0");

    return DashboardTemplate(
      title: 'Manager Dashboard',
      token: widget.token,
      onRefresh: _refreshDashboardData,
      kpiCards: [
        // Error Card
        if (_errorMessage != null && !_isLoading)
          Card(
              color: Colors.redAccent.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Error loading data:\n$_errorMessage!", style: TextStyle(color: Colors.red[900])),
              )
          ),

        // KPI Cards using dynamic values
        DashboardCard(
          title: 'Notes de Frais (À Valider)',
          value: pendingClaimsValue, // Use dynamic value
          icon: Icons.check_circle_outline,
          startColor: orangeStart, endColor: orangeEnd,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AffectationsScreen(token: widget.token))),
        ),
        DashboardCard(
          title: 'Demandes Congé (À Valider)',
          value: pendingLeaveValue, // Use dynamic value
          icon: Icons.event_available_outlined,
          startColor: redStart, endColor: redEnd,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LeaveRequestListScreen(token: widget.token))),
        ),
        DashboardCard(
          title: 'Affectations Équipe (Actives)',
          value: activeAssignmentsValue,
          icon: Icons.assignment_ind_outlined, // Changed Icon
          startColor: tealStart, endColor: tealEnd,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AssignmentListScreen(token: widget.token))), // Navigate to Assignment list
        ),
        DashboardCard(
          title: 'Gérer Employés',
          value: totalEmployeesValue, // Use dynamic value
          icon: Icons.group_outlined,
          startColor: indigoStart, endColor: indigoEnd,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EmployeesScreen(token: widget.token))),
        ),
        DashboardCard(
          title: 'Mes Tâches', // My Tasks
          value: myOpenTasks, // Show open task count for user if available
          icon: Icons.list_alt_rounded, // Icon for tasks
          startColor: orangeStart, endColor: orangeEnd,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TaskListScreen(token: widget.token))),
        ),
        DashboardCard(
          title: 'Voir Projets',
          value: activeProjectsValue, // Show active project count
          icon: Icons.business_center_outlined,
          startColor: greenStart, endColor: greenEnd,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectListScreen(token: widget.token))),
        ),
        // --- NEW CARD: View Equipment ---
        DashboardCard(
          title: 'Voir Matériel',
          value: "Liste", // Or fetch count if available in DTO
          icon: Icons.build_circle_outlined,
          startColor: brownStart, endColor: brownEnd,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EquipmentListScreen(token: widget.token))),
        ),
    DashboardCard(
    title: 'Clients',
    value: "Voir",
    icon: Icons.add_call,
    startColor: Colors.cyan.shade300, endColor: Colors.cyan.shade800,
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ClientListScreen(token: widget.token))),
    ), DashboardCard(
          title: 'Mouvement Stock',
          value: "+/-",
          icon: Icons.compare_arrows_outlined,
          startColor: Colors.blueGrey.shade300, endColor: Colors.blueGrey.shade700,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RecordStockMovementScreen(token: widget.token))),
        ),
        DashboardCard(
          title: 'Demander Congé (Perso)',
          value: "+", // Static value for action card
          icon: Icons.time_to_leave_outlined,
          startColor: purpleStart, endColor: purpleEnd, // Use distinct color
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LeaveRequestScreen(token: widget.token))).then((_) => _refreshDashboardData()), // Refresh might be needed
        ),
      ],
    );
  }
}