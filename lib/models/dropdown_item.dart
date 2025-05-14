class DropdownItem {
  final int id; // Or String if your IDs are strings
  final String name;

  DropdownItem({required this.id, required this.name});

  // Optional: Override equals and hashCode if needed for comparison
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DropdownItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}