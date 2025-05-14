import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/screens/expense_claim_screen.dart';
import 'package:sib_expense_app/config/dio_client.dart';

import 'expense_claim_detail_screen.dart'; // Import the helper

class AffectationsScreen extends StatefulWidget {
  final String token;

  const AffectationsScreen({
    Key? key,
    required this.token,
  }) : super(key: key);

  @override
  _AffectationsScreenState createState() => _AffectationsScreenState();
}

class _AffectationsScreenState extends State<AffectationsScreen> {
  List<Map<String, dynamic>> _expenseClaims = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = '';
  Set<int> _processingClaims = {}; // Keep track of claims being processed

  final Dio _dio = createDioClient(); // Get the configured Dio instance


  @override
  void initState() {
    super.initState();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.headers['Authorization'] = 'Bearer ${widget.token}';
        return handler.next(options);
      },
    ));
    _fetchUserRoleAndData();
  }

  Future<void> _fetchUserRoleAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedRole = prefs.getString('user_role');

    if (storedRole == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "User role not found. Please login again.";
      });
      return;
    }

    setState(() {
      _userRole = storedRole;
    });

    await _fetchExpenseClaims();
  }

  Future<void> _fetchExpenseClaims() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String endpoint;

    if (_userRole == 'ADMIN' || _userRole == 'MANAGER') {
      endpoint = '/api/admin/all-claims'; // Endpoint for admins/managers
    } else { // Assume EMPLOYEE role
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id'); // **CRITICAL: Ensure user_id is stored**

      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User ID not found. Please login again.';
        });
        return;
      }
      endpoint = '/claims/user/$userId'; // Endpoint for employee's own claims
    }

    try {
      print('Fetching expense claims from endpoint: $endpoint');
      final response = await _dio.get(endpoint);

      if (response.statusCode == 200) {
        setState(() {
          _expenseClaims = List<Map<String, dynamic>>.from(response.data);
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load expense claims: ${response.statusCode}';
        });
        print('Failed to load expense claims: ${response.statusCode}');
      }
    } on DioError catch (e) { // Changed DioException to DioError
      setState(() {
        _errorMessage = 'Error fetching expense claims: ${e.message}';
        if (e.response != null) {
          print('Error response data: ${e.response?.data}');
          if (e.response?.statusCode == 403) {
            _errorMessage = 'Access Denied. You might not have permission.';
          }
        } else {
          _errorMessage = 'Network Error: Could not connect to the server.';
        }
      });
      print('Error fetching expense claims: $e');
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
      print('Unexpected error: $e');
    }
    finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  Future<void> _approveClaim(int claimId) async {
    if (_processingClaims.contains(claimId)) return; // Prevent double taps

    setState(() {
      _processingClaims.add(claimId); // Mark as processing
      _errorMessage = null; // Clear previous errors
    });

    try {
      // **MODIFY:** Use your actual endpoint for approval (PUT or POST)
      final response = await _dio.put('/claims/$claimId/approve');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim Approved!'), backgroundColor: Colors.green),
        );
        // Option 1: Refresh the whole list (simpler)
        // await _fetchExpenseClaims();

        // Option 2: Update locally for immediate feedback (better UX)
        setState(() {
          final index = _expenseClaims.indexWhere((claim) => claim['id'] == claimId);
          if (index != -1) {
            _expenseClaims[index]['status'] = 'APPROVED'; // Or whatever status your API returns
          }
        });

      } else {
        setState(() {
          _errorMessage = 'Failed to approve claim: ${response.statusCode}';
        });
        print('Failed to approve claim: ${response.statusCode} ${response.data}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error approving claim: ${e.toString()}';
      });
      print('Error approving claim: $e');
    } finally {
      setState(() {
        _processingClaims.remove(claimId); // Unmark as processing
      });
    }
  }

  // --- NEW: Function to Reject a Claim ---
  Future<void> _rejectClaim(int claimId) async {
    if (_processingClaims.contains(claimId)) return;

    setState(() {
      _processingClaims.add(claimId);
      _errorMessage = null;
    });

    try {
      // **MODIFY:** Use your actual endpoint for rejection (PUT or POST)
      final response = await _dio.put('/claims/$claimId/reject');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim Rejected!'), backgroundColor: Colors.orange),
        );
        // Option 1: Refresh the whole list
        // await _fetchExpenseClaims();

        // Option 2: Update locally
        setState(() {
          final index = _expenseClaims.indexWhere((claim) => claim['id'] == claimId);
          if (index != -1) {
            _expenseClaims[index]['status'] = 'REJECTED'; // Or whatever status your API returns
          }
        });

      } else {
        setState(() {
          _errorMessage = 'Failed to reject claim: ${response.statusCode}';
        });
        print('Failed to reject claim: ${response.statusCode} ${response.data}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error rejecting claim: ${e.toString()}';
      });
      print('Error rejecting claim: $e');
    } finally {
      setState(() {
        _processingClaims.remove(claimId);
      });
    }
  }

  // --- Update/Delete for Expense Claims ---
  Future<void> _updateExpenseClaim(
      int id, Map<String, dynamic> updatedData) async {
    // **MODIFY:** Ensure updatedData matches your ExpenseClaimDTO/Entity on the backend
    try {
      final response = await _dio.put(
        '/update-claim/$id', // **MODIFY:** Adjust endpoint if needed
        data: updatedData,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      _fetchExpenseClaims(); // Refresh list

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense Claim updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update claim: ${response.statusCode}')),
        );
        print('Failed to update claim: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update error: ${e.toString()}')),
      );
      print('Update error: $e');
    }
  }

  Future<void> _deleteExpenseClaim(int id) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this expense claim?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirmDelete) return;

    try {
      final response = await _dio.delete(
        '/update-claim/$id', // **MODIFY:** Adjust endpoint if needed
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _fetchExpenseClaims(); // Refresh list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense Claim deleted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: ${response.statusCode}')),
        );
        print('Delete failed: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete error: ${e.toString()}')),
      );
      print('Delete error: $e');
    }
  }
  // --- End Update/Delete ---

  // --- Edit Dialog for Expense Claims ---
  void _showEditDialog(Map<String, dynamic> claim) {
    // Initialize controllers with existing data
    final TextEditingController amountController = TextEditingController(
      text: claim['amount']?.toString() ?? '',
    );
    final TextEditingController categoryController = TextEditingController(
      text: claim['category'] ?? '', // Assuming category is a String or Enum.toString()
    );
    final TextEditingController descriptionController = TextEditingController(
      text: claim['description'] ?? '',
    );
    final TextEditingController statusController = TextEditingController(
      text: claim['status'] ?? '', // Status might need a Dropdown
    );
    DateTime selectedDate = claim['date'] != null // Use 'date' field
        ? DateTime.tryParse(claim['date']) ?? DateTime.now()
        : DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder to update the date in the dialog itself
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Edit Expense Claim'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: amountController,
                        decoration: const InputDecoration(labelText: 'Amount'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      // Consider DropdownButton for category if it's an Enum
                      TextField(
                        controller: categoryController,
                        decoration: const InputDecoration(labelText: 'Category'),
                      ),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      // Consider DropdownButton for status if it's an Enum
                      TextField(
                        controller: statusController,
                        decoration: const InputDecoration(labelText: 'Status'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null && picked != selectedDate) {
                            // Use setDialogState to update the date shown in the dialog
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: Text('Select Date: ${selectedDate.toLocal().toString().split(' ')[0]}'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // Prepare updated data map based on ExpenseClaim structure
                      Map<String, dynamic> updatedData = {
                        'amount': double.tryParse(amountController.text.trim()),
                        'category': categoryController.text.trim(), // Adjust if Enum
                        'description': descriptionController.text.trim(),
                        'status': statusController.text.trim(), // Adjust if Enum
                        'date': selectedDate.toIso8601String().split('T').first,
                        // Add other fields as needed by your backend update endpoint
                      };

                      await _updateExpenseClaim(claim['id'], updatedData);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            }
        );
      },
    );
  }
  // --- End Edit Dialog ---

  @override
  Widget build(BuildContext context) {
    // Rename the Scaffold title for clarity
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Claims'), // Renamed title
        backgroundColor: Colors.blue[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search Claims...', // Updated hint text
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onChanged: (value) {
                // TODO: Implement search logic for claims here
                // You might want to filter the _expenseClaims list locally
                // or make a new API call with the search term.
              },
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_errorMessage!,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center),
                ),
              )
                  : _expenseClaims.isEmpty
                  ? const Center(child: Text('No expense claims found.'))
                  : RefreshIndicator( // Keep RefreshIndicator
                onRefresh: _fetchExpenseClaims,
                child: ListView.builder(
                  itemCount: _expenseClaims.length,
                  itemBuilder: (context, index) {
                    final claim = _expenseClaims[index];
                    // Safely access nested user data
                    final userMap = claim['user'] as Map<String, dynamic>?;
                    final username = userMap?['username'] ?? 'N/A';

                    // Safely access and format claim data
                    final amountRaw = claim['amount'];
                    final amount = amountRaw is num
                        ? amountRaw.toStringAsFixed(2)
                        : 'N/A';
                    final date = claim['date']?.toString() ?? 'N/A'; // Assuming date is String
                    final category = claim['category']?.toString() ?? 'N/A'; // Assuming category is String or Enum
                    final status = claim['status']?.toString() ?? 'N/A'; // Assuming status is String or Enum
                    final description = claim['description']?.toString() ?? '';
                    final claimId = claim['id'] as int?; // Use int? for safety

                    if (claimId == null) {
                      // Skip rendering if claim ID is missing (data integrity issue)
                      print("Warning: Skipping claim with missing ID at index $index");
                      return const SizedBox.shrink(); // Render nothing
                    }


                    final bool isProcessing = _processingClaims.contains(claimId);

                    // Determine if action buttons should be shown
                    final bool canTakeAction = (_userRole == 'ADMIN' || _userRole == 'MANAGER') &&
                        (status == 'PENDING' || status == 'SUBMITTED'); // **MODIFY:** Adjust valid statuses

                    return GestureDetector(
                        onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExpenseClaimDetailScreen(token: widget.token,
                            claimId: claimId // Passez le claim entier ou un ID
                          ),
                        ),
                      );
                    },
                    child:Card(
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      elevation: 2, // Add subtle elevation
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0), // Add padding inside card
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main Claim Info Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible( // Use Flexible to prevent title overflow
                                  child: Text(
                                    'Amount: $amount - Status: $status',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Edit/Delete only for Admin/Manager
                                if (_userRole == 'ADMIN' || _userRole == 'MANAGER')
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 20), // Smaller icon
                                    tooltip: "Actions",
                                    onSelected: (String choice) {
                                      if (choice == 'Edit') {
                                        _showEditDialog(claim);
                                      } else if (choice == 'Delete') {
                                        _deleteExpenseClaim(claimId); // Use checked claimId
                                      }
                                    },
                                    itemBuilder: (BuildContext context) {
                                      return {'Edit', 'Delete'}.map((String choice) {
                                        return PopupMenuItem<String>(
                                          value: choice,
                                          child: Text(choice),
                                        );
                                      }).toList();
                                    },
                                  )
                              ],
                            ),
                            const Divider(height: 12, thickness: 1), // Separator

                            // Details Section
                            if (_userRole == 'ADMIN' || _userRole == 'MANAGER')
                              Text('Submitted by: $username', style: TextStyle(color: Colors.grey[700])),
                            Text('Date: $date', style: TextStyle(color: Colors.grey[700])),
                            Text('Category: $category', style: TextStyle(color: Colors.grey[700])),
                            if (description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('Description: $description'),
                              ),

                            // Conditional Action Buttons
                            if (canTakeAction)
                              Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: isProcessing // Show loading or buttons
                                    ? const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                                      label: const Text('Approve', style: TextStyle(color: Colors.green)),
                                      onPressed: () => _approveClaim(claimId), // Use checked claimId
                                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                                      label: const Text('Reject', style: TextStyle(color: Colors.red)),
                                      onPressed: () => _rejectClaim(claimId), // Use checked claimId
                                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
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
            // Optional Pagination Controls
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExpenseClaimScreen(token: widget.token),
            ),
            // Refresh list when returning from the add/edit screen
          ).then((value) {
            // Check if a value was returned indicating success (optional)
            if (value == true) { // You might return true from ExpenseClaimScreen on success
              _fetchExpenseClaims();
            } else {
              // Optionally refresh even if no specific value returned
              _fetchExpenseClaims();
            }
          });
        },
        child: const Icon(Icons.add),
        tooltip: 'Add Expense Claim',
        backgroundColor: Colors.blue[700], // Match AppBar color
      ),
    );
  }}