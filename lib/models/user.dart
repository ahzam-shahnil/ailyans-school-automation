/// User model for school automation system operators.
/// Maps to the `Users` SQLite table.
class User {
  final int id;
  final String name;
  final String? designation;
  final String? cnic;
  final String password;
  final String? branch;
  final String? address;
  final String? mobile1;
  final String? mobile2;
  final int userLevel;
  final String? remarks;
  final bool isActive;

  const User({
    required this.id,
    required this.name,
    this.designation,
    this.cnic,
    required this.password,
    this.branch,
    this.address,
    this.mobile1,
    this.mobile2,
    this.userLevel = 1,
    this.remarks,
    this.isActive = true,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['ID'] as int,
      name: map['Name'] as String,
      designation: map['Desig'] as String?,
      cnic: map['CNIC'] as String?,
      password: map['Pwd'] as String,
      branch: map['Br'] as String?,
      address: map['Address'] as String?,
      mobile1: map['Mobile1'] as String?,
      mobile2: map['Mobile2'] as String?,
      userLevel: map['UserLvl'] as int? ?? 1,
      remarks: map['Remarks'] as String?,
      isActive: map['IsActive'] == null ? true : (map['IsActive'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'Name': name,
      'Desig': designation,
      'CNIC': cnic,
      'Pwd': password,
      'Br': branch,
      'Address': address,
      'Mobile1': mobile1,
      'Mobile2': mobile2,
      'UserLvl': userLevel,
      'Remarks': remarks,
      'IsActive': isActive ? 1 : 0,
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? designation,
    String? cnic,
    String? password,
    String? branch,
    String? address,
    String? mobile1,
    String? mobile2,
    int? userLevel,
    String? remarks,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      cnic: cnic ?? this.cnic,
      password: password ?? this.password,
      branch: branch ?? this.branch,
      address: address ?? this.address,
      mobile1: mobile1 ?? this.mobile1,
      mobile2: mobile2 ?? this.mobile2,
      userLevel: userLevel ?? this.userLevel,
      remarks: remarks ?? this.remarks,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          designation == other.designation &&
          cnic == other.cnic &&
          password == other.password &&
          branch == other.branch &&
          address == other.address &&
          mobile1 == other.mobile1 &&
          mobile2 == other.mobile2 &&
          userLevel == other.userLevel &&
          remarks == other.remarks &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      designation.hashCode ^
      cnic.hashCode ^
      password.hashCode ^
      branch.hashCode ^
      address.hashCode ^
      mobile1.hashCode ^
      mobile2.hashCode ^
      userLevel.hashCode ^
      remarks.hashCode ^
      isActive.hashCode;

  @override
  String toString() {
    return 'User(id: $id, name: $name, designation: $designation, userLevel: $userLevel, isActive: $isActive)';
  }
}
