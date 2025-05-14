// lib/models/dashboard_data_dto.dart

// Class for individual alerts
// lib/models/dashboard_data_dto.dart

class AlertDto {
  final String title;
  final String description;
  final String priority;
  // --- NEW FIELDS ---
  final String? targetType; // Make nullable if not always present
  final int? targetId;     // Make nullable (use int for ID from JSON)
  // --- END NEW FIELDS ---

  AlertDto({
    required this.title,
    required this.description,
    required this.priority,
    this.targetType, // Add to constructor
    this.targetId,   // Add to constructor
  });

  factory AlertDto.fromJson(Map<String, dynamic> json) {
    return AlertDto(
      title: json['title'] as String? ?? 'Alert',
      description: json['description'] as String? ?? 'No details.',
      priority: json['priority'] as String? ?? 'INFO',
      // --- PARSE NEW FIELDS ---
      targetType: json['targetType'] as String?,
      targetId: json['targetId'] as int?, // Assuming ID from backend is int/long
      // --- END PARSE ---
    );
  }
}

// Class for the overall dashboard data structure
class DashboardDataDto {
  // Common KPIs
  final int? totalActiveProjects;
  final int? myActiveProjects;
  final int? pendingExpenseClaims;

  // Admin/Manager Specific
  final int? totalUsers;
  final int? pendingLeaveRequests;
  final Map<String, dynamic>? teamAssignments;
  final Map<String, dynamic>? teamExpenseClaims;
  final int? myActiveAssignments;
  final int? myAssignedEquipmentCount;
  // Employee Specific
  final int? myOpenTasks;
  final int? myApprovedLeaveDaysThisYear;
  final int? finishedTasks;

  // Alerts
  final List<AlertDto>? alerts;

  DashboardDataDto({this.myActiveProjects,
    this.finishedTasks,
    this.myActiveAssignments, this.myAssignedEquipmentCount,
      this.totalActiveProjects,
    this.pendingExpenseClaims,
    this.totalUsers,
    this.pendingLeaveRequests,
    this.teamAssignments,
    this.teamExpenseClaims,
    this.myOpenTasks,
    this.myApprovedLeaveDaysThisYear,
    this.alerts,
  });

  // Factory constructor to create an instance from JSON
  factory DashboardDataDto.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse map values, ensuring keys are Strings
    Map<String, dynamic>? parseMap(dynamic data) {
      if (data is Map) {
        // Ensure keys are Strings and values are dynamic (or cast to int if sure)
        return data.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    }

    // Helper function to safely parse List<AlertDto>
    List<AlertDto>? parseAlerts(dynamic alertList) {
      if (alertList is List) {
        return alertList
            .where((item) => item is Map<String, dynamic>) // Ensure items are maps
            .map((item) => AlertDto.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return null;
    }


    return DashboardDataDto(
      totalActiveProjects: json['totalActiveProjects'] as int?,
      myActiveProjects: json['myActiveProjects'] as int?,
      pendingExpenseClaims: json['pendingExpenseClaims'] as int?,
      totalUsers: json['totalUsers'] as int?,
      pendingLeaveRequests: json['pendingLeaveRequests'] as int?,
      teamAssignments: parseMap(json['teamAssignments']),
      teamExpenseClaims: parseMap(json['teamExpenseClaims']),
      myOpenTasks: json['myOpenTasks'] as int?,
      myAssignedEquipmentCount: json['myAssignedEquipmentCount'] as int?,
      myActiveAssignments: json['myActiveAssignments'] as int?,
      myApprovedLeaveDaysThisYear: json['myApprovedLeaveDaysThisYear'] as int?,
      alerts: parseAlerts(json['alerts']), // Use helper for safe parsing
    );
  }
}