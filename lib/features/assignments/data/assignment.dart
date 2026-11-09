import '../../../core/utils/json_readers.dart';

/// `AssignmentResponse` (FR-DR02): one driver–vehicle assignment. An open
/// assignment (`unassignedAt == null`, `current == true`) is the current one.
class Assignment {
  const Assignment({
    required this.id,
    required this.vehicleId,
    required this.vehicleNumber,
    required this.driverId,
    required this.driverName,
    required this.current,
    this.assignedAt,
    this.unassignedAt,
    this.assignedBy,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    final unassignedAt = JsonReaders.timestamp(json['unassignedAt']);
    return Assignment(
      id: JsonReaders.requireInt(json, 'id'),
      vehicleId: JsonReaders.requireInt(json, 'vehicleId'),
      vehicleNumber: json['vehicleNumber'] as String? ?? '',
      driverId: JsonReaders.requireInt(json, 'driverId'),
      driverName: json['driverName'] as String? ?? '',
      assignedAt: JsonReaders.timestamp(json['assignedAt']),
      unassignedAt: unassignedAt,
      current: JsonReaders.boolOr(json['current'], unassignedAt == null),
      assignedBy: json['assignedBy'] as String?,
    );
  }

  final int id;
  final int vehicleId;
  final String vehicleNumber;
  final int driverId;
  final String driverName;
  final DateTime? assignedAt;
  final DateTime? unassignedAt;
  final bool current;
  final String? assignedBy;
}
