import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:sib_expense_app/screens/add_edit_equipment_screen.dart'; // For Add/Edit
import 'package:sib_expense_app/screens/equipment_detail_screen.dart'; // For Detail View
import 'package:intl/intl.dart'; // If formatting dates

 enum EquipmentStatus { NEW, ASSIGNED, IN_STORAGE, UNDER_MAINTENANCE, BROKEN, DISPOSED }

class EquipmentListScreen extends StatefulWidget {
  final String token;

  const EquipmentListScreen({Key? key, required this.token}) : super(key: key);

  @override
  _EquipmentListScreenState createState() => _EquipmentListScreenState();
}

class _EquipmentListScreenState extends State<EquipmentListScreen> {
  List<Map<String, dynamic>> _equipmentList = []; // List of Maps
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
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    _userId = prefs.getInt('user_id');
    if (!mounted) return;
    if (_userRole.isEmpty || _userId == null) {
      setState(() { _isLoading = false; _errorMessage = "User info missing."; });
      return;
    }
    await _fetchEquipment();
  }

  Future<void> _fetchEquipment() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    // Determine endpoint based on role - Adjust if needed
    String endpoint = (_userRole == 'ADMIN' || _userRole == 'MANAGER')
        ? '/api/equipment'       // Endpoint to get all equipment
        : '/api/equipment/my'; // Endpoint to get equipment assigned to user

    try {
      print('Fetching equipment from: $endpoint');
      final response = await _dio.get(endpoint);

      if (!mounted) return;

      if (response.statusCode == 200 && response.data is List) {
        setState(() {
          _equipmentList = List<Map<String, dynamic>>.from(response.data);
        });
      } else {
        _handleApiError(response, 'Failed to load equipment');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'fetching equipment');
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
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



  // --- Status Color Helper ---
  Color _getStatusColor(String? status) {
    // **MODIFY** based on your actual EquipmentStatus enum values
    switch (status?.toUpperCase()) {
      case 'ASSIGNED': return Colors.blue;
      case 'IN_STORAGE': return Colors.grey;
      case 'UNDER_MAINTENANCE': return Colors.orange;
      case 'BROKEN': return Colors.red;
      case 'DISPOSED': return Colors.black54;
      case 'NEW':
      default: return Colors.green; // Default for NEW or unknown
    }
  }


  @override
  Widget build(BuildContext context) {
    bool canManageEquipment = (_userRole == 'ADMIN' || _userRole == 'MANAGER');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment Inventory'),
        backgroundColor: Colors.brown, // Example color
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration( /* Search Bar */),
              onChanged: (value) { /* TODO: Implement Search */ },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(/* Error Message */)
                  : _equipmentList.isEmpty
                  ? const Center(child: Text('No equipment found.'))
                  : RefreshIndicator(
                onRefresh: _fetchEquipment,
                child: ListView.builder(
                  itemCount: _equipmentList.length,
                  itemBuilder: (context, index) {
                    final item = _equipmentList[index];
                    final itemId = item['id'] as int?;
                    final status = item['status'] as String?;
                    final assignedUsername = item['assignedUsername'] ?? 'Unassigned';
                    final projectName = item['projectName'] ?? 'None';


                    if (itemId == null) return const SizedBox.shrink();

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(status),
                          child: Icon(Icons.computer, color: Colors.white, size: 20), // Example icon
                        ),
                        title: Text(item['name'] ?? 'Unknown Item', style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item['serialNumber'] != null) Text('S/N: ${item['serialNumber']}', style: TextStyle(fontSize: 12)),
                            Text('Qty: ${item['stockQuantity'] ?? 0}', style: TextStyle(fontSize: 12)),
                            Text('Assigned: $assignedUsername', style: TextStyle(fontSize: 12)),
                            Text('Project: $projectName', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(status ?? 'N/A', style: TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: _getStatusColor(status),
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                              builder: (context) => EquipmentDetailScreen(
                                token: widget.token,
                                equipmentId: itemId, // Pass ID
                              )
                          )).then((_) => _fetchEquipment()); // Refresh list on return
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
      floatingActionButton: canManageEquipment
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(
              builder: (context) => AddEditEquipmentScreen(token: widget.token) // Navigate to Add Screen
          )).then((success) { if(success == true) _fetchEquipment(); }); // Refresh on return
        },
        child: const Icon(Icons.inventory), // Specific Icon
        tooltip: 'Add Equipment',
        backgroundColor: Colors.brown,
      )
          : null,
    );
  }
}