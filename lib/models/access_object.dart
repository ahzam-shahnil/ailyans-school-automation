/// AccessObject model representing securable application modules.
/// Maps to the `AccObj` SQLite table.
class AccessObject {
  final int objId;
  final String objName;
  final String displayName;

  const AccessObject({
    required this.objId,
    required this.objName,
    required this.displayName,
  });

  factory AccessObject.fromMap(Map<String, dynamic> map) {
    return AccessObject(
      objId: map['ObjID'] as int,
      objName: (map['ObjName'] as String?) ?? '',
      displayName: (map['DisplayName'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'ObjID': objId, 'ObjName': objName, 'DisplayName': displayName};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessObject &&
          runtimeType == other.runtimeType &&
          objId == other.objId;

  @override
  int get hashCode => objId.hashCode;

  @override
  String toString() =>
      'AccessObject(objId: $objId, objName: $objName, displayName: $displayName)';
}
