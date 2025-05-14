import 'package:flutter/material.dart';

class LeaveRequestDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> leaveRequest;

  const LeaveRequestDetailsScreen({Key? key, required this.leaveRequest}) : super(key: key);

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      case 'PENDING':
        return Icons.hourglass_top;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String leaveType = leaveRequest['leaveType'] ?? 'N/A';
    final String startDate = _formatDate(leaveRequest['startDate']);
    final String endDate = _formatDate(leaveRequest['endDate']);
    final String status = leaveRequest['status'] ?? 'N/A';
    final int userId = leaveRequest['userId'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Leave Request Details"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: Colors.grey[100],
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.event_available, color: Colors.blue),
                  title: const Text("Leave Type"),
                  subtitle: Text(leaveType, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.date_range, color: Colors.green),
                  title: const Text("Start Date"),
                  subtitle: Text(startDate),
                ),
                ListTile(
                  leading: const Icon(Icons.date_range, color: Colors.red),
                  title: const Text("End Date"),
                  subtitle: Text(endDate),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
                  title: const Text("Status"),
                  subtitle: Chip(
                    label: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white)),
                    backgroundColor: _getStatusColor(status),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.deepPurple),
                  title: const Text("User ID"),
                  subtitle: Text(userId.toString()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
