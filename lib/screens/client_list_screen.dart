import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:sib_expense_app/screens/add_edit_client_screen.dart';
import 'package:sib_expense_app/screens/client_detail_screen.dart'; // Import Add/Edit screen

class ClientListScreen extends StatefulWidget {
  final String token;

  const ClientListScreen({Key? key, required this.token}) : super(key: key);

  @override
  _ClientListScreenState createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  List<Map<String, dynamic>> _clients = []; // Working with Maps
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = ''; // Needed to determine if Add/Edit/Delete allowed

  final Dio _dio = createDioClient();

  @override
  void initState() {
    super.initState();
    _fetchRoleAndData();
  }

  Future<void> _fetchRoleAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    if (!mounted) return;
    if (_userRole.isEmpty) {
      setState(() { _isLoading = false; _errorMessage = "Role info missing."; }); return;
    }
    await _fetchClients();
  }

  Future<void> _fetchClients() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    // Endpoint defined in AdminController
    const String endpoint = '/api/admin/all-clients';

    try {
      print('Fetching clients from: $endpoint');
      final response = await _dio.get(endpoint); // Dio instance has interceptor

      if (!mounted) return;

      if (response.statusCode == 200 && response.data is List) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(response.data);
        });
      } else {
        _handleApiError(response, 'Failed to load clients');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'fetching clients');
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  // --- Delete Client Logic ---
  Future<void> _deleteClient(int clientId) async {
    bool confirmDelete = await showDialog<bool>( context: context, builder: (ctx) => AlertDialog( title: Text('Confirm Delete'), content: Text('Delete this client? This may affect related projects.'), actions: [ TextButton(child: Text('Cancel'),onPressed: ()=>Navigator.of(ctx).pop(false)), TextButton(child: Text('Delete'), style: TextButton.styleFrom(foregroundColor: Colors.red), onPressed: ()=>Navigator.of(ctx).pop(true))])) ?? false;
    if (!confirmDelete || !mounted) return;

    setState(() { _isLoading = true; }); // Might want a specific deleting flag

    try {
      // **MODIFY/VERIFY:** Add DELETE /api/clients/{id} endpoint in backend
      final response = await _dio.delete('/api/clients/$clientId'); // Use DELETE on a client-specific path
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client Deleted'), backgroundColor: Colors.grey));
        _fetchClients(); // Refresh list
      } else { _handleApiError(response, 'Failed to delete client'); }
    } catch (e) { if (!mounted) return; _handleGenericError(e, 'deleting client');
    } finally { if (mounted) { setState(() { _isLoading = false; }); } } // Reset general loading
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
  String _formatDioExceptionMessage(DioException e) {
    switch(e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Network timeout. Please check connection.';
      case DioExceptionType.connectionError:
        var originalError = e.error;
        if (originalError is SocketException) {
          return 'Network Error: Could not connect (${originalError.osError?.message ?? 'No details'}). Check server address and network.';
        }
        return 'Network Error: Could not connect to server.';
      case DioExceptionType.cancel: return 'Request cancelled.';
      case DioExceptionType.badCertificate: return 'Invalid server certificate.';
      case DioExceptionType.badResponse: return 'Invalid response from server (${e.response?.statusCode}).';
      case DioExceptionType.unknown: default: return 'Network Error: An unknown network issue occurred.';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canManageClients = (_userRole == 'ADMIN' || _userRole == 'MANAGER');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        backgroundColor: Colors.cyan[700], // Example color
      ),
      body: Stack( // Add Stack for background
        children: [
          Image.asset( // Background Image
            'assets/dashboard_background1.jpg',
            fit: BoxFit.cover,
            width: double.infinity, height: double.infinity,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration( /* Search Bar */
                      hintText: 'Search Clients...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                      filled: true, fillColor: Colors.white70,
                    ),
                    onChanged: (value) { /* TODO: Implement Search */ },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMessage != null
                        ? Center(/* Error Message */)
                        : _clients.isEmpty
                        ? const Center(child: Text('No clients found.'))
                        : RefreshIndicator(
                      onRefresh: _fetchClients,
                      child: ListView.builder(
                        itemCount: _clients.length,
                        itemBuilder: (context, index) {
                          final client = _clients[index]; // client is Map<String, dynamic>
                          final clientId = client['id'] as int?;
                          final companyName = client['companyName'] as String? ?? 'Unknown Company';
                          final contactPerson = client['contactPerson'] as String?;
                          final email = client['email'] as String?;
                          final phone = client['phone'] as String?;
                          // --- Get Active Status ---
                          final bool isActive = client['active'] as bool? ?? false;
                          if (clientId == null) return const SizedBox.shrink();

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            color: isActive ? Colors.green[50] : Colors.red[50], // Very light green/red background
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isActive ? Colors.green.shade400 : Colors.red.shade400, // Green if active, Red if inactive
                                radius: 18, // Adjust size
                                child: Icon(
                                  isActive ? Icons.check_circle_outline : Icons.remove_circle_outline, // Different icons
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              title: Text(client['companyName'] ?? 'Unknown Company', style: TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Contact: ${client['contactPerson'] ?? 'N/A'}', style: TextStyle(fontSize: 13)),
                                  Text('Email: ${client['email'] ?? 'N/A'}', style: TextStyle(fontSize: 13)),
                                  Text('Phone: ${client['phone'] ?? 'N/A'}', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                              trailing: canManageClients ? PopupMenuButton<String>( // Edit/Delete menu
                                icon: const Icon(Icons.more_vert, size: 20),
                                tooltip: "Actions",
                                onSelected: (String choice) {
                                  if (choice == 'Edit') {
                                    Navigator.push(context, MaterialPageRoute(
                                        builder: (context) => AddEditClientScreen(
                                          token: widget.token,
                                          initialClientData: client, // Pass data for editing
                                        )
                                    )).then((success) { if(success == true) _fetchClients(); });
                                  } else if (choice == 'Delete') {
                                    _deleteClient(clientId);
                                  }
                                },
                                itemBuilder: (BuildContext context) {
                                  return {'Edit', 'Delete'}.map((String choice) {
                                    return PopupMenuItem<String>(
                                      value: choice,
                                      child: Text(choice, style: choice == 'Delete' ? TextStyle(color: Colors.red) : null),
                                    );
                                  }).toList();
                                },
                              ) : null, // No actions for non-managers/admins
                              onTap: () {
                                {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ClientDetailScreen(
                                            token: widget.token,
                                            // Use the correctly spelled variable name 'projectId'
                                            clientId: clientId, // Pass the project ID
                                          ),
                                    ),
                                  ).then((_) {
                                    _fetchClients();
                                  });
                                }},
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: canManageClients
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(
              builder: (context) => AddEditClientScreen(token: widget.token) // Navigate to Add Screen
          )).then((success) { if(success == true) _fetchClients(); });
        },
        child: const Icon(Icons.add_business), // Specific Icon
        tooltip: 'Add Client',
        backgroundColor: Colors.cyan[700],
      )
          : null,
    );
  }
}