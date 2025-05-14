// lib/models/client.dart

class Client {
  final int id; // Assuming backend ID is int/long
  final String companyName;
  final String? contactPerson; // Optional fields marked with ?
  final String? email;
  final String? phone;

  Client({
    required this.id,
    required this.companyName,
    this.contactPerson,
    this.email,
    this.phone,
  });

  // Factory constructor to create a Client instance from JSON data
  factory Client.fromJson(Map<String, dynamic> json) {
    // Perform null checks and type casting safely
    return Client(
      id: json['id'] as int? ?? 0, // Provide a default ID or handle null appropriately
      companyName: json['companyName'] as String? ?? 'Unknown Company', // Provide a default
      contactPerson: json['contactPerson'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  // Optional: Method to convert Client instance back to JSON (if needed for sending data)
  Map<String, dynamic> toJson() {
    return {
      'id': id, // Usually you don't send ID when creating/updating unless specifically needed
      'companyName': companyName,
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
    };
  }
}