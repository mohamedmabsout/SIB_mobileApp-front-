class Task {
  final int id;
  final String taskName;
  final String? description;
  final String? dueDate;
  final String? status;
  final String? priority;
  // Store related info directly as received from API
  final int? projectId;
  final String? projectName;
  final int? assignedUserId;
  final String? assignedUsername;
  // Remove these if you don't need the full nested objects in this model:
  // final Project? project;
  // final UserViewDTO? assignedToUser;

  Task({
    required this.id,
    required this.taskName,
    this.description,
    this.dueDate,
    this.status,
    this.priority,
    this.projectId,        // Add to constructor
    this.projectName,      // Add to constructor
    this.assignedUserId,   // Add to constructor
    this.assignedUsername, // Add to constructor
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int? ?? 0,
      taskName: json['taskName'] as String? ?? 'Unnamed Task',
      description: json['description'] as String?,
      dueDate: json['dueDate'] as String?,
      status: json['status'] as String?,
      priority: json['priority'] as String?,
      // --- FIX: Read top-level fields ---
      projectId: json['projectId'] as int?,
      projectName: json['projectName'] as String?,
      assignedUserId: json['assignedUserId'] as int?,
      assignedUsername: json['assignedUsername'] as String?,
      // --- END FIX ---
    );
  }
}