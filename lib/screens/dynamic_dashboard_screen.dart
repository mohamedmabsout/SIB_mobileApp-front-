// lib/screens/dynamic_dashboard_screen.dart
import 'package:sib_expense_app/config/dio_client.dart'; // Import the helper
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/models/dashboard_data_dto.dart';
import 'package:sib_expense_app/screens/client_list_screen.dart';
import 'package:sib_expense_app/screens/edit_profile_screen.dart';
import 'package:sib_expense_app/screens/login_screen.dart';
import 'package:sib_expense_app/screens/leave_request_list_screen.dart'; // List view
import 'package:sib_expense_app/screens/leave_request_screen.dart';    // Form view
import 'package:sib_expense_app/screens/affectations_screen.dart';      // Claims/Assignments list view
import 'package:sib_expense_app/screens/expense_claim_screen.dart';   // Claim form view
import 'package:sib_expense_app/screens/employees_screen.dart';        // User list / profile view
import 'package:sib_expense_app/screens/add_employee_screen.dart';
import 'package:sib_expense_app/screens/project_list_screen.dart';
import 'package:sib_expense_app/screens/record_stock_movement_screen.dart';
import 'package:sib_expense_app/screens/task_list_screen.dart';
import 'package:sib_expense_app/screens/equipment_list_screen.dart';
import '../components/dashboard_card.dart';
import 'alerts_screen.dart';
import 'assignment_list_screen.dart';

class DynamicDashboardScreen extends StatefulWidget {
final String token;

const DynamicDashboardScreen({Key? key, required this.token}) : super(key: key);

@override
State<DynamicDashboardScreen> createState() => _DynamicDashboardScreenState();
}
class _DynamicDashboardScreenState extends State<DynamicDashboardScreen> {
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
      _logout();
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
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(icon, size: 32, color: Colors.white.withOpacity(0.8)),
                ),
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


  IconData _getAlertIcon(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH': return Icons.error_outline;
      case 'MEDIUM': return Icons.warning_amber_outlined;
      case 'INFO': return Icons.info_outline;
      default: return Icons.info_outline; // Explicit return for default
    }
  }



  Widget _buildAlertsSection(List<AlertDto> alerts) {
    if (alerts.isEmpty) return const SizedBox.shrink(); // Don't show if no alerts

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.only(top: 16.0, bottom: 8.0), // Add some margin
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "Important Alerts",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _getAlertColor("HIGH") // Use a prominent color
                )
            ),
            const Divider(height: 16, thickness: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_getAlertIcon(alert.priority), color: _getAlertColor(alert.priority), size: 28),
                  title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(alert.description),
                  onTap: () {
                    print("Tapped on alert: ${alert.title}");
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Action for '${alert.title}' not yet implemented."))
                    );
                  },
                );
              },
              separatorBuilder: (context, index) => const Divider(height: 10),
            )
          ],
        ),
      ),
    );
  }



  Color _getAlertColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH': return Colors.red.shade700;
      case 'MEDIUM': return Colors.orange.shade800;
      case 'WARNING': return Colors.orange.shade800;
      case 'INFO':
      default: return Colors.blue.shade700;
    }
  }
  List<Widget> _buildDashboardGrid(BuildContext context, DashboardDataDto data) {
    List<Widget> cards = [];
    final String currentToken = widget.token;

    // Define colors for Admin cards (can reuse or define new ones)
    const Color indigoStart = Color(0xFF5C6BC0); const Color indigoEnd = Color(0xFF283593);
    const Color tealStart = Color(0xFF4DB6AC); const Color tealEnd = Color(0xFF00695C);
    const Color orangeStart = Color(0xFFFDC830); const Color orangeEnd = Color(0xFFF37335);
    const Color redStart = Color(0xFFEB5757); const Color redEnd = Color(0xFFB82E1F);
    const Color blueStart = Color(0xFF3A7BD5); const Color blueEnd = Color(0xFF00D2FF);
    const Color greenStart = Color(0xFF6DD5FA); const Color greenEnd = Color(0xFF23A6D5); // Added for tasks
    const Color greyStart = Color(0xFFBDBDBD); const Color greyEnd = Color(0xFF616161); // Added for setting
    String activeAssignmentsValue = _isLoading ? "..." : (_dashboardData?.teamAssignments?['ACTIVE']?.toString() ?? "0");

    // --- ADMIN Specific Cards ---
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
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectListScreen(token: currentToken))),
      ));
      cards.add(DashboardCard(
        title: 'Total Notes Frais (Attente)',
        value: data.pendingExpenseClaims?.toString() ?? '0',
        icon: Icons.hourglass_bottom_outlined,
        startColor: greenStart, endColor: greenEnd, // Green gradient
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
      cards.add(DashboardCard(
        title: 'Mes Tâches', // My Tasks
        value: data.myOpenTasks?.toString() ?? "Voir", // Show open task count for user if available
        icon: Icons.list_alt_rounded, // Icon for tasks
        startColor: orangeStart, endColor: orangeEnd,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TaskListScreen(token: currentToken))),
      ));cards.add(DashboardCard(
        title: 'Affectations Équipe (Actives)',
        value: activeAssignmentsValue,
        icon: Icons.assignment_ind_outlined, // Changed Icon
        startColor: tealStart, endColor: tealEnd,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AssignmentListScreen(token: widget.token))), // Navigate to Assignment list
      ),);cards.add( DashboardCard(
        title: 'Gérer Inventaire',
        value: "Voir", // Fetch total count?
        icon: Icons.inventory_2_outlined,
        startColor: Colors.brown.shade300, endColor: Colors.brown.shade700,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EquipmentListScreen(token: widget.token))),
      ));
      cards.add(  DashboardCard(
      title: 'Mouvement Stock',
        value: "+/-",
        icon: Icons.compare_arrows_outlined,
        startColor: Colors.blueGrey.shade300, endColor: Colors.blueGrey.shade700,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RecordStockMovementScreen(token: widget.token))),
      ));cards.add(  DashboardCard(
      title: 'Clients',
        value: "Voir",
        icon: Icons.add_call,
        startColor: Colors.blueGrey.shade300, endColor: Colors.cyan.shade800,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ClientListScreen(token: widget.token))),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('$_userRole Dashboard'), // Dynamic title
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined), // Standard notifications icon
            tooltip: 'View Alerts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AlertsScreen(token: widget.token), // Pass the token
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