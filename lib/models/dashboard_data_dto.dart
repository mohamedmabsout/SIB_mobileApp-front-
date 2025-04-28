// lib/models/dashboard_data_dto.dart

// Class for individual alerts
class AlertDto {
  final String title;
  final String description;
  final String priority; // e.g., "HIGH", "MEDIUM", "LOW", "INFO"

  AlertDto({
    required this.title,
    required this.description,
    required this.priority,
  });

  // Factory constructor to create an instance from JSON
  factory AlertDto.fromJson(Map<String, dynamic> json) {
    return AlertDto(
      title: json['title'] as String? ?? 'No Title', // Add null checks and defaults
      description: json['description'] as String? ?? '',
      priority: json['priority'] as String? ?? 'INFO',
    );
  }
}

// Class for the overall dashboard data structure
class DashboardDataDto {
  // Common KPIs
  final int? totalActiveProjects;
  final int? pendingExpenseClaims;

  // Admin/Manager Specific
  final int? totalUsers;
  final int? pendingLeaveRequests;
  final Map<String, dynamic>? teamAssignments;
  final Map<String, dynamic>? teamExpenseClaims;

  // Employee Specific
  final int? myOpenTasks;
  final int? myApprovedLeaveDaysThisYear;

  // Alerts
  final List<AlertDto>? alerts;

  DashboardDataDto({
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
      pendingExpenseClaims: json['pendingExpenseClaims'] as int?,
      totalUsers: json['totalUsers'] as int?,
      pendingLeaveRequests: json['pendingLeaveRequests'] as int?,
      teamAssignments: parseMap(json['teamAssignments']),
      teamExpenseClaims: parseMap(json['teamExpenseClaims']),
      myOpenTasks: json['myOpenTasks'] as int?,
      myApprovedLeaveDaysThisYear: json['myApprovedLeaveDaysThisYear'] as int?,
      alerts: parseAlerts(json['alerts']), // Use helper for safe parsing
    );
  }
}