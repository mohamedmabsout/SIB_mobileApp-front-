import 'package:sib_expense_app/models/client.dart'; // Assuming Client model exists

// Ensure these names EXACTLY match the backend enum names (case-sensitive)
enum ProjectStatus {
  PLANNING,
  ACTIVE,
  ON_HOLD,
  COMPLETED
}
// --- END ENUM DEFINITION ---

class Project {
  final int id;
  final String? projectCode;
  final String projectName;
  final String? description;
  final double? budget;
  final String? startDate;
  final String? endDate;
  final String? status; // The raw string from JSON
  final int? clientId;
  final String? clientCompanyName;
  Project({
    required this.id,
    this.projectCode,
    required this.projectName,
    this.description,
    this.budget,
    this.startDate,
    this.endDate,
    this.status,
    this.clientId,
    this.clientCompanyName,
  });

  // Helper getter to convert the status string to the enum
  // Returns null if the string doesn't match any enum value
  ProjectStatus? get statusEnum {
    if (status == null) return null;
    try {
      return ProjectStatus.values.firstWhere((e) => e.name == status);
    } catch (e) {
      print("Warning: Unknown project status string received: $status");
      return null; // Or return a default status like ProjectStatus.PLANNING
    }
  }


  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as int? ?? 0,
      projectCode: json['projectCode'] as String?,
      projectName: json['projectName'] as String? ?? 'Unknown Project',
      description: json['description'] as String?,
      budget: (json['budget'] as num?)?.toDouble(),
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      status: json['status'] as String?, // Keep receiving as String
        clientId: json['clientId'] as int?,
        clientCompanyName: json['clientCompanyName'] as String?,

    );
  }
}