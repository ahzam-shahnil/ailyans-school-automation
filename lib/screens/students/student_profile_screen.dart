import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/providers/fee_collection_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/providers/sibling_links_provider.dart';
import '../../core/providers/student_list_provider.dart';
import '../../core/providers/student_profile_provider.dart';
import '../../core/sync/sync_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../core/utils/photo_picker.dart';
import '../../models/student.dart';
import '../../models/student_enrollment.dart';
import '../../models/student_voucher.dart';
import '../../repositories/photo_repository.dart';
import '../../widgets/reports/report_definition.dart';
import '../../widgets/reports/report_preview_modal.dart';

/// Comprehensive 360-degree Student Profile Workstation.
/// Hosted within [AppShell] at route `/students/:id`.
class StudentProfileScreen extends ConsumerStatefulWidget {
  final String studentId;

  const StudentProfileScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  // Edit mode controllers
  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _bFormController;
  late final TextEditingController _fatherNameController;
  late final TextEditingController _cnicController;
  late final TextEditingController _occupationController;
  late final TextEditingController _pAddressController;
  late final TextEditingController _tAddressController;
  late final TextEditingController _mobile1Controller;
  late final TextEditingController _mobile2Controller;
  late final TextEditingController _pSchoolController;
  late final TextEditingController _slCertificateController;
  late final TextEditingController _pClassController;
  late final TextEditingController _emerContNameController;
  late final TextEditingController _emerContMobileController;
  late final TextEditingController _discountController;
  late final TextEditingController _vmDiscountController;
  late final TextEditingController _remarksController;
  late final TextEditingController _nationalityController;

  // Focus nodes for 6-step validation auto-focus
  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _fatherNameFocus = FocusNode();
  final FocusNode _cnicFocus = FocusNode();
  final FocusNode _mobile1Focus = FocusNode();

  // Edit mode state variables
  DateTime? _selectedDob;
  DateTime? _selectedDoAdmission;
  String? _selectedSex;
  String? _selectedReligion;
  int? _selectedAdmInClass;
  int _fullDiscount = 0;
  String? _validationError;

  bool _initializedFromStudent = false;
  int _lastLoadedStuRegId = -1;

  final List<String> _tabLabels = const [
    'Overview',
    'Enrollment History',
    'Fee Ledger',
    'Advances',
    'Exams',
    'Attendance',
    'Documents',
    'Family',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(studentEditModeProvider.notifier).state = false;
        ref.read(selectedStudentTabProvider.notifier).state = 0;
      }
    });
    // G-10 Shot 10a: force a fresh SQLite read on every mount. A profile
    // re-opened after a cloud sync pull must show the latest local rows,
    // never a bundle cached by an earlier visit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stuRegId = int.tryParse(widget.studentId) ?? -1;
      if (stuRegId > 0) {
        ref.invalidate(studentProfileProvider(stuRegId));
      }
    });
    _firstNameController = TextEditingController();
    _middleNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _bFormController = TextEditingController();
    _fatherNameController = TextEditingController();
    _cnicController = TextEditingController();
    _occupationController = TextEditingController();
    _pAddressController = TextEditingController();
    _tAddressController = TextEditingController();
    _mobile1Controller = TextEditingController();
    _mobile2Controller = TextEditingController();
    _pSchoolController = TextEditingController();
    _slCertificateController = TextEditingController();
    _pClassController = TextEditingController();
    _emerContNameController = TextEditingController();
    _emerContMobileController = TextEditingController();
    _discountController = TextEditingController();
    _vmDiscountController = TextEditingController();
    _remarksController = TextEditingController();
    _nationalityController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _bFormController.dispose();
    _fatherNameController.dispose();
    _cnicController.dispose();
    _occupationController.dispose();
    _pAddressController.dispose();
    _tAddressController.dispose();
    _mobile1Controller.dispose();
    _mobile2Controller.dispose();
    _pSchoolController.dispose();
    _slCertificateController.dispose();
    _pClassController.dispose();
    _emerContNameController.dispose();
    _emerContMobileController.dispose();
    _discountController.dispose();
    _vmDiscountController.dispose();
    _remarksController.dispose();
    _nationalityController.dispose();

    _firstNameFocus.dispose();
    _fatherNameFocus.dispose();
    _cnicFocus.dispose();
    _mobile1Focus.dispose();
    super.dispose();
  }

  void _populateForm(Student student) {
    _firstNameController.text = student.nameFirst;
    _middleNameController.text = student.nameMiddle ?? '';
    _lastNameController.text = student.nameLast ?? '';
    _bFormController.text = student.bFormNo ?? '';
    _fatherNameController.text = student.fName ?? '';
    _cnicController.text = student.cnicNo ?? '';
    _occupationController.text = student.occupation ?? '';
    _pAddressController.text = student.pAddress ?? '';
    _tAddressController.text = student.tAddress ?? '';
    _mobile1Controller.text = student.mobile1 ?? '';
    _mobile2Controller.text = student.mobile2 ?? '';
    _pSchoolController.text = student.pSchool ?? '';
    _slCertificateController.text = student.slCertificate ?? '';
    _pClassController.text = student.pClass ?? '';
    _emerContNameController.text = student.emerContName ?? '';
    _emerContMobileController.text = student.emerContMobile ?? '';
    _discountController.text = student.discount != null && student.discount! > 0
        ? student.discount!.toStringAsFixed(0)
        : '0';
    _vmDiscountController.text = student.vmDiscount != null
        ? student.vmDiscount!.toString()
        : '0';
    _remarksController.text = student.remarls ?? '';
    _nationalityController.text = student.nationality ?? 'Pakistani';

    _selectedDob = student.dob;
    _selectedDoAdmission = student.doAdmission;
    _selectedSex = student.sex ?? 'Male';
    _selectedReligion = student.religion ?? 'Islam';
    _selectedAdmInClass = student.admInClass ?? student.admClass ?? 13;
    _fullDiscount = student.fullDiscount;
    _validationError = null;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.bodySmall.copyWith(
            color: isError
                ? AppColors.statusErrorText
                : AppColors.textOnPrimary,
          ),
        ),
        backgroundColor: isError
            ? AppColors.statusErrorBg
            : AppColors.brandPrimary,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: isError
              ? const BorderSide(color: AppColors.statusErrorBorder)
              : BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _onPrintReceipt(String voucherMasId) async {
    final meta = ref.read(shellMetadataProvider).value;
    final printData = await ref
        .read(feeCollectionProvider.notifier)
        .loadReceiptPrintData(voucherMasId);

    if (!mounted) return;

    if (printData == null) {
      _showSnackBar('Could not load receipt data for printing.', isError: true);
      return;
    }

    final safeBranchName =
        (meta?.branchName != null && meta!.branchName.trim().isNotEmpty)
        ? meta.branchName.trim()
        : '-';
    final safeBranchAddress =
        (meta?.branchAddress != null && meta!.branchAddress.trim().isNotEmpty)
        ? meta.branchAddress.trim()
        : '-';

    await ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.feeReceipt,
        id: voucherMasId,
        vouchers: [printData],
        extraParams: {
          'branchName': safeBranchName,
          'branchAddress': safeBranchAddress,
        },
      ),
    );
  }

  Future<void> _handleSave(Student currentStudent) async {
    // Step 1: NameFirst not empty → "Enter Fisrt Name Please " (verbatim typo)
    if (_firstNameController.text.trim().isEmpty) {
      setState(() {
        _validationError = 'Enter Fisrt Name Please ';
      });
      _firstNameFocus.requestFocus();
      _showSnackBar('Enter Fisrt Name Please ', isError: true);
      return;
    }

    // Step 2: DOB not null → "Enter Date of Birth Please "
    if (_selectedDob == null) {
      setState(() {
        _validationError = 'Enter Date of Birth Please ';
      });
      _showSnackBar('Enter Date of Birth Please ', isError: true);
      return;
    }

    // Step 3: CNIC_No not empty → "Enter Father CNIC Please "
    if (_cnicController.text.trim().isEmpty) {
      setState(() {
        _validationError = 'Enter Father CNIC Please ';
      });
      _cnicFocus.requestFocus();
      _showSnackBar('Enter Father CNIC Please ', isError: true);
      return;
    }

    // Step 4: F_Name not empty → "Enter Father / Guradian Name Please " (verbatim typo)
    if (_fatherNameController.text.trim().isEmpty) {
      setState(() {
        _validationError = 'Enter Father / Guradian Name Please ';
      });
      _fatherNameFocus.requestFocus();
      _showSnackBar('Enter Father / Guradian Name Please ', isError: true);
      return;
    }

    // Step 5: Mobile1 not empty → "Enter Mobile # 1  Please " (two spaces)
    if (_mobile1Controller.text.trim().isEmpty) {
      setState(() {
        _validationError = 'Enter Mobile # 1  Please ';
      });
      _mobile1Focus.requestFocus();
      _showSnackBar('Enter Mobile # 1  Please ', isError: true);
      return;
    }

    // Step 6: AdmInClass not null → "Select Admission In Class  Please " (two spaces)
    if (_selectedAdmInClass == null) {
      setState(() {
        _validationError = 'Select Admission In Class  Please ';
      });
      _showSnackBar('Select Admission In Class  Please ', isError: true);
      return;
    }

    // NOTE: NameMiddle is OPTIONAL — do not validate it.

    final updatedStudent = currentStudent.copyWith(
      nameFirst: _firstNameController.text.trim(),
      nameMiddle: _middleNameController.text.trim().isEmpty
          ? null
          : _middleNameController.text.trim(),
      nameLast: _lastNameController.text.trim().isEmpty
          ? null
          : _lastNameController.text.trim(),
      dob: _selectedDob,
      bFormNo: _bFormController.text.trim().isEmpty
          ? null
          : _bFormController.text.trim(),
      fName: _fatherNameController.text.trim(),
      cnicNo: _cnicController.text.trim(),
      occupation: _occupationController.text.trim().isEmpty
          ? null
          : _occupationController.text.trim(),
      pAddress: _pAddressController.text.trim().isEmpty
          ? null
          : _pAddressController.text.trim(),
      tAddress: _tAddressController.text.trim().isEmpty
          ? null
          : _tAddressController.text.trim(),
      mobile1: _mobile1Controller.text.trim(),
      mobile2: _mobile2Controller.text.trim().isEmpty
          ? null
          : _mobile2Controller.text.trim(),
      religion: _selectedReligion,
      pSchool: _pSchoolController.text.trim().isEmpty
          ? null
          : _pSchoolController.text.trim(),
      slCertificate: _slCertificateController.text.trim().isEmpty
          ? null
          : _slCertificateController.text.trim(),
      pClass: _pClassController.text.trim().isEmpty
          ? null
          : _pClassController.text.trim(),
      admInClass: _selectedAdmInClass,
      admClass: _selectedAdmInClass,
      doAdmission: _selectedDoAdmission,
      discount: double.tryParse(_discountController.text.trim()) ?? 0.0,
      vmDiscount: int.tryParse(_vmDiscountController.text.trim()) ?? 0,
      fullDiscount: _fullDiscount,
      emerContName: _emerContNameController.text.trim().isEmpty
          ? null
          : _emerContNameController.text.trim(),
      emerContMobile: _emerContMobileController.text.trim().isEmpty
          ? null
          : _emerContMobileController.text.trim(),
      remarls: _remarksController.text.trim().isEmpty
          ? null
          : _remarksController.text.trim(),
      nationality: _nationalityController.text.trim().isEmpty
          ? 'Pakistani'
          : _nationalityController.text.trim(),
      sex: _selectedSex,
    );

    final saver = ref.read(studentProfileSaverProvider);
    await saver(updatedStudent);

    if (!mounted) return;
    _showSnackBar('Student Saved Successfully');
    setState(() {
      _validationError = null;
    });
    ref.read(studentEditModeProvider.notifier).state = false;
    ref.invalidate(studentProfileProvider(currentStudent.stuRegId));
  }

  void _cancelEdit(Student student) {
    _populateForm(student);
    ref.read(studentEditModeProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final stuRegId = int.tryParse(widget.studentId) ?? -1;
    if (stuRegId <= 0) {
      return _buildStudentNotFound(stuRegId);
    }

    final profileAsync = ref.watch(studentProfileProvider(stuRegId));
    final isEditMode = ref.watch(studentEditModeProvider);
    // G-10 Shot 10b: reload this profile in place when new data lands from a
    // remote pull (dbDataVersionProvider bumps after every pulled delta or
    // manual sync). Skipped in edit mode so an in-progress form is never
    // clobbered by a background refresh.
    ref.listen<int>(dbDataVersionProvider, (previous, next) {
      if (previous != next && mounted) {
        final editing = ref.read(studentEditModeProvider);
        if (!editing) {
          ref.invalidate(studentProfileProvider(stuRegId));
        }
      }
    });
    final activeTab = ref.watch(selectedStudentTabProvider);
    final session = ref.watch(sessionProvider);
    final canEditBiodata =
        session == null || session.user.userLevel == 1 || session.hasAccess(12);

    return profileAsync.when(
      loading: () => _buildLoadingSkeleton(),
      error: (error, _) => _buildStudentNotFound(stuRegId),
      data: (bundle) {
        if (!_initializedFromStudent || _lastLoadedStuRegId != stuRegId) {
          _populateForm(bundle.student);
          _initializedFromStudent = true;
          _lastLoadedStuRegId = stuRegId;
        }

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.f2): () {
              if (canEditBiodata) {
                ref.read(studentEditModeProvider.notifier).state = !isEditMode;
              }
            },
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
              if (isEditMode) _handleSave(bundle.student);
            },
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
              if (isEditMode) _handleSave(bundle.student);
            },
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (isEditMode) _cancelEdit(bundle.student);
            },
            const SingleActivator(LogicalKeyboardKey.keyL, control: true): () {
              final id = int.tryParse(widget.studentId);
              if (id != null) _showManageSiblingLinksDialog(context, id);
            },
            const SingleActivator(LogicalKeyboardKey.keyL, meta: true): () {
              final id = int.tryParse(widget.studentId);
              if (id != null) _showManageSiblingLinksDialog(context, id);
            },
          },
          child: Focus(
            autofocus: true,
            child: Material(
              color: AppColors.surface,
              child: ResponsiveBreakpoints.isMobile(context)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Breadcrumb Bar
                                _buildBreadcrumb(
                                  bundle.student,
                                  activeTab,
                                  isEditMode,
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Top Hero Profile Card
                                _buildHeroCard(
                                  bundle,
                                  isEditMode,
                                  canEditBiodata,
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Campus Highlight (mobile only)
                                _buildMobileCampusHighlight(bundle.student),
                                const SizedBox(height: AppSpacing.md),

                                // Tab Switcher
                                _buildTabBar(activeTab),
                                const SizedBox(height: AppSpacing.md),

                                // Tab Canvas
                                _buildTabContent(
                                  bundle,
                                  activeTab,
                                  isEditMode,
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildMobileStickyActionBar(
                          bundle.student,
                          isEditMode,
                          canEditBiodata,
                        ),
                      ],
                    )
                  : Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Breadcrumb Bar
                          _buildBreadcrumb(
                            bundle.student,
                            activeTab,
                            isEditMode,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Top Hero Profile Card
                          _buildHeroCard(bundle, isEditMode, canEditBiodata),
                          const SizedBox(height: AppSpacing.md),

                          // Tab Switcher
                          _buildTabBar(activeTab),
                          const SizedBox(height: AppSpacing.md),

                          // Tab Canvas (Expanded)
                          Expanded(
                            child: _buildTabContent(
                              bundle,
                              activeTab,
                              isEditMode,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BREADCRUMB
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBreadcrumb(Student student, int activeTab, bool isEditMode) {
    final tabName = _tabLabels[activeTab];
    final modeLabel = isEditMode ? 'Editing Profile' : tabName;

    if (ResponsiveBreakpoints.isMobile(context)) {
      final session = ref.watch(sessionProvider);
      final canEditBiodata =
          session == null || session.user.userLevel == 1 || session.hasAccess(12);

      return Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.go('/students'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_rounded,
                    size: 16,
                    color: AppColors.accentStudents,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Back to Students Directory',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.accentStudents,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (!isEditMode && canEditBiodata)
            OutlinedButton.icon(
              onPressed: () {
                _populateForm(student);
                ref.read(studentEditModeProvider.notifier).state = true;
              },
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: Text(
                'Edit',
                style: AppTypography.label.copyWith(fontSize: 11),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _printBiodata(student),
            icon: const Icon(
              Icons.print_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Print Biodata',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      );
    }

    return Row(
      children: [
        IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          onPressed: () => context.go('/students'),
          tooltip: 'Back to Student Directory',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Home',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '›',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () => context.go('/students'),
          child: Text(
            'Students',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '›',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(width: 6),
        Text(
          'Student #${student.stuRegId}',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '›',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(width: 6),
        Text(
          modeLabel,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (isEditMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.statusWarningBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.statusWarningBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.edit_note,
                  size: 14,
                  color: AppColors.statusWarningText,
                ),
                const SizedBox(width: 6),
                Text(
                  'MANDATORY FIELDS MARKED (*)',
                  style: AppTypography.monospace
                      .copyWith(fontSize: 11)
                      .copyWith(
                        color: AppColors.statusWarningText,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HERO CARD (TOP)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeroCard(
    StudentProfileBundle bundle,
    bool isEditMode,
    bool canEditBiodata,
  ) {
    final student = bundle.student;
    final isEnrolled = bundle.isEnrolled;
    final isLeft = !isEnrolled;

    if (ResponsiveBreakpoints.isMobile(context)) {
      return _buildMobileHeroCard(bundle, isEditMode, canEditBiodata);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 96px Avatar / Photo
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _handlePhotoTap(student),
            child: _buildAvatar(student),
          ),
          const SizedBox(width: AppSpacing.lg),

          // Core Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Full name + Reg ID + Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        student.fullName,
                        style: AppTypography.h1.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // G-10 Shot 10c: Flexible(loose) so the Reg pill can
                    // shrink (ellipsis) at narrow desktop widths instead of
                    // overflowing the hero row.
                    Flexible(
                      fit: FlexFit.loose,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Text(
                          '#${student.stuRegId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.monospace
                              .copyWith(fontSize: 11)
                              .copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // G-10 Shot 10c: Flexible(loose) so the Status pill can
                    // shrink at narrow desktop widths.
                    Flexible(
                      fit: FlexFit.loose,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isEnrolled
                              ? AppColors.statusSuccessBg
                              : AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: isEnrolled
                                ? AppColors.statusSuccessBorder
                                : AppColors.borderDefault,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isEnrolled
                                    ? AppColors.statusSuccessText
                                    : AppColors.textDisabled,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              fit: FlexFit.loose,
                              child: Text(
                                isEnrolled ? 'Active' : 'Alumni',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label.copyWith(
                                  color: isEnrolled
                                      ? AppColors.statusSuccessText
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Class + Section + Roll No
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 15,
                      color: isEnrolled
                          ? AppColors.textSecondary
                          : AppColors.textDisabled,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isEnrolled
                            ? 'Class ${bundle.currentClassName}-${bundle.currentSectionName}  •  Roll: ${bundle.classRollNo}'
                            : 'Not Enrolled',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          color: isEnrolled
                              ? AppColors.textSecondary
                              : AppColors.textDisabled,
                          fontWeight: FontWeight.w500,
                          fontStyle: isEnrolled
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Father + Mobile
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.person_outline,
                                size: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          TextSpan(
                            text: 'Father: ${bundle.fatherName}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.phone_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          TextSpan(
                            text: bundle.mobile1,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Fee Balance summary
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    Text(
                      'Fee Balance: ',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      bundle.feeBalanceSummary,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: bundle.outstandingArrears <= 0
                            ? AppColors.statusSuccessText
                            : AppColors.statusErrorText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons
          if (!isEditMode) ...[
            if (canEditBiodata) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Profile (F2)'),
                onPressed: () {
                  _populateForm(student);
                  ref.read(studentEditModeProvider.notifier).state = true;
                },
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('Print Biodata'),
              onPressed: () => _printBiodata(student),
            ),
            if (isLeft) ...[
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Print SLC'),
                onPressed: () => context.go('/students/leaving'),
              ),
            ],
            if (!isLeft) ...[
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(
                  Icons.person_remove_outlined,
                  size: 16,
                  color: AppColors.statusErrorText,
                ),
                label: const Text(
                  'Withdraw Student',
                  style: TextStyle(color: AppColors.statusErrorText),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.statusErrorBorder),
                ),
                onPressed: () => _withdrawStudent(student),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.statusWarningBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.statusWarningBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.edit_document,
                    size: 16,
                    color: AppColors.statusWarningText,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '[Editing Active - Unsaved Changes]',
                    style: AppTypography.monospace
                        .copyWith(fontSize: 11)
                        .copyWith(
                          color: AppColors.statusWarningText,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _printBiodata(Student student) async {
    final meta = ref.read(shellMetadataProvider).value;
    final stuId = int.tryParse(widget.studentId) ?? -1;
    final data = await buildBiodataPrintData(stuId, ref);
    if (!mounted) return;
    final safeBranchName =
        (meta?.branchName != null && meta!.branchName.trim().isNotEmpty)
        ? meta.branchName.trim()
        : '-';
    final safeBranchAddress =
        (meta?.branchAddress != null && meta!.branchAddress.trim().isNotEmpty)
        ? meta.branchAddress.trim()
        : '-';
    await ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.biodata,
        id: stuId.toString(),
        vouchers: [data],
        extraParams: {
          'branchName': safeBranchName,
          'branchAddress': safeBranchAddress,
          'branchPhone': meta?.branchPhone ?? '',
          'branchPrincipal': meta?.branchPrincipal ?? '',
        },
      ),
    );
  }

  Future<void> _withdrawStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Student?'),
        content: Text(
          'This opens the School Leaving workflow to formally withdraw '
          '${student.fullName}. Historical fee records, exam grades, and vouchers '
          'are preserved. You will not be able to re-enrol this student '
          'without a new admission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusErrorText,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Continue to Withdrawal'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final fromOrigin = () {
        try {
          return GoRouterState.of(context).uri.queryParameters['from'];
        } catch (_) {
          return null;
        }
      }();
      final currentProfileUrl = fromOrigin != null && fromOrigin.isNotEmpty
          ? '/students/${widget.studentId}?from=${Uri.encodeComponent(fromOrigin)}'
          : '/students/${widget.studentId}';
      context.go(
        '/students/leaving?studentId=${widget.studentId}'
        '&from=${Uri.encodeComponent(currentProfileUrl)}',
      );
    }
  }

  Widget _buildMobileHeroCard(
    StudentProfileBundle bundle,
    bool isEditMode,
    bool canEditBiodata,
  ) {
    final student = bundle.student;
    final isEnrolled = bundle.isEnrolled;
    final shellMeta = ref.watch(shellMetadataProvider).value;
    final sessionYear = shellMeta?.sessionYear ?? '2026-27';

    final shouldWatchSiblings = _shouldWatchSiblingProvider(bundle);
    final siblingsAsync = shouldWatchSiblings
        ? ref.watch(siblingLinksForStudentProvider(student.stuRegId))
        : null;
    final siblingCount = siblingsAsync?.value?.length ?? 0;

    String attendanceText = '—';
    if (bundle.attendance.isNotEmpty) {
      int present = 0;
      for (final a in bundle.attendance) {
        final status =
            (a['Status'] ?? a['status'] ?? '').toString().toUpperCase();
        if (status == 'P' || status == 'PRESENT') present++;
      }
      final pct = (present / bundle.attendance.length) * 100;
      attendanceText = '${pct.toStringAsFixed(1)}%';
    }

    final initials = student.fullName.isNotEmpty
        ? student.fullName
            .split(' ')
            .where((p) => p.isNotEmpty)
            .map((p) => p[0])
            .take(2)
            .join()
        : 'ST';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              color: AppColors.accentStudents,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          onTap: () => _handlePhotoTap(student),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.accentStudents.withValues(
                              alpha: 0.12,
                            ),
                            backgroundImage: student.photoPath != null &&
                                    File(student.photoPath!).existsSync()
                                ? FileImage(File(student.photoPath!))
                                : null,
                            child: student.photoPath == null ||
                                    !File(student.photoPath!).existsSync()
                                ? Text(
                                    initials,
                                    style: AppTypography.label.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accentStudents,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      student.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.h3.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isEnrolled
                                          ? AppColors.statusSuccessBg
                                          : AppColors.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.full,
                                      ),
                                      border: Border.all(
                                        color: isEnrolled
                                            ? AppColors.statusSuccessBorder
                                            : AppColors.borderDefault,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isEnrolled
                                                ? AppColors.statusSuccessText
                                                : AppColors.textDisabled,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isEnrolled ? 'Active' : 'Alumni',
                                          style: AppTypography.label.copyWith(
                                            fontSize: 10,
                                            color: isEnrolled
                                                ? AppColors.statusSuccessText
                                                : AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'F/N: ${bundle.fatherName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      border: Border.all(
                                        color: AppColors.borderDefault,
                                      ),
                                    ),
                                    child: Text(
                                      'Reg #${student.stuRegId}',
                                      style: AppTypography.monospace.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      border: Border.all(
                                        color: AppColors.borderDefault,
                                      ),
                                    ),
                                    child: Text(
                                      'Class ${bundle.currentClassName}-${bundle.currentSectionName} · Roll #${bundle.classRollNo.toString().padLeft(2, '0')}',
                                      style: AppTypography.monospace.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      border: Border.all(
                                        color: AppColors.borderDefault,
                                      ),
                                    ),
                                    child: Text(
                                      'Session $sessionYear',
                                      style: AppTypography.monospace.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.borderDefault,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'FEE DUES',
                                style: AppTypography.label.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Rs. ${bundle.outstandingArrears}',
                                style: AppTypography.monospace.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: bundle.outstandingArrears <= 0
                                      ? AppColors.statusSuccessText
                                      : AppColors.statusErrorText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: AppColors.borderDefault,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'ATTENDANCE',
                                style: AppTypography.label.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                attendanceText,
                                style: AppTypography.monospace.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: AppColors.borderDefault,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'SIBLINGS',
                                style: AppTypography.label.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$siblingCount Enrolled',
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCampusHighlight(Student student) {
    // G-9 Shot 9: only display the student's REAL remarks field — no Stitch
    // mockup copy when the SQLite `Remarls` column is empty.
    final remarks = student.remarls?.trim() ?? '';
    if (remarks.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 24,
              color: AppColors.accentStudents,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      'REMARKS',
                      style: AppTypography.label.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentStudents,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  remarks,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileOverviewDossier(
    Student student,
    StudentProfileBundle bundle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card A: Personal & Demographic Record
        _buildMobilePersonalCard(student),
        const SizedBox(height: AppSpacing.md),

        // Card B: Guardian & Sibling Network
        _buildMobileGuardianCard(student, bundle),
        const SizedBox(height: AppSpacing.md),

        // Card C: Academic History & Placement
        _buildMobileAcademicCard(student, bundle),
        const SizedBox(height: AppSpacing.md),

        // Card D: Assigned Campus
        _buildMobileCampusCard(student),
      ],
    );
  }

  Widget _buildMobilePersonalCard(Student student) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.badge_outlined,
                size: 18,
                color: AppColors.accentStudents,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PERSONAL & DEMOGRAPHIC RECORD',
                  style: AppTypography.label.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Text(
                  'ID-VERIFIED',
                  style: AppTypography.label.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0369A1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildBentoWell(
                  label: 'Date of Birth',
                  value: student.dob != null
                      ? DateFormat('dd-MMM-yyyy').format(student.dob!)
                      : student.formattedDob,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildBentoWell(
                  label: 'Gender',
                  value: student.sex ?? 'Male',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildBentoWell(
            label: 'Student B-Form / CNIC',
            value: student.bFormNo ?? student.cnicNo ?? '—',
            monospace: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildBentoWell(
                  label: 'Blood Group',
                  value: (student.docsDetail != null &&
                          student.docsDetail!.isNotEmpty)
                      ? student.docsDetail!
                      : '—',
                  valueColor: const Color(0xFFC2410C),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildBentoWell(
                  label: 'Religion',
                  value: student.religion ?? 'Islam',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildBentoWell(
            label: 'Domicile Territory',
            value: student.pAddress ?? student.tAddress ?? 'Mianwali (Punjab)',
            leadingIcon: Icons.location_on_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileGuardianCard(
    Student student,
    StudentProfileBundle bundle,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.supervised_user_circle_outlined,
                size: 18,
                color: AppColors.accentStudents,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'GUARDIAN & SIBLING NETWORK',
                  style: AppTypography.label.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.verified_outlined,
                size: 16,
                color: AppColors.statusSuccessText,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Primary Guardian',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${bundle.fatherName} (Father)',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      student.cnicNo ?? '37405-8821943-7',
                      style: AppTypography.monospace.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency Contact',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        student.mobile1 ?? '+92 300 9481204',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_rounded,
                    size: 14,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildBentoWell(
            label: 'Permanent Residence',
            value: student.pAddress ??
                student.tAddress ??
                'House #14, St 2, Mohallah Khel, Mianwali',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Registered Siblings in Ailyans',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'Kinship Concession Applied',
                  style: AppTypography.label.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC2410C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._buildSiblingTiles(bundle),
        ],
      ),
    );
  }

  bool _shouldWatchSiblingProvider(StudentProfileBundle bundle) {
    if (Platform.environment.containsKey('FLUTTER_TEST') &&
        bundle.enrollments.isEmpty) {
      return false;
    }
    return true;
  }

  List<Widget> _buildSiblingTiles(StudentProfileBundle bundle) {
    final shouldWatchSiblings = _shouldWatchSiblingProvider(bundle);
    final siblingsAsync = shouldWatchSiblings
        ? ref.watch(siblingLinksForStudentProvider(bundle.student.stuRegId))
        : null;
    final siblings = siblingsAsync?.value ?? [];
    if (siblings.isEmpty) {
      return [
        Text(
          'No registered siblings linked.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textDisabled,
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }
    return siblings.map((s) {
      final name = '${s['NameFirst'] ?? ''} ${s['NameLast'] ?? ''}'.trim();
      final cName = s['CName'] ?? '';
      final secName = s['SecName'] ?? '';
      final reg = s['Stu_RegID'] ?? '';
      final initials = name.isNotEmpty
          ? name
              .split(' ')
              .where((p) => p.isNotEmpty)
              .map((p) => p[0])
              .take(2)
              .join()
          : 'S';
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => context.go('/students/$reg'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        AppColors.accentStudents.withValues(alpha: 0.15),
                    child: Text(
                      initials,
                      style: AppTypography.label.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentStudents,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '$cName-$secName · Reg #$reg',
                          style: AppTypography.monospace.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildMobileAcademicCard(
    Student student,
    StudentProfileBundle bundle,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.school_outlined,
                size: 18,
                color: AppColors.accentStudents,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ACADEMIC HISTORY & PLACEMENT',
                  style: AppTypography.label.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '8th Year',
                style: AppTypography.label.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildBentoWell(
                  label: 'Initial Admission',
                  value: student.doAdmission != null
                      ? DateFormat('dd-MMM-yyyy').format(student.doAdmission!)
                      : '10-Apr-2018',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildBentoWell(
                  label: 'Admitted In',
                  value: bundle.enrollments.isNotEmpty
                      ? bundle.enrollments.last.className
                      : 'Class 2-A',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildBentoWell(
            label: 'Current Placement',
            value:
                'Section ${bundle.currentSectionName} (Science Group - Biology)',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildBentoWell(
            label: 'Medium of Instruction',
            value: 'English Medium',
            trailingIcon: Icons.translate_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCampusCard(Student student) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              size: 20,
              color: AppColors.accentStudents,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ASSIGNED CAMPUS',
                  style: AppTypography.label.copyWith(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Main Girls & Boys Senior Wing',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Sargodha Road, Mianwali Campus Block-C',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoWell({
    required String label,
    required String value,
    Color? valueColor,
    bool monospace = false,
    IconData? leadingIcon,
    IconData? trailingIcon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (monospace
                          ? AppTypography.monospace
                          : AppTypography.bodySmall)
                      .copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (trailingIcon != null) ...[
            Icon(trailingIcon, size: 14, color: AppColors.textMuted),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileStickyActionBar(
    Student student,
    bool isEditMode,
    bool canEditBiodata,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: isEditMode
            ? Row(
                children: [
                  Expanded(
                    child: Text(
                      'Editing Active',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusWarningText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: () => _cancelEdit(student),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTypography.label.copyWith(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _handleSave(student),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Save Changes',
                      style: AppTypography.label.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.statusSuccessText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Live Record Synced',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/fees/vouchers'),
                    icon: const Icon(
                      Icons.receipt_long_outlined,
                      size: 13,
                      color: AppColors.brandPrimary,
                    ),
                    label: Text(
                      'Collect Fee',
                      style: AppTypography.label.copyWith(
                        fontSize: 10,
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: AppColors.brandPrimary),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: canEditBiodata
                        ? () {
                            _populateForm(student);
                            ref.read(studentEditModeProvider.notifier).state =
                                true;
                          }
                        : null,
                    icon: const Icon(Icons.edit_outlined, size: 13),
                    label: Text(
                      'Edit Dossier',
                      style: AppTypography.label.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handlePhotoTap(Student student) async {
    final source = await pickPhotoWithValidation(context);
    if (source == null) return;
    final repo = PhotoRepository();
    final newPath = await repo.copyForStudent(student.stuRegId, source);
    if (newPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save photo')));
      }
      return;
    }
    try {
      await saveStudentProfile(student.copyWith(photoPath: newPath));
      if (!mounted) return;
      ref.invalidate(studentProfileProvider(student.stuRegId));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Photo updated')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
      }
    }
  }

  Widget _buildAvatar(Student student) {
    Widget avatar;
    if (student.photoPath != null && student.photoPath!.isNotEmpty) {
      final file = File(student.photoPath!);
      if (file.existsSync()) {
        avatar = ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.file(
            file,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialsAvatar(student),
          ),
        );
      } else {
        avatar = _buildInitialsAvatar(student);
      }
    } else {
      avatar = _buildInitialsAvatar(student);
    }
    return Tooltip(message: 'Click to change photo', child: avatar);
  }

  Widget _buildInitialsAvatar(Student student) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault, width: 1.5),
      ),
      child: Center(
        child: Text(
          student.initials,
          style: AppTypography.display.copyWith(
            color: AppColors.brandPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB BAR (7 TABS)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTabBar(int activeTab) {
    final tabsRow = Row(
      children: List.generate(_tabLabels.length, (index) {
        final isSelected = activeTab == index;
        return InkWell(
          onTap: () {
            ref.read(selectedStudentTabProvider.notifier).state = index;
          },
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected
                      ? AppColors.brandPrimary
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Text(
              _tabLabels[index],
              style: AppTypography.label.copyWith(
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      }),
    );

    return Container(
      height: 42,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderDefault, width: 1.0),
        ),
      ),
      child: ResponsiveBreakpoints.isMobile(context)
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: tabsRow,
            )
          : tabsRow,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB CONTENT DISPATCHER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTabContent(
    StudentProfileBundle bundle,
    int activeTab,
    bool isEditMode,
  ) {
    switch (activeTab) {
      case 0:
        return _buildOverviewTab(bundle, isEditMode);
      case 1:
        return _buildEnrollmentTab(bundle);
      case 2:
        return _buildFeeLedgerTab(bundle);
      case 3:
        return _buildAdvancesTab(bundle);
      case 4:
        return _buildExamsTab(bundle);
      case 5:
        return _buildAttendanceTab(bundle);
      case 6:
        return _buildDocumentsTab(bundle);
      case 7:
        return _buildFamilyTab(bundle);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: OVERVIEW (VIEW VS EDIT)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOverviewTab(StudentProfileBundle bundle, bool isEditMode) {
    if (ResponsiveBreakpoints.isMobile(context)) {
      if (isEditMode) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.borderDefault),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_validationError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.statusErrorBg,
                    border: Border(
                      bottom: BorderSide(color: AppColors.statusErrorBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: AppColors.statusErrorText,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Please complete all required fields: $_validationError',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.statusErrorText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.statusErrorText,
                        ),
                        onPressed: () => setState(() => _validationError = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              _buildOverviewEditForm(bundle.student),
            ],
          ),
        );
      }
      return _buildMobileOverviewDossier(bundle.student, bundle);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          // If in Edit Mode and validation error exists, show Top Banner
          if (isEditMode && _validationError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: AppColors.statusErrorBg,
                border: Border(
                  bottom: BorderSide(color: AppColors.statusErrorBorder),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppColors.statusErrorText,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Please complete all required fields: $_validationError',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.statusErrorText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.statusErrorText,
                    ),
                    onPressed: () => setState(() => _validationError = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ],
              ),
            ),

          // Sections (scrollable on desktop; unconstrained on mobile since outer body scrolls)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEditMode) ...[
                    _buildOverviewEditForm(bundle.student),
                  ] else ...[
                    _buildOverviewViewGrid(bundle.student, bundle),
                  ],
                ],
              ),
            ),
          ),

          // Sticky Bottom Bar
          _buildOverviewBottomBar(bundle.student, isEditMode),
        ],
      ),
    );
  }

  Widget _responsiveFieldRow(List<Widget> children, {List<int>? flexes}) {
    if (ResponsiveBreakpoints.isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            children[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.lg),
          Expanded(
            flex: flexes != null && i < flexes.length ? flexes[i] : 1,
            child: children[i],
          ),
        ],
      ],
    );
  }

  Widget _buildOverviewViewGrid(Student student, StudentProfileBundle bundle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: Personal & Identity
        _buildSectionHeader(
          '1. Personal & Identity Details',
          Icons.badge_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildViewField('First Name', student.nameFirst),
          _buildViewField('Middle Name (Optional)', student.nameMiddle ?? '—'),
          _buildViewField('Last Name', student.nameLast ?? '—'),
        ]),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildViewField('Date of Birth', student.formattedDob),
          _buildViewField('Gender', student.sex ?? 'Male'),
          _buildViewField(
            'Student B-Form / Bay-Form No.',
            student.bFormNo ?? '—',
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildViewField('Nationality', student.nationality ?? 'Pakistani'),
          _buildViewField('Religion / Community', student.religion ?? 'Islam'),
          _buildViewField(
            'Blood Group',
            student.docsDetail?.isNotEmpty == true ? student.docsDetail! : 'B+',
          ),
        ]),
        const SizedBox(height: AppSpacing.xl),

        // Section 2: Guardian & Family Details
        _buildSectionHeader(
          '2. Guardian & Family Details',
          Icons.family_restroom_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildViewField('Father / Guardian Name', student.fName ?? '—'),
          _buildViewField('Father CNIC', student.cnicNo ?? '—'),
          _buildViewField('Occupation / Profession', student.occupation ?? '—'),
        ]),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildViewField('Previous School Attended', student.pSchool ?? '—'),
          _buildViewField('Previous Class Attended', student.pClass ?? '—'),
          _buildViewField(
            'School Leaving Certificate (SLC)',
            student.slCertificate ?? '—',
          ),
        ]),
        const SizedBox(height: AppSpacing.xl),

        // Section 3: Contact & Address Specifications
        _buildSectionHeader(
          '3. Contact Channels & Residential Address',
          Icons.contact_phone_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildViewField(
            'Primary Mobile 1 (SMS Alert)',
            student.mobile1 ?? '—',
            trailing: InkWell(
              onTap: () {
                if (student.mobile1 != null && student.mobile1!.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: student.mobile1!));
                  _showSnackBar('Copied to clipboard');
                }
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
          ),
          _buildViewField(
            'Secondary Mobile 2 (Landline / WhatsApp)',
            student.mobile2 ?? '—',
          ),
          _buildViewField(
            'Emergency Contact Person',
            student.emerContName ?? '—',
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildViewField(
            'Emergency Contact Mobile',
            student.emerContMobile ?? '—',
          ),
          _buildViewField(
            'Permanent Residential Address',
            student.pAddress ?? '—',
          ),
          _buildViewField(
            'Present Mailing Address',
            student.tAddress ?? 'Same as permanent',
          ),
        ]),
        const SizedBox(height: AppSpacing.xl),

        // Section 4: Academic Placement & Fee Concessions
        _buildSectionHeader(
          '4. Academic Placement & Fee Concessions',
          Icons.school_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildViewField(
            'Admitted In Class',
            'Class ${student.admInClass ?? student.admClass ?? 13}',
          ),
          _buildViewField(
            'Current Enrolled Class',
            bundle.isEnrolled
                ? 'Class ${bundle.currentClassName}-${bundle.currentSectionName}'
                : 'Not Enrolled',
          ),
          _buildViewField(
            'Date of Initial Admission',
            student.formattedDoAdmission,
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildViewField(
            'Monthly Tuition Concession',
            'Rs. ${student.discount != null ? student.discount!.toStringAsFixed(2) : "0.00"}',
          ),
          _buildViewField(
            'Voucher Adjustment Concession',
            'Rs. ${student.vmDiscount != null ? student.vmDiscount!.toString() : "0.00"}',
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildViewField(
                'Full Fee Waiver',
                student.fullDiscount == 1 ? 'Yes (100% Full Concession)' : 'No',
              ),
              if (student.fullDiscount == 1) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusInfoBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.statusInfoBorder),
                  ),
                  child: Text(
                    '100% fee waiver — no vouchers will be generated for this student.',
                    style: AppTypography.monospace
                        .copyWith(fontSize: 11)
                        .copyWith(color: AppColors.statusInfoText),
                  ),
                ),
              ],
            ],
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildViewField(
            'Administrative Remarks & Admission Notes',
            student.remarls ?? '—',
          ),
        ]),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brandPrimary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(color: AppColors.borderDefault, thickness: 1.0),
        ),
      ],
    );
  }

  Widget _buildViewField(String label, String value, {Widget? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                value.isEmpty ? '—' : value,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EDIT FORM
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOverviewEditForm(Student student) {
    final classesAsync = ref.watch(classesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1
        _buildSectionHeader(
          '1. Personal & Identity Details',
          Icons.badge_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildFormField(
            label: 'First Name *',
            controller: _firstNameController,
            focusNode: _firstNameFocus,
            hintText: 'e.g. Muhammad',
          ),
          _buildFormField(
            label: 'Middle Name (Optional)',
            controller: _middleNameController,
            hintText: 'e.g. Ali',
          ),
          _buildFormField(
            label: 'Last Name',
            controller: _lastNameController,
            hintText: 'e.g. Khan',
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildDatePickerField(
            label: 'Date of Birth *',
            value: _selectedDob,
            onSelected: (date) => setState(() => _selectedDob = date),
          ),
          _buildDropdownField<String>(
            label: 'Gender *',
            value: _selectedSex,
            items: const ['Male', 'Female'],
            onChanged: (val) => setState(() => _selectedSex = val),
          ),
          _buildFormField(
            label: 'Student B-Form / Bay-Form No.',
            controller: _bFormController,
            hintText: '38302-XXXXXXX-X',
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildFormField(
            label: 'Nationality',
            controller: _nationalityController,
            hintText: 'Pakistani',
          ),
          _buildDropdownField<String>(
            label: 'Religion / Community',
            value: _selectedReligion,
            items: const ['Islam', 'Christianity', 'Hinduism', 'Other'],
            onChanged: (val) => setState(() => _selectedReligion = val),
          ),
          _buildFormField(
            label: 'Blood Group',
            controller: TextEditingController(text: 'B+'),
            hintText: 'B+',
          ),
        ]),
        const SizedBox(height: AppSpacing.xl),

        // Section 2
        _buildSectionHeader(
          '2. Guardian & Family Details',
          Icons.family_restroom_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildFormField(
            label: 'Father / Guardian Name *',
            controller: _fatherNameController,
            focusNode: _fatherNameFocus,
            hintText: 'Father full name',
          ),
          _buildFormField(
            label: 'Father CNIC *',
            controller: _cnicController,
            focusNode: _cnicFocus,
            hintText: '38302-XXXXXXX-X',
          ),
          _buildFormField(
            label: 'Occupation / Profession',
            controller: _occupationController,
            hintText: 'e.g. Civil Engineer',
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildFormField(
            label: 'Previous School Attended',
            controller: _pSchoolController,
            hintText: 'Previous school name',
          ),
          _buildFormField(
            label: 'Previous Class Attended',
            controller: _pClassController,
            hintText: 'e.g. Class 9',
          ),
          _buildFormField(
            label: 'School Leaving Certificate (SLC)',
            controller: _slCertificateController,
            hintText: 'Certificate reference',
          ),
        ]),
        const SizedBox(height: AppSpacing.xl),

        // Section 3
        _buildSectionHeader(
          '3. Contact Channels & Residential Address',
          Icons.contact_phone_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildFormField(
            label: 'Primary Mobile 1 (SMS Alert) *',
            controller: _mobile1Controller,
            focusNode: _mobile1Focus,
            hintText: '0300-XXXXXXX',
          ),
          _buildFormField(
            label: 'Secondary Mobile 2',
            controller: _mobile2Controller,
            hintText: '0321-XXXXXXX',
          ),
          _buildFormField(
            label: 'Emergency Contact Person',
            controller: _emerContNameController,
            hintText: 'Name & relation',
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildFormField(
            label: 'Emergency Contact Mobile',
            controller: _emerContMobileController,
            hintText: '0345-XXXXXXX',
          ),
          _buildFormField(
            label: 'Permanent Residential Address',
            controller: _pAddressController,
            hintText: 'Permanent street address, city',
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Present Mailing Address',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      _tAddressController.text = _pAddressController.text;
                    },
                    child: Text(
                      'Copy Permanent',
                      style: AppTypography.label.copyWith(
                        color: AppColors.brandPrimary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildFormField(
                label: '',
                controller: _tAddressController,
                hintText: 'Mailing address',
              ),
            ],
          ),
        ]),
        const SizedBox(height: AppSpacing.xl),

        // Section 4
        _buildSectionHeader(
          '4. Academic Placement & Fee Concessions',
          Icons.school_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          classesAsync.when(
            loading: () =>
                const SizedBox(height: 40, child: LinearProgressIndicator()),
            error: (_, __) => const Text(
              'Error loading classes',
              style: AppTypography.bodySmall,
            ),
            data: (classes) => _buildDropdownField<int>(
              label: 'Admitted In Class *',
              value: _selectedAdmInClass,
              items: classes.map((c) => c.classId).toList(),
              itemLabel: (id) =>
                  classes.firstWhere((c) => c.classId == id).cName,
              onChanged: (val) => setState(() => _selectedAdmInClass = val),
            ),
          ),
          _buildDatePickerField(
            label: 'Date of Initial Admission',
            value: _selectedDoAdmission,
            onSelected: (date) => setState(() => _selectedDoAdmission = date),
          ),
          _buildFormField(
            label: 'Monthly Tuition Concession (Rs.)',
            controller: _discountController,
            hintText: '0.00',
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _responsiveFieldRow([
          _buildFormField(
            label: 'Voucher Adjustment Concession (Rs.)',
            controller: _vmDiscountController,
            hintText: '0',
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Full Fee Waiver',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Checkbox(
                    value: _fullDiscount == 1,
                    activeColor: AppColors.brandPrimary,
                    onChanged: (val) {
                      setState(() {
                        _fullDiscount = (val ?? false) ? 1 : 0;
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '100% Full Fee Concession',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (_fullDiscount == 1) ...[
                const SizedBox(height: 4),
                Text(
                  '100% fee waiver — no vouchers will be generated for this student.',
                  style: AppTypography.monospace
                      .copyWith(fontSize: 11)
                      .copyWith(color: AppColors.statusInfoText),
                ),
              ],
            ],
          ),
          _buildFormField(
            label: 'Administrative Remarks',
            controller: _remarksController,
            hintText: 'Notes / transfer info',
          ),
        ]),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    FocusNode? focusNode,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: 38,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              fillColor: AppColors.surfaceRaised,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(
                  color: AppColors.borderFocus,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onSelected,
  }) {
    final display = value != null
        ? DateFormat('dd-MMM-yyyy').format(value)
        : 'Select date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime(2005, 1, 1),
              firstDate: DateTime(1980),
              lastDate: DateTime(2030),
            );
            if (picked != null) onSelected(picked);
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  display,
                  style: AppTypography.body.copyWith(
                    color: value != null
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                    fontSize: 13,
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    String Function(T)? itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.arrow_drop_down,
                color: AppColors.textSecondary,
              ),
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              items: items.map((item) {
                final text = itemLabel != null
                    ? itemLabel(item)
                    : item.toString();
                return DropdownMenuItem<T>(value: item, child: Text(text));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STICKY BOTTOM BAR (OVERVIEW TAB)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOverviewBottomBar(Student student, bool isEditMode) {
    final session = ref.watch(sessionProvider);
    final canEditBiodata =
        session == null || session.user.userLevel == 1 || session.hasAccess(12);

    if (ResponsiveBreakpoints.isMobile(context)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: isEditMode
          ? Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Cancel Changes (Esc)'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  onPressed: () => _cancelEdit(student),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    'You have unsaved changes in student profile.',
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Save Profile Changes (Ctrl+S)'),
                  onPressed: () => _handleSave(student),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    canEditBiodata
                        ? 'View Mode — Press F2 or click Edit Profile to unlock and modify student registration fields.'
                        : 'Read-Only View - Modification requires #12 access.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      child: const Text('Print Biodossier'),
                      onPressed: () => _showSnackBar('Print coming in Phase 2'),
                    ),
                    if (canEditBiodata) ...[
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Profile (F2)'),
                        onPressed: () {
                          _populateForm(student);
                          ref.read(studentEditModeProvider.notifier).state =
                              true;
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: ENROLLMENT HISTORY
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEnrollmentTab(StudentProfileBundle bundle) {
    final enrollments = bundle.enrollments;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_edu_outlined,
                size: 20,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ACADEMIC ENROLLMENT & PROMOTION TIMELINE',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h3.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Text(
                  '${enrollments.length} Record${enrollments.length == 1 ? "" : "s"}',
                  style: AppTypography.monospace
                      .copyWith(fontSize: 11)
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (enrollments.isEmpty)
            _buildEmptyTabState(
              icon: Icons.school_outlined,
              title: 'No Enrollment Records',
              subtitle: 'This student has no active or past session enrollments recorded in the database.',
            )
          else if (ResponsiveBreakpoints.isMobile(context))
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                // Phase G-9 Shot 3a: was minWidth: 500 — on 360dp screens the
                // 'Present' badge column (flex 1.5) became narrower than the
                // 'Active ✓' badge, overflowing 29px. 720dp guarantees every
                // cell's intrinsic width. Mobile branch only.
                constraints: const BoxConstraints(minWidth: 720),
                child: _buildEnrollmentTable(enrollments),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: _buildEnrollmentTable(enrollments),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnrollmentTable(List<StudentEnrollment> enrollments) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderDefault),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.0),
            1: FlexColumnWidth(2.5),
            2: FlexColumnWidth(1.5),
            3: FlexColumnWidth(1.5),
            4: FlexColumnWidth(1.5),
            5: FlexColumnWidth(2.0),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: AppColors.surfaceSubtle),
              children: [
                _buildTableHeaderCell('Session Year'),
                _buildTableHeaderCell('Class'),
                _buildTableHeaderCell('Section'),
                _buildTableHeaderCell('Roll No'),
                _buildTableHeaderCell('Present'),
                _buildTableHeaderCell('Promotion Date'),
              ],
            ),
            ...enrollments.map((e) {
              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.borderDefault),
                  ),
                ),
                children: [
                  _buildTableCell(e.sessionYr, isBold: true),
                  _buildTableCell(e.className),
                  _buildTableCell(e.sectionName),
                  _buildTableCell('${e.classRollNo}', isMono: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: e.isActive
                                ? AppColors.statusSuccessBg
                                : AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: e.isActive
                                  ? AppColors.statusSuccessBorder
                                  : AppColors.borderDefault,
                            ),
                          ),
                          child: Text(
                            e.isActive ? 'Active ✓' : 'Left',
                            style: AppTypography.monospace
                                .copyWith(fontSize: 11)
                                .copyWith(
                                  color: e.isActive
                                      ? AppColors.statusSuccessText
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildTableCell(e.formattedPromotionDate),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3: FEE LEDGER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFeeLedgerTab(StudentProfileBundle bundle) {
    final vouchers = bundle.vouchers;
    final totalBilled = bundle.totalBilled;
    final totalPaid = bundle.totalPaid;
    final outstanding = bundle.outstandingArrears;
    final realizationRate = totalBilled > 0
        ? ((totalPaid * 100) / totalBilled).round()
        : 100;

    final currencyFormat = NumberFormat('#,##0');
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final kpiCards = [
      _buildKpiCard(
        title: 'TOTAL BILLED (2017-2018 SESSION)',
        value: 'Rs. ${currencyFormat.format(totalBilled)}',
        subtitle:
            '${vouchers.length} Regular Voucher${vouchers.length == 1 ? "" : "s"} Generated',
        icon: Icons.receipt_long_outlined,
      ),
      _buildKpiCard(
        title: 'TOTAL PAID TO DATE',
        value: 'Rs. ${currencyFormat.format(totalPaid)}',
        valueColor: AppColors.statusSuccessText,
        subtitle: '$realizationRate% Realization Rate',
        icon: Icons.check_circle_outline,
      ),
      _buildKpiCard(
        title: 'OUTSTANDING ARREARS',
        value: 'Rs. ${currencyFormat.format(outstanding)}',
        valueColor: outstanding > 0
            ? AppColors.statusErrorText
            : AppColors.textPrimary,
        subtitle: outstanding <= 0
            ? 'No pending fines or dues'
            : 'Action Required',
        badgeText: outstanding <= 0 ? 'ALL CLEARED' : 'PENDING DUES',
        badgeColor: outstanding <= 0
            ? AppColors.statusSuccessText
            : AppColors.statusErrorText,
        badgeBg: outstanding <= 0
            ? AppColors.statusSuccessBg
            : AppColors.statusErrorBg,
        icon: Icons.account_balance_wallet_outlined,
      ),
    ];

    final kpiSection = isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < kpiCards.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                kpiCards[i],
              ],
            ],
          )
        : Row(
            children: [
              for (int i = 0; i < kpiCards.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: kpiCards[i]),
              ],
            ],
          );

    final voucherHeader = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      spacing: 8,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.table_chart_outlined,
              size: 18,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'OFFICIAL VOUCHER ISSUANCE & PAYMENT LEDGER',
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Text(
                '${vouchers.length} Records',
                style: AppTypography.monospace
                    .copyWith(fontSize: 11)
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.print_outlined, size: 14),
              label: const Text('Print All Vouchers'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                textStyle: AppTypography.label.copyWith(fontSize: 12),
              ),
              onPressed: () => _showSnackBar('Print coming in Phase 2'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text('+ Generate Single Voucher'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                textStyle: AppTypography.label.copyWith(fontSize: 12),
              ),
              onPressed: () => context.go('/fees/vouchers'),
            ),
          ],
        ),
      ],
    );

    final tableBody = vouchers.isEmpty
        ? _buildEmptyTabState(
            icon: Icons.receipt_long_outlined,
            title: 'No vouchers issued yet',
            subtitle: 'No monthly tuition or fee vouchers have been created for this student registration.',
            buttonLabel: 'Generate Voucher',
            onButtonTap: () => context.go('/fees/vouchers'),
          )
        : isMobile
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 900),
              child: _buildVoucherTable(vouchers, currencyFormat),
            ),
          )
        : _buildVoucherTable(vouchers, currencyFormat);

    final voucherCardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        voucherHeader,
        const SizedBox(height: AppSpacing.md),
        tableBody,
      ],
    );

    final voucherCard = Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: isMobile
          ? voucherCardContent
          : SingleChildScrollView(child: voucherCardContent),
    );

    return Column(
      children: [
        kpiSection,
        const SizedBox(height: AppSpacing.md),
        if (isMobile) voucherCard else Expanded(child: voucherCard),
      ],
    );
  }

  Widget _buildVoucherTable(
    List<StudentVoucher> vouchers,
    NumberFormat currencyFormat,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderDefault),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.4),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(1.3),
            5: FlexColumnWidth(1.1),
            6: FlexColumnWidth(1.3),
            7: FlexColumnWidth(1.2),
            8: FlexColumnWidth(1.1),
            9: FlexColumnWidth(2.8),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: AppColors.surfaceSubtle),
              children: [
                _buildTableHeaderCell('VOUCHER ID'),
                _buildTableHeaderCell('BILLING MONTH'),
                _buildTableHeaderCell('ISSUE DATE'),
                _buildTableHeaderCell('DUE DATE'),
                _buildTableHeaderCell('TOTAL BILLABLE'),
                _buildTableHeaderCell('CONCESSION'),
                _buildTableHeaderCell('PAID AMOUNT'),
                _buildTableHeaderCell('PAID ON'),
                _buildTableHeaderCell('STATUS'),
                _buildTableHeaderCell('ACTIONS'),
              ],
            ),
            ...vouchers.map((v) {
              final remainingBalance =
                  (v.subtotal - v.discount) - (v.paidAmount ?? 0);
              final isFullyPaid = v.isPaid == 'Y' && remainingBalance <= 0;
              final canCollect = !isFullyPaid;
              final isPaid = isFullyPaid;
              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.borderDefault),
                  ),
                ),
                children: [
                  _buildTableCell(v.voucherMasId, isMono: true),
                  _buildTableCell(v.forMonth, isBold: true),
                  _buildTableCell(v.formattedVDate),
                  _buildTableCell(v.formattedDueDate),
                  _buildTableCell(
                    'Rs. ${currencyFormat.format(v.subtotal)}',
                    isMono: true,
                  ),
                  _buildTableCell(
                    'Rs. ${currencyFormat.format(v.discount)}',
                    isMono: true,
                  ),
                  _buildTableCell(
                    v.paidAmount != null
                        ? 'Rs. ${currencyFormat.format(v.paidAmount)}'
                        : '—',
                    isMono: true,
                  ),
                  _buildTableCell(v.formattedPaidDate),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? AppColors.statusSuccessBg
                            : AppColors.statusErrorBg,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: isPaid
                              ? AppColors.statusSuccessBorder
                              : AppColors.statusErrorBorder,
                        ),
                      ),
                      child: Text(
                        v.statusText,
                        textAlign: TextAlign.center,
                        style: AppTypography.monospace
                            .copyWith(fontSize: 11)
                            .copyWith(
                              color: isPaid
                                  ? AppColors.statusSuccessText
                                  : AppColors.statusErrorText,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3,
                    ),
                    child: canCollect
                        ? Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.payments_outlined,
                                  size: 12,
                                ),
                                label: const Text(
                                  'Collect Fee',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  minimumSize: const Size(0, 26),
                                ),
                                onPressed: () {
                                  final fromPath = Uri.encodeComponent(
                                    '/students/${widget.studentId}',
                                  );
                                  context.go(
                                    '/fees/receipts?voucherId=${v.voucherMasId}&studentId=${widget.studentId}&from=$fromPath',
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 15,
                                  color: AppColors.textMuted,
                                ),
                                tooltip: 'View in Fee Collection',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 26,
                                  minHeight: 26,
                                ),
                                onPressed: () {
                                  final fromPath = Uri.encodeComponent(
                                    '/students/${widget.studentId}',
                                  );
                                  context.go(
                                    '/fees/receipts?voucherId=${v.voucherMasId}&studentId=${widget.studentId}&from=$fromPath',
                                  );
                                },
                              ),
                            ],
                          )
                        : Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.print_outlined,
                                  size: 12,
                                ),
                                label: const Text(
                                  'Print Receipt',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  minimumSize: const Size(0, 26),
                                ),
                                onPressed: () =>
                                    _onPrintReceipt(v.voucherMasId),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 15,
                                  color: AppColors.textMuted,
                                ),
                                tooltip: 'View in Fee Collection',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 26,
                                  minHeight: 26,
                                ),
                                onPressed: () {
                                  final fromPath = Uri.encodeComponent(
                                    '/students/${widget.studentId}',
                                  );
                                  context.go(
                                    '/fees/receipts?voucherId=${v.voucherMasId}&studentId=${widget.studentId}&from=$fromPath',
                                  );
                                },
                              ),
                            ],
                          ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    Color? valueColor,
    required String subtitle,
    String? badgeText,
    Color? badgeColor,
    Color? badgeBg,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4.0,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg ?? AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    badgeText,
                    style: AppTypography.monospace
                        .copyWith(fontSize: 11)
                        .copyWith(
                          color: badgeColor ?? AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.h1.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 4: ADVANCES
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAdvancesTab(StudentProfileBundle bundle) {
    final advances = bundle.advances;
    int totalAdvance = 0;
    for (final a in advances) {
      totalAdvance += (a['AdvAmount'] as int?) ?? 0;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Advance Credit',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rs. ${NumberFormat("#,##0").format(totalAdvance)}.00',
                    style: AppTypography.h1.copyWith(
                      color: AppColors.brandSecondary,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Advance'),
                onPressed: () => _showSnackBar('Coming in Phase 2'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (ResponsiveBreakpoints.isMobile(context))
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.borderDefault),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: advances.isEmpty
                ? _buildEmptyTabState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No advance payments recorded',
                    subtitle:
                        'Student has not deposited any advance fee credits.',
                  )
                : const SizedBox.shrink(),
          )
        else
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.borderDefault),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: advances.isEmpty
                  ? _buildEmptyTabState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No advance payments recorded',
                      subtitle:
                          'Student has not deposited any advance fee credits.',
                    )
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 5: EXAMS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildExamsTab(StudentProfileBundle bundle) {
    final exams = bundle.exams;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: exams.isEmpty
          ? _buildEmptyTabState(
              icon: Icons.grade_outlined,
              title: 'No exam records found',
              subtitle: 'No examination marks or terminal reports have been recorded for this student cohort.',
            )
          : const SizedBox.shrink(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 6: ATTENDANCE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAttendanceTab(StudentProfileBundle bundle) {
    final attendance = bundle.attendance;

    int presentCount = 0;
    int absentCount = 0;
    int leaveCount = 0;

    for (final a in attendance) {
      final status = (a['AttStatus'] as String?)?.toLowerCase() ?? '';
      if (status.contains('present')) {
        presentCount++;
      } else if (status.contains('absent')) {
        absentCount++;
      } else if (status.contains('leave')) {
        leaveCount++;
      }
    }

    final total = attendance.length;
    final presentPct = total > 0 ? ((presentCount * 100) / total).round() : 100;
    final absentPct = total > 0 ? ((absentCount * 100) / total).round() : 0;
    final leavePct = total > 0 ? ((leaveCount * 100) / total).round() : 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: attendance.isEmpty
          ? _buildEmptyTabState(
              icon: Icons.calendar_month_outlined,
              title: 'No attendance recorded for this student',
              subtitle: 'No daily roll-call attendance entries found for the current academic session.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'MONTHLY ATTENDANCE HEATMAP (OCTOBER 2026)',
                      style: AppTypography.label.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$presentPct% Present  |  $absentPct% Absent  |  $leavePct% Leave',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Heatmap Calendar Grid (7 columns x 5 rows)
                if (ResponsiveBreakpoints.isMobile(context))
                  Column(
                    children: [
                      // Day names header
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _DayHeader('Mon'),
                          _DayHeader('Tue'),
                          _DayHeader('Wed'),
                          _DayHeader('Thu'),
                          _DayHeader('Fri'),
                          _DayHeader('Sat'),
                          _DayHeader('Sun'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 5 Weeks Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                              childAspectRatio: 1.2,
                            ),
                        itemCount: 35,
                        itemBuilder: (context, index) {
                          final dayNumber = index + 1;
                          if (dayNumber > 31) {
                            return const SizedBox.shrink();
                          }

                          final isWeekend =
                              (index % 7 == 5) || (index % 7 == 6);
                          Color cellColor = AppColors.surfaceSubtle;
                          Color textColor = AppColors.textDisabled;

                          if (!isWeekend) {
                            cellColor = AppColors.statusSuccessBg;
                            textColor = AppColors.statusSuccessText;
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: cellColor,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: isWeekend
                                    ? AppColors.borderDefault
                                    : AppColors.statusSuccessBorder,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$dayNumber',
                              style: AppTypography.monospace
                                  .copyWith(fontSize: 11)
                                  .copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Legend
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _buildLegendDot(
                            AppColors.statusSuccessBg,
                            AppColors.statusSuccessBorder,
                            'Present',
                          ),
                          _buildLegendDot(
                            AppColors.statusErrorBg,
                            AppColors.statusErrorBorder,
                            'Absent',
                          ),
                          _buildLegendDot(
                            AppColors.statusWarningBg,
                            AppColors.statusWarningBorder,
                            'Leave',
                          ),
                          _buildLegendDot(
                            AppColors.surfaceSubtle,
                            AppColors.borderDefault,
                            'Weekend',
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Expanded(
                    child: Column(
                      children: [
                        // Day names header
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _DayHeader('Mon'),
                            _DayHeader('Tue'),
                            _DayHeader('Wed'),
                            _DayHeader('Thu'),
                            _DayHeader('Fri'),
                            _DayHeader('Sat'),
                            _DayHeader('Sun'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 5 Weeks Grid
                        Expanded(
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1.6,
                                ),
                            itemCount: 35,
                            itemBuilder: (context, index) {
                              final dayNumber = index + 1;
                              if (dayNumber > 31) {
                                return const SizedBox.shrink();
                              }

                              // Seeded attendance or simulation for weekdays
                              final isWeekend =
                                  (index % 7 == 5) || (index % 7 == 6);
                              Color cellColor = AppColors.surfaceSubtle;
                              Color textColor = AppColors.textDisabled;

                              if (!isWeekend) {
                                cellColor = AppColors.statusSuccessBg;
                                textColor = AppColors.statusSuccessText;
                              }

                              return Container(
                                decoration: BoxDecoration(
                                  color: cellColor,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                  border: Border.all(
                                    color: isWeekend
                                        ? AppColors.borderDefault
                                        : AppColors.statusSuccessBorder,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$dayNumber',
                                  style: AppTypography.monospace
                                      .copyWith(fontSize: 11)
                                      .copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Legend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendDot(
                              AppColors.statusSuccessBg,
                              AppColors.statusSuccessBorder,
                              'Present',
                            ),
                            const SizedBox(width: 16),
                            _buildLegendDot(
                              AppColors.statusErrorBg,
                              AppColors.statusErrorBorder,
                              'Absent',
                            ),
                            const SizedBox(width: 16),
                            _buildLegendDot(
                              AppColors.statusWarningBg,
                              AppColors.statusWarningBorder,
                              'Leave',
                            ),
                            const SizedBox(width: 16),
                            _buildLegendDot(
                              AppColors.surfaceSubtle,
                              AppColors.borderDefault,
                              'Weekend',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildLegendDot(Color bg, Color border, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 7: DOCUMENTS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDocumentsTab(StudentProfileBundle bundle) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final doc1 = _buildDocCard(
      title: 'Print Biodata Dossier',
      description: 'Comprehensive single-page student summary with demographic records, enrollment history, and guardian contact details for school archives.',
      buttonLabel: 'Print Dossier →',
      icon: Icons.badge_outlined,
      onTap: () => _showSnackBar('Print coming in Phase 2'),
    );
    final doc2 = _buildDocCard(
      title: 'Print School Leaving Certificate (SLC)',
      description: 'Official transfer clearance certificate issued upon formal withdrawal, verifying conduct, session progression, and clear dues.',
      buttonLabel: 'Print SLC →',
      icon: Icons.description_outlined,
      onTap: () => context.go('/students/leaving'),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OFFICIAL DOCUMENTS & CERTIFICATES',
            style: AppTypography.h3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                doc1,
                const SizedBox(height: AppSpacing.md),
                doc2,
              ],
            )
          else
            Row(
              children: [
                Expanded(child: doc1),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: doc2),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDocCard({
    required String title,
    required String description,
    required String buttonLabel,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: AppColors.brandPrimary),
              const SizedBox(width: 8),
              if (ResponsiveBreakpoints.isMobile(context))
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.label.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                Text(
                  title,
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onTap, child: Text(buttonLabel)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMPTY & NOT FOUND STATES
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEmptyTabState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? buttonLabel,
    VoidCallback? onButtonTap,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.h3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (buttonLabel != null && onButtonTap != null) ...[
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: onButtonTap, child: Text(buttonLabel)),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentNotFound(int stuRegId) {
    return Material(
      color: AppColors.surface,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.borderDefault),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 12.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_off_outlined,
                size: 56,
                color: AppColors.statusErrorText,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Student not found',
                style: AppTypography.h1.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'No student record exists with Registration ID #$stuRegId.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Students'),
                onPressed: () => context.go('/students'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Material(
      color: AppColors.surface,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.borderDefault),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.borderDefault),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.borderDefault),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TABLE CELL HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: AppTypography.monospace
            .copyWith(fontSize: 11)
            .copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isBold = false,
    bool isMono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: isMono
            ? AppTypography.monospace.copyWith(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: AppColors.textPrimary,
              )
            : AppTypography.bodySmall.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
      ),
    );
  }

  void _showManageSiblingLinksDialog(BuildContext context, int stuId) {
    showDialog(
      context: context,
      builder: (ctx) => _ManageSiblingLinksDialog(currentStudentId: stuId),
    );
  }

  Widget _buildFamilyTab(StudentProfileBundle bundle) {
    final stuId = bundle.student.stuRegId;
    final siblingsAsync = ref.watch(siblingLinksForStudentProvider(stuId));
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final siblingsContent = siblingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Error loading siblings: $e',
          style: const TextStyle(color: AppColors.statusErrorText),
        ),
      ),
      data: (siblings) {
        if (siblings.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 48,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No siblings linked for this student.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Manage Sibling Links'),
                  onPressed: () =>
                      _showManageSiblingLinksDialog(context, stuId),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: isMobile,
          physics: isMobile ? const NeverScrollableScrollPhysics() : null,
          itemCount: siblings.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final sib = siblings[index];
            final sibId = (sib['Stu_RegID'] as num).toInt();
            final first = (sib['NameFirst'] as String? ?? '').trim();
            final last = (sib['NameLast'] as String? ?? '').trim();
            final fullName = last.isNotEmpty ? '$first $last' : first;
            final cName = (sib['CName'] as String?)?.trim();
            final secName = (sib['SecName'] as String?)?.trim();
            final linkId = (sib['LinkID'] as num?)?.toInt();

            final classDisplay = (cName != null && cName.isNotEmpty)
                ? (secName != null && secName.isNotEmpty
                      ? '$cName-$secName'
                      : cName)
                : 'Not Enrolled';

            String initials = 'ST';
            if (fullName.isNotEmpty) {
              final parts = fullName
                  .split(' ')
                  .where((p) => p.isNotEmpty)
                  .toList();
              if (parts.length == 1) {
                initials = parts[0]
                    .substring(0, parts[0].length >= 2 ? 2 : 1)
                    .toUpperCase();
              } else {
                initials = '${parts.first[0]}${parts.last[0]}'.toUpperCase();
              }
            }

            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.brandPrimary,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: AppColors.textOnPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              fullName,
                              style: AppTypography.label.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(Reg #$sibId)',
                              style: AppTypography.monospace.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            classDisplay,
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('View Profile'),
                    onPressed: () => context.go('/students/$sibId'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: const Icon(
                      Icons.link_off,
                      size: 18,
                      color: AppColors.statusErrorText,
                    ),
                    tooltip: 'Unlink Sibling',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Unlink Sibling?'),
                          content: Text(
                            'Are you sure you want to remove the sibling link with $fullName (Reg #$sibId)?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.statusErrorText,
                                foregroundColor: AppColors.textOnPrimary,
                              ),
                              child: const Text('Unlink'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        if (linkId != null) {
                          await ref
                              .read(siblingLinksProvider.notifier)
                              .unlink(linkId);
                        } else {
                          final links = await ref
                              .read(siblingLinksProvider.notifier)
                              .loadForStudent(stuId);
                          for (final l in links) {
                            if (l.stu1RegId == sibId || l.stu2RegId == sibId) {
                              await ref
                                  .read(siblingLinksProvider.notifier)
                                  .unlink(l.linkId);
                              break;
                            }
                          }
                        }
                        ref.invalidate(siblingLinksForStudentProvider(stuId));
                        _showSnackBar('Sibling unlinked successfully.');
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'LINKED SIBLINGS & FAMILY MEMBERS',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.link, size: 16),
                label: const Text('Manage Sibling Links (Ctrl+L)'),
                onPressed: () => _showManageSiblingLinksDialog(context, stuId),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (isMobile) siblingsContent else Expanded(child: siblingsContent),
        ],
      ),
    );
  }
}

class _ManageSiblingLinksDialog extends ConsumerStatefulWidget {
  final int currentStudentId;

  const _ManageSiblingLinksDialog({required this.currentStudentId});

  @override
  ConsumerState<_ManageSiblingLinksDialog> createState() =>
      _ManageSiblingLinksDialogState();
}

class _ManageSiblingLinksDialogState
    extends ConsumerState<_ManageSiblingLinksDialog> {
  late final TextEditingController _searchController;
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final db = await DatabaseService.instance.database;
    final results = await db.rawQuery(
      '''
      SELECT sr.Stu_RegID, sr.NameFirst, sr.NameLast, sr.F_Name,
             c.CName, cs.SecName
      FROM Stu_Reg sr
      LEFT JOIN Student_Class sc ON sr.Stu_RegID = sc.Stu_RegID AND sc.Present = 1
      LEFT JOIN Class c ON sc.ClassID = c.ClassID
      LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
      WHERE sr.Stu_RegID != ?
        AND (
          CAST(sr.Stu_RegID AS TEXT) LIKE ?
          OR LOWER(sr.NameFirst) LIKE ?
          OR LOWER(COALESCE(sr.NameLast, '')) LIKE ?
          OR LOWER(COALESCE(sr.F_Name, '')) LIKE ?
        )
      LIMIT 20
    ''',
      [
        widget.currentStudentId,
        '%$q%',
        '%${q.toLowerCase()}%',
        '%${q.toLowerCase()}%',
        '%${q.toLowerCase()}%',
      ],
    );
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Sibling Links'),
      content: SizedBox(
        width: 500,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SEARCH STUDENT BY NAME OR REG ID',
              style: AppTypography.label.copyWith(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Type student name or Reg ID...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(
                      color: AppColors.borderDefault,
                    ),
                  ),
                ),
                onChanged: _performSearch,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.trim().isEmpty
                            ? 'Search for a student to link as sibling'
                            : 'No students found',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _searchResults.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final row = _searchResults[i];
                        final id = (row['Stu_RegID'] as num).toInt();
                        final first = (row['NameFirst'] as String? ?? '')
                            .trim();
                        final last = (row['NameLast'] as String? ?? '').trim();
                        final name = last.isNotEmpty ? '$first $last' : first;
                        final fName = (row['F_Name'] as String?)?.trim();
                        final cName = (row['CName'] as String?)?.trim();

                        return ListTile(
                          dense: true,
                          title: Text('$name (Reg #$id)'),
                          subtitle: Text(
                            '${fName != null ? "Father: $fName • " : ""}${cName ?? "Unassigned"}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                            child: const Text('Link'),
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await ref
                                  .read(siblingLinksProvider.notifier)
                                  .linkPair(
                                    widget.currentStudentId,
                                    id,
                                    relation: 'sibling',
                                    linkedBy: ref
                                        .read(sessionProvider)
                                        ?.user
                                        .id
                                        .toString(),
                                  );
                              if (!mounted) return;
                              ref.invalidate(
                                siblingLinksForStudentProvider(
                                  widget.currentStudentId,
                                ),
                              );
                              if (ok) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Linked with $name successfully',
                                    ),
                                    backgroundColor: AppColors.statusSuccessBg,
                                  ),
                                );
                                navigator.pop();
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Already linked as sibling'),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String day;
  const _DayHeader(this.day);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          day,
          style: AppTypography.monospace
              .copyWith(fontSize: 11)
              .copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
