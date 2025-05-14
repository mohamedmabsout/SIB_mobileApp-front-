// lib/screens/expense_claim_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:sib_expense_app/screens/expense_claim_screen.dart'; // For Edit

// Define Enums if not imported centrally - MUST MATCH BACKEND EXACTLY
enum ExpenseClaimStatus { SUBMITTED, PENDING, APPROVED, REJECTED, REIMBURSED }
enum ExpenseCategory { FOOD, TRAVEL, SUPPLIES, OTHER } // Add all your categories

class ExpenseClaimDetailScreen extends StatefulWidget {
  final String token;
  final int claimId;

  const ExpenseClaimDetailScreen({
    Key? key,
    required this.token,
    required this.claimId,
  }) : super(key: key);

  @override
  _ExpenseClaimDetailScreenState createState() => _ExpenseClaimDetailScreenState();
}

class _ExpenseClaimDetailScreenState extends State<ExpenseClaimDetailScreen> {
  Map<String, dynamic>? _claimDetails;
  bool _isLoading = true;
  bool _isProcessingAction = false; // For approve/reject/delete actions
  String? _errorMessage;
  String _userRole = '';
  int? _loggedInUserId; // To check if current user is the submitter

  final Dio _dio = createDioClient();
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy, hh:mm a'); // More detailed format
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'fr_MA', symbol: 'MAD', decimalDigits: 2); // Example Moroccan Dirham

  @override
  void initState() {
    super.initState();
    _fetchRoleAndData();
  }

  Future<void> _fetchRoleAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    _loggedInUserId = prefs.getInt('user_id'); // Get logged-in user's ID
    if (!mounted) return;
    if (_userRole.isEmpty || _loggedInUserId == null) {
      setState(() { _isLoading = false; _errorMessage = "User/Role info missing."; });
      return;
    }
    await _fetchClaimDetails();
  }

  Future<void> _fetchClaimDetails() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    // **VERIFY/MODIFY** Endpoint path for fetching a single claim
    final String endpoint = '/claims/${widget.claimId}';

    try {
      print('Fetching claim details from: $endpoint');
      final response = await _dio.get(endpoint);

      if (!mounted) return;

      if (response.statusCode == 200 && response.data is Map) {
        setState(() {
          _claimDetails = response.data as Map<String, dynamic>;
        });
      } else {
        _handleApiError(response, 'Failed to load claim details');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'fetching claim details');
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  // --- Approve Claim ---
  Future<void> _approveClaim() async {
    if (_isProcessingAction || !mounted) return;
    setState(() { _isProcessingAction = true; _errorMessage = null; });

    try {
      final response = await _dio.put(
          '/claims/update-claim/${widget.claimId}', // Your confirmed endpoint
          data: {'status': 'APPROVED'}
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim Approved!'), backgroundColor: Colors.green));
        _fetchClaimDetails(); // Refresh details
      } else { _handleApiError(response, 'Failed to approve claim'); }
    } catch (e) { if (!mounted) return; _handleGenericError(e, 'approving claim');
    } finally { if (mounted) { setState(() { _isProcessingAction = false; }); } }
  }

  // --- Reject Claim ---
  Future<void> _rejectClaim() async {
    if (_isProcessingAction || !mounted) return;
    setState(() { _isProcessingAction = true; _errorMessage = null; });
    try {
      final response = await _dio.put(
          '/claims/update-claim/${widget.claimId}', // Your confirmed endpoint
          data: {'status': 'REJECTED'}
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim Rejected!'), backgroundColor: Colors.orange));
        _fetchClaimDetails(); // Refresh details
      } else { _handleApiError(response, 'Failed to reject claim'); }
    } catch (e) { if (!mounted) return; _handleGenericError(e, 'rejecting claim');
    } finally { if (mounted) { setState(() { _isProcessingAction = false; }); } }
  }

  // --- Delete Claim ---
  Future<void> _deleteClaim() async {
    bool confirmDelete = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogCtx) {
          return AlertDialog(
            title: const Text('Confirm Delete'),
            content: const Text('Are you sure you want to delete this expense claim? This action cannot be undone.'),
            actions: <Widget>[
              TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogCtx).pop(false)),
              TextButton(child: const Text('Delete'), style: TextButton.styleFrom(foregroundColor: Colors.red), onPressed: () => Navigator.of(dialogCtx).pop(true)),
            ],
          );
        }) ?? false;

    if (!confirmDelete || !mounted) return;
    setState(() { _isProcessingAction = true; _errorMessage = null; }); // Use _isProcessingAction

    try {
      final response = await _dio.delete('/claims/update-claim/${widget.claimId}'); // Your confirmed endpoint
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense Claim Deleted'), backgroundColor: Colors.grey));
        Navigator.pop(context, true); // Pop back to list and signal refresh
      } else {
        _handleApiError(response, 'Failed to delete claim');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'deleting claim');
    } finally {
      if (mounted) { setState(() { _isProcessingAction = false; }); }
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


  // --- Date Formatter ---
  String _formatDateDisplay(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString); // Assumes ISO 8601 format (YYYY-MM-DD or with time)
      return _dateFormatter.format(date); // Use the instance formatter
    } catch (e) { return "Invalid Date"; }
  }

  // --- Status Color Helper ---
  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING': return Colors.orange.shade700;
      case 'SUBMITTED': return Colors.blue.shade700;
      case 'APPROVED': return Colors.green.shade700;
      case 'REJECTED': return Colors.red.shade700;
      case 'REIMBURSED': return Colors.purple.shade700;
      default: return Colors.grey.shade600;
    }
  }
  // --- Build Detail Row ---
  Widget _buildDetailRow(IconData icon, String label, String? value, {bool isCurrency = false, bool isLink = false, VoidCallback? onLinkTap}) {
    Widget valueWidget = Text(value ?? 'N/A', style: TextStyle(color: Colors.grey[800], fontSize: 15));
    if (isCurrency && value != null) {
      try {
        final amount = double.parse(value);
        valueWidget = Text(_currencyFormatter.format(amount), style: TextStyle(color: Colors.grey[800], fontSize: 15, fontWeight: FontWeight.w600));
      } catch (e) { valueWidget = const Text('Invalid Amount', style: TextStyle(color: Colors.red, fontSize: 15)); }
    }
    if (isLink && value != null) {
      valueWidget = InkWell(
        onTap: onLinkTap,
        child: Text(value, style: TextStyle(color: Colors.blue, fontSize: 15, decoration: TextDecoration.underline)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          SizedBox(width: 110, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canManage = (_userRole == 'ADMIN' || _userRole == 'MANAGER');
    final String status = _claimDetails?['status']?.toString().toUpperCase() ?? '';
    final bool isPending = (status == 'PENDING' || status == 'SUBMITTED');
    final submitterId = (_claimDetails?['user'] as Map?)?['id'] as int?;
    final bool isOwnClaim = _loggedInUserId == submitterId;


    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? 'Loading Claim...' : 'Expense Claim Details'),
        backgroundColor: Colors.blue[700],
        actions: [
          if (!_isLoading && _claimDetails != null && ( (isOwnClaim && isPending) || canManage) )
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: "Edit Claim",
              onPressed: _isProcessingAction ? null : () { // Disable if another action is in progress
                Navigator.push(context, MaterialPageRoute(
                    builder: (context) => ExpenseClaimScreen(
                      token: widget.token,
                      initialClaimData: _claimDetails, // Pass current data
                    )
                )).then((success) { if(success == true) _fetchClaimDetails(); });
              },
            ),
          if (!_isLoading && _claimDetails != null && ( (isOwnClaim && isPending) || canManage) ) // Allow delete under same conditions as edit
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white), // White delete icon
              tooltip: "Delete Claim",
              onPressed: _isProcessingAction ? null : _deleteClaim,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchClaimDetails,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center)))
            : _claimDetails == null
            ? const Center(child: Text('Expense claim data not found.'))
            : ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- Claim Header ---
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Claim ID: #${_claimDetails!['id']}", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        Chip(
                          label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          backgroundColor: _getStatusColor(status),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.person_outline, "Submitted By", (_claimDetails!['user'] as Map?)?['username'] ?? 'N/A'),
                    _buildDetailRow(Icons.email_outlined, "Submitter Email", (_claimDetails!['user'] as Map?)?['email'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Core Claim Details ---
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Details", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(height: 10, thickness: 0.5),
                    _buildDetailRow(Icons.calendar_today, "Date", _formatDateDisplay(_claimDetails!['date'] as String?)),
                    _buildDetailRow(Icons.category_outlined, "Category", _claimDetails!['category'] as String?),
                    _buildDetailRow(Icons.attach_money, "Amount", _claimDetails!['amount']?.toString(), isCurrency: true),
                    _buildDetailRow(Icons.description_outlined, "Description", _claimDetails!['description'] as String?),
                  ],
                ),
              ),
            ),

            // --- Receipt Image ---
            if (_claimDetails!['receiptImageUrl'] != null && (_claimDetails!['receiptImageUrl'] as String).isNotEmpty) ...[
              const SizedBox(height: 20),
              Text("Receipt Image", style: Theme.of(context).textTheme.titleLarge),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: GestureDetector(
                  onTap: (){
                    // TODO: Implement full-screen image viewer
                    showDialog(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(_claimDetails!['receiptImageUrl']))));
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _claimDetails!['receiptImageUrl'],
                      height: 200, // Constrain height
                      width: double.infinity,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) => progress == null ? child : const Center(heightFactor: 2, child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stack) => Center(child: Text('Could not load receipt image.', style: TextStyle(color: Colors.red))),
                    ),
                  ),
                ),
              ),
            ],

            // --- Action Buttons (Manager/Admin if Pending) ---
            if (canManage && isPending)
              Padding(
                padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                child: _isProcessingAction
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('Approve', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                      onPressed: _approveClaim,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cancel, color: Colors.white),
                      label: const Text('Reject', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                      onPressed: _rejectClaim,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}