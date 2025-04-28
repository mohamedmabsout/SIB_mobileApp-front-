// lib/screens/dynamic_dashboard_screen.dart
import 'package:sib_expense_app/config/dio_client.dart'; // Import the helper
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/models/dashboard_data_dto.dart';
import 'package:sib_expense_app/screens/edit_profile_screen.dart';
import 'package:sib_expense_app/screens/login_screen.dart';
import 'package:sib_expense_app/screens/leave_request_list_screen.dart'; // List view
import 'package:sib_expense_app/screens/leave_request_screen.dart';    // Form view
import 'package:sib_expense_app/screens/affectations_screen.dart';      // Claims/Assignments list view
import 'package:sib_expense_app/screens/expense_claim_screen.dart';   // Claim form view
import 'package:sib_expense_app/screens/employees_screen.dart';        // User list / profile view
import 'package:sib_expense_app/screens/add_employee_screen.dart';

import '../components/dashboard_card.dart';     // Add Employee form

class DynamicDashboardScreen extends StatefulWidget {
final String token;

const DynamicDashboardScreen({Key? key, required this.token}) : super(key: key);

@override
State<DynamicDashboardScreen> createState() => _DynamicDashboardScreenState();
}
class _DynamicDashboardScreenState extends State<DynamicDashboardScreen> {
  // ... (Keep existing state variables: _dashboardData, _isLoading, _errorMessage, _userRole, _dio) ...
  DashboardDataDto? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = '';

  final Dio _dio = createDioClient(); // Get the configured Dio instance


  @override
  void initState() {
    super.initState();

    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final String? storedRole = prefs.getString('user_role');

    if (storedRole == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Role not found. Please login again.";
      });
      _logout(); // Force logout if role is missing
      return;
    }
    setState(() { _userRole = storedRole; });
    await _fetchDashboardData();
  }


  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      print('Fetching dashboard data...');
      final response = await _dio.get('/api/dashboard/data');

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _dashboardData = DashboardDataDto.fromJson(response.data);
          _isLoading = false;
        });
      } else {
        _handleApiError(response, 'Failed to load dashboard data');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'fetching dashboard data');
    } finally {
      if (mounted && _isLoading) {
        setState(() { _isLoading = false; });
      }
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
  // --- End Error Handling ---
  String _formatDioException(DioException e) {
    String errorMsg;
    if (e.response != null && e.response?.data is Map) {
      final responseData = e.response!.data as Map<String, dynamic>;
      errorMsg = responseData['error'] ?? responseData['message'] ?? 'Server Error (${e.response?.statusCode})';
    } else if (e.response != null) {
      errorMsg = 'Server Error: ${e.response?.statusCode} ${e.response?.statusMessage ?? ''}'.trim();
    } else {
      // Likely a connection error, timeout, etc.
      switch(e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMsg = 'Network timeout. Please check connection.';
          break;
        case DioExceptionType.connectionError:
          errorMsg = 'Network Error. Could not connect to server.';
          break;
        case DioExceptionType.cancel:
          errorMsg = 'Request cancelled.';
          break;
        case DioExceptionType.badCertificate:
          errorMsg = 'Invalid server certificate.';
          break;
        case DioExceptionType.badResponse: // Should be handled by checking response != null above
          errorMsg = 'Invalid response from server.';
          break;
        case DioExceptionType.unknown:
        default:
          errorMsg = 'Network Error: An unknown network issue occurred.';
          break;
      }
    }
    return errorMsg;
  }
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color startColor, // Start color for gradient
    required Color endColor,   // End color for gradient
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // More rounded
      clipBehavior: Clip.antiAlias, // Clip the InkWell ripple
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF0F4F8)], // White to very light blue
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space content vertically
              crossAxisAlignment: CrossAxisAlignment.start, // Align text left
              children: [
                // Top Row: Icon
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(icon, size: 32, color: Colors.white.withOpacity(0.8)),
                ),

                // Bottom Area: Value and Title
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox( // Ensure large numbers fit
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 30, // Larger value
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1, // Adjust line height
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14, // Slightly larger title
                        color: Colors.white.withOpacity(0.9),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Reusable Alerts Section Widget ---
  Widget _buildAlertsSection(List<AlertDto> alerts) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Card( /* ... keep existing implementation ... */);
  }
  IconData _getAlertIcon(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH': return Icons.error_outline;
      case 'MEDIUM': return Icons.warning_amber_outlined;
      case 'INFO': return Icons.info_outline;
      default: return Icons.info_outline; // Explicit return for default
    }
  }

  Color _getAlertColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH': return Colors.red;
      case 'MEDIUM': return Colors.orange;
      case 'INFO': return Colors.blue;
      default: return Colors.blue; // Explicit return for default
    }
  }

  // --- ** FULLY IMPLEMENTED ** Build the main dashboard grid ---
  // --- ** UPDATED ** Build the main dashboard grid for Admin ---
  List<Widget> _buildDashboardGrid(BuildContext context, DashboardDataDto data) {
    List<Widget> cards = [];
    final String currentToken = widget.token;

    // Define colors for Admin cards (can reuse or define new ones)
    const Color indigoStart = Color(0xFF5C6BC0); const Color indigoEnd = Color(0xFF283593);
    const Color tealStart = Color(0xFF4DB6AC); const Color tealEnd = Color(0xFF00695C);
    const Color orangeStart = Color(0xFFFDC830); const Color orangeEnd = Color(0xFFF37335);
    const Color redStart = Color(0xFFEB5757); const Color redEnd = Color(0xFFB82E1F);
    const Color blueStart = Color(0xFF3A7BD5); const Color blueEnd = Color(0xFF00D2FF);


    // --- ADMIN Specific Cards (Using New DashboardCard) ---
    if (_userRole == 'ADMIN') {
      cards.add(DashboardCard(
        title: 'Gestion Utilisateurs',
        value: data.totalUsers?.toString() ?? '0',
        icon: Icons.people_alt_outlined,
        startColor: indigoStart, endColor: indigoEnd,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EmployeesScreen(token: currentToken))),
      ));
      cards.add(DashboardCard(
        title: 'Projets Actifs',
        value: data.totalActiveProjects?.toString() ?? '0',
        icon: Icons.assessment_outlined,
        startColor: tealStart, endColor: tealEnd,
        onTap: () { /* TODO: Navigate to ProjectListScreen */ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Projects list screen not yet implemented.'))); },
      ));
      cards.add(DashboardCard(
        title: 'Total Notes Frais (Attente)',
        value: data.pendingExpenseClaims?.toString() ?? '0',
        icon: Icons.hourglass_bottom_outlined,
        startColor: orangeStart, endColor: orangeEnd,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AffectationsScreen(token: currentToken))),
      ));
      cards.add(DashboardCard(
        title: 'Total Demandes Congé (Attente)',
        value: data.pendingLeaveRequests?.toString() ?? '0',
        icon: Icons.event_note_outlined,
        startColor: redStart, endColor: redEnd,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LeaveRequestListScreen(token: currentToken))),
      ));
      cards.add(DashboardCard(
        title: 'Ajouter Employé',
        value: "Nouveau",
        icon: Icons.person_add_alt,
        startColor: blueStart, endColor: blueEnd,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddEmployeeScreen(token: currentToken))),
      ));
      // Add more Admin-specific cards if needed (e.g., Settings, Audit Logs)
      cards.add(DashboardCard(
        title: 'Paramètres', // Example settings card
        value: "Config",
        icon: Icons.settings_outlined,
        startColor: Colors.grey.shade400, endColor: Colors.grey.shade700,
        onTap: () { /* TODO: Navigate to Settings */ },
      ));
    } else {
      // This part shouldn't be reached if navigation logic is correct,
      // but good to have a fallback or error display
      cards.add(Card(child: Center(child: Text("Invalid Role for this Dashboard"))));
    }

    return cards;
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    // ... (Keep the existing Scaffold structure, AppBar, Background, SafeArea) ...
    return Scaffold(
      appBar: AppBar(
        title: Text('$_userRole Dashboard'), // Dynamic title
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Manage Users', // Add tooltips
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmployeesScreen(token: widget.token),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'View Assignments/Claims', // Adjust tooltip
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  // Assuming AffectationsScreen now shows Expense Claims or Assignments
                  builder: (context) => AffectationsScreen(token: widget.token),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.time_to_leave), // Or Icons.time_to_leave
            tooltip: 'Request Leave',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LeaveRequestListScreen(token: widget.token), // Pass the token
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(token: widget.token),
                ),
              ).then((_) => _fetchInitialData());
            },
          ),

        ],
      ),
      body: Stack(
        children: [
          Image.asset(
            'assets/dashboard_background2.jpg',
            fit: BoxFit.cover,
            width: double.infinity, height: double.infinity,
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 18), textAlign: TextAlign.center)))
                  : _dashboardData == null
                  ? const Center(child: Text('Could not load dashboard data.'))
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- KPI Grid ---
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16.0, // Increased spacing
                      mainAxisSpacing: 16.0,  // Increased spacing
                      childAspectRatio: 0.95, // START HERE and adjust (try 1.0, 0.9) - Controls height relative to width
                      children: _buildDashboardGrid(context, _dashboardData!),
                    ),
                    const SizedBox(height: 20),
                    // --- Alerts Section ---
                    // if (_dashboardData!.alerts != null && _dashboardData!.alerts!.isNotEmpty) // Check if alerts list is not null and not empty
                    //    _buildAlertsSection(_dashboardData!.alerts!),

                    // Add other sections like charts or recent activity here
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

} // End of _DynamicDashboardScreenState