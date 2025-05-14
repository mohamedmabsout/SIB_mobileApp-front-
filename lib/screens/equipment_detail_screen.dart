import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:sib_expense_app/screens/add_edit_equipment_screen.dart'; // For Edit navigation
// Import StockMovementViewDTO if you created one
// import 'package:sib_expense_app/models/stock_movement_view_dto.dart';

class EquipmentDetailScreen extends StatefulWidget {
  final String token;
  final int equipmentId;

  const EquipmentDetailScreen({
    Key? key,
    required this.token,
    required this.equipmentId,
  }) : super(key: key);

  @override
  _EquipmentDetailScreenState createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen> {
  Map<String, dynamic>? _equipmentDetails;
  List<Map<String, dynamic>> _stockMovements = []; // List of movements
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = '';

  final Dio _dio = createDioClient();
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _fetchRoleAndData();
  }

  Future<void> _fetchRoleAndData() async {
    // ... (Fetch role - Same as list screen) ...
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    if (!mounted) return;
    if (_userRole.isEmpty) {
      setState(() { _isLoading = false; _errorMessage = "Role info missing."; }); return;
    }
    await _fetchDetailsAndHistory(); // Fetch both details and history
  }

  Future<void> _fetchDetailsAndHistory() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // Fetch details and history concurrently
      final responses = await Future.wait([
        _dio.get('/api/equipment/${widget.equipmentId}'), // **VERIFY/MODIFY** Endpoint
        _dio.get('/api/equipment/${widget.equipmentId}/movements') // **VERIFY/MODIFY** Endpoint
      ]);

      if (!mounted) return;

      // Process Equipment Details
      if (responses[0].statusCode == 200 && responses[0].data is Map) {
        _equipmentDetails = responses[0].data as Map<String, dynamic>;
      } else {
        _handleApiError(responses[0], 'Failed to load equipment details');
        // Optionally handle error more gracefully (e.g., show partial data if possible)
      }

      // Process Stock Movements
      if (responses[1].statusCode == 200 && responses[1].data is List) {
        _stockMovements = List<Map<String, dynamic>>.from(responses[1].data);
      } else {
        _handleApiError(responses[1], 'Failed to load movement history');
        // Don't necessarily block the whole screen if history fails
        // setState(() { _errorMessage = (_errorMessage ?? '') + '\nFailed to load history.'; });
      }

    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'loading details and history');
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  // --- Delete Logic ---
  Future<void> _deleteEquipment() async {
    // ... (Implementation similar to Project/Task delete, use /api/equipment/{id}) ...
    bool confirmDelete = await showDialog<bool>( // Add type argument <bool>
      context: context, // Pass context
      builder: (BuildContext dialogContext) { // Provide builder
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this equipement?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false), // Use dialogContext
            ),
            TextButton(
              child: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true), // Use dialogContext
            ),
          ],
        );
      },
    ) ?? false;
    if (!confirmDelete || !mounted) return;
    setState(() { _isLoading = true; });
    try {
      final response = await _dio.delete('/api/equipment/${widget.equipmentId}'); // **VERIFY/MODIFY**
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipement Deleted'), backgroundColor: Colors.grey),
        );
        Navigator.pop(context, true);
      } else { _handleApiError(response, 'Failed to delete'); }
    } catch (e) { if (!mounted) return; _handleGenericError(e, 'deleting');
    } finally { if (mounted) { setState(() { _isLoading = false; }); } }
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
  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACTIVE': return Colors.green;
      case 'PLANNING': return Colors.blue;
      case 'ON_HOLD': return Colors.orange;
      case 'COMPLETED': return Colors.grey;
      default: return Colors.grey.shade400; // Explicit default return
    }
  }
  Widget _buildDetailRow(IconData icon, String label, String? value) {
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
        title: Text(_isLoading ? 'Loading...' : 'Equipment Details'),
        backgroundColor: Colors.brown,
        actions: [
          if (canEditDelete && !_isLoading && _equipmentDetails != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: "Edit Equipment",
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (context) => AddEditEquipmentScreen(
                      token: widget.token,
                      initialEquipmentData: _equipmentDetails, // Pass current data
                    )
                )).then((success) { if(success == true) _fetchDetailsAndHistory(); }); // Refresh
              },
            ),
          if (canEditDelete && !_isLoading && _equipmentDetails != null) // Maybe ADMIN only?
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: "Delete Equipment",
              onPressed: _deleteEquipment,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDetailsAndHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && _equipmentDetails == null // Show error only if main details failed
            ? Center(/* Error Message */)
            : _equipmentDetails == null
            ? const Center(child: Text('Equipment data not found.'))
            : ListView( // Use ListView to combine details and history
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- Equipment Header ---
            Text(_equipmentDetails!['name'] ?? 'Unknown Item', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Chip(
              label: Text(_equipmentDetails!['status'] ?? 'N/A', style: TextStyle(color: Colors.white, fontSize: 12)),
              backgroundColor: _getStatusColor(_equipmentDetails!['status'] as String?),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
            const SizedBox(height: 16),
            const Divider(),

            // --- Details Card ---
            Card(
              elevation: 2, margin: const EdgeInsets.symmetric(vertical: 10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.description_outlined, "Description", _equipmentDetails!['description'] as String?),
                    _buildDetailRow(Icons.inventory_outlined, "Stock Quantity", _equipmentDetails!['stockQuantity']?.toString() ?? '0'),
                    _buildDetailRow(Icons.warning_amber_outlined, "Min Stock Level", _equipmentDetails!['minimumStockLevel']?.toString() ?? '0'),
                    _buildDetailRow(Icons.info_outline, "Serial Number", _equipmentDetails!['serialNumber'] as String?),
                    _buildDetailRow(Icons.calendar_month_outlined, "Purchase Date", _formatDateDisplay(_equipmentDetails!['purchaseDate'] as String?)),
                    const Divider(height: 15),
                _buildDetailRow(Icons.person_outline, "Assigned To", _equipmentDetails!['assignedUsername'] ?? 'Unassigned'), // Use assignedUsername
                _buildDetailRow(Icons.folder_copy_outlined, "Project", _equipmentDetails!['projectName'] ?? 'None'),        // Use projectName
                 ],
                ),
              ),
            ),

            // --- Stock Movement History Section ---
            const SizedBox(height: 20),
            Text("Movement History", style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            _stockMovements.isEmpty
                ? const Padding( padding: EdgeInsets.symmetric(vertical: 16.0), child: Center(child: Text("No movement history found.")))
                : ListView.builder(
              shrinkWrap: true, // Important inside SingleChildScrollView
              physics: const NeverScrollableScrollPhysics(), // Let outer ListView scroll
              itemCount: _stockMovements.length,
              itemBuilder: (context, index) {
                final movement = _stockMovements[index];
                final isIN = (movement['type'] == 'IN');
                final performedByUserMap = movement['performedByUser'] as Map<String, dynamic>?;
                final performedBy = performedByUserMap?['username'] ?? 'System'; // Default to System if no user

                return ListTile(
                  dense: true,
                  leading: Icon(
                    isIN ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isIN ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  title: Text('${isIN ? '+' : '-'}${movement['quantity']} units on ${_formatDateDisplay(movement['movementDate'] as String?)}'),
                  subtitle: Text('By: $performedBy ${movement['reason'] != null ? '- Reason: ${movement['reason']}' : ''}'),
                );
              },
            ),

          ],
        ),
      ),
    );
  }
}