// lib/screens/client_detail_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/dio_client.dart';
import 'add_edit_client_screen.dart';
// ... other necessary imports

class ClientDetailScreen extends StatefulWidget {
  final String token;
  final int clientId;

  const ClientDetailScreen({Key? key, required this.token, required this.clientId}) : super(key: key);

  @override
  _ClientDetailScreenState createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  Map<String, dynamic>? _clientDetails;
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = ''; // Needed for actions

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
    await _fetchClientDetails();
  }
  Future<void> _fetchClientDetails() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    // Endpoint defined in AdminController
    final String endpoint = '/api/clients/${widget.clientId}'; // CORRECT endpoint using the passed ID

    try {
      print('Fetching clients from: $endpoint');
      final response = await _dio.get(endpoint); // Dio instance has interceptor

      if (!mounted) return;

      if (response.statusCode == 200 && response.data is Map) {
        setState(() {
          // Directly cast the response data to the expected Map type
          _clientDetails = response.data as Map<String, dynamic>;
          // _isLoading = false; // Set loading false on success
        });
      } else {
        // Handle cases where status is not 200 or data is not a Map
        _handleApiError(response, 'Failed to load client details');
        // setState(() { _isLoading = false; }); // Set loading false on error
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'fetching clients');
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }
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
        _fetchClientDetails(); // Refresh list
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
          return "Network Error: Could not connect (${originalError.osError?.message ?? 'No details'}). Check server address and network.";
        }
        return 'Network Error: Could not connect to server.';
      case DioExceptionType.cancel: return 'Request cancelled.';
      case DioExceptionType.badCertificate: return 'Invalid server certificate.';
      case DioExceptionType.badResponse: return 'Invalid response from server (${e.response?.statusCode}).';
      case DioExceptionType.unknown: default: return 'Network Error: An unknown network issue occurred.';
    }
  }Widget _buildDetailRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value ?? 'N/A', style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canEditDelete = (_userRole == 'ADMIN' || _userRole == 'MANAGER');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? 'Loading...' : 'Client Details'),
        backgroundColor: Colors.cyan[700],
        actions: [
          if(canEditDelete && !_isLoading && _clientDetails != null)
            IconButton(
              icon: Icon(Icons.edit_outlined),
              tooltip: "Edit Client",
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (context) => AddEditClientScreen(token: widget.token, initialClientData: _clientDetails)
                )).then((success) => { if(success == true) _fetchClientDetails() });
              },
            ),
          if(canEditDelete && !_isLoading && _clientDetails != null) // Maybe Admin only?
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: "Delete Client",
              onPressed: () { // Wrap the call in a () => ... lambda
    // Ensure you have the ID available, either from widget or state
    if (widget.clientId != null) { // Or use _clientDetails!['id'] if fetched
    _deleteClient(widget.clientId); // Call delete with the correct ID
    } else {
    print("Error: Client ID not available for deletion");
    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Cannot delete: Client ID missing'), backgroundColor: Colors.red)
    );
    }
    },
            )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchClientDetails,
        child: _isLoading ? Center(child: CircularProgressIndicator())
            : _errorMessage != null ? Center(/*...Error...*/)
            : _clientDetails == null ? Center(child: Text("Client not found."))
            : ListView(
          padding: EdgeInsets.all(16),
          children: [
            Text(_clientDetails!['companyName'] ?? 'N/A', style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 16), Divider(),
            Card(
              margin: EdgeInsets.symmetric(vertical: 10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.person_pin_outlined, "Contact Person", _clientDetails!['contactPerson']),
                    _buildDetailRow(Icons.email_outlined, "Email", _clientDetails!['email']),
                    _buildDetailRow(Icons.phone_outlined, "Phone", _clientDetails!['phone']),
                    _buildDetailRow(Icons.blur_on_sharp, "active", _clientDetails!['avtive']),
                    // Add other fields like 'active' if present
                  ],
                ),
              ),
            ),
            // TODO: Add section to list related Projects (requires another API call)
          ],
        ),
      ),
    );
  }
}