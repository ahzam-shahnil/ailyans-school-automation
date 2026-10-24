/// Represents an institutional bank account record from BankInfo.
class BankAccountRow {
  final int bankInfoId;
  final String bankName;
  final String address;
  final String branch;
  final String acctNo;
  final String acctTitle;
  final String acctType;
  final int acctStatus;
  final String bankDefault;

  const BankAccountRow({
    required this.bankInfoId,
    required this.bankName,
    this.address = '',
    this.branch = '',
    required this.acctNo,
    this.acctTitle = '',
    this.acctType = '',
    this.acctStatus = 1,
    this.bankDefault = 'N',
  });

  bool get isActive => acctStatus == 1;
  bool get isDefault => bankDefault == 'Y';

  factory BankAccountRow.fromMap(Map<String, dynamic> map) {
    return BankAccountRow(
      bankInfoId: map['BankInfoID'] as int,
      bankName: map['BankName'] as String? ?? '',
      address: map['Address'] as String? ?? '',
      branch: map['Branch'] as String? ?? '',
      acctNo: map['AcctNo'] as String? ?? '',
      acctTitle: map['AcctTitle'] as String? ?? '',
      acctType: map['AcctType'] as String? ?? '',
      acctStatus: map['AcctStatus'] as int? ?? 1,
      bankDefault: map['BankDefault'] as String? ?? 'N',
    );
  }
}
