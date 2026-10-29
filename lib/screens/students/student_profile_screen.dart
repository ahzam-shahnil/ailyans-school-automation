import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/shell_metadata_provider.dart';
import '../../core/providers/student_list_provider.dart';
import '../../core/providers/student_profile_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/biodata_pdf_generator.dart';
import '../../core/utils/photo_picker.dart';
import '../../models/student.dart';
import '../../repositories/photo_repository.dart';

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
    final activeTab = ref.watch(selectedStudentTabProvider);

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
              ref.read(studentEditModeProvider.notifier).state = !isEditMode;
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
          },
          child: Focus(
            autofocus: true,
            child: Material(
              color: AppColors.surface,
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Breadcrumb Bar
                    _buildBreadcrumb(bundle.student, activeTab, isEditMode),
                    const SizedBox(height: AppSpacing.md),

                    // Top Hero Profile Card
                    _buildHeroCard(bundle, isEditMode),
                    const SizedBox(height: AppSpacing.md),

                    // Tab Switcher
                    _buildTabBar(activeTab),
                    const SizedBox(height: AppSpacing.md),

                    // Tab Canvas (Expanded)
                    Expanded(
                      child: _buildTabContent(bundle, activeTab, isEditMode),
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
  Widget _buildHeroCard(StudentProfileBundle bundle, bool isEditMode) {
    final student = bundle.student;
    final isLeft = student.remarls?.toLowerCase().contains('left') ?? false;

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
                    Container(
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
                        style: AppTypography.monospace
                            .copyWith(fontSize: 11)
                            .copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isLeft
                            ? AppColors.surfaceSubtle
                            : AppColors.statusSuccessBg,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: isLeft
                              ? AppColors.borderDefault
                              : AppColors.statusSuccessBorder,
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
                              color: isLeft
                                  ? AppColors.textDisabled
                                  : AppColors.statusSuccessText,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isLeft ? 'Left' : 'Active',
                            style: AppTypography.label.copyWith(
                              color: isLeft
                                  ? AppColors.textSecondary
                                  : AppColors.statusSuccessText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Class + Section + Roll No
                Row(
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Class ${bundle.currentClassName}-${bundle.currentSectionName}  •  Roll: ${bundle.classRollNo}',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Father + Mobile
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Father: ${bundle.fatherName}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '•',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      bundle.mobile1,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Fee Balance summary
                Row(
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
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Profile (F2)'),
              onPressed: () {
                _populateForm(student);
                ref.read(studentEditModeProvider.notifier).state = true;
              },
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('Print Biodata'),
              onPressed: () async {
                final meta = ref.read(shellMetadataProvider).value;
                final stuId = int.tryParse(widget.studentId) ?? -1;
                final data = await buildBiodataPrintData(stuId, ref);
                if (!mounted) return;
                await showBiodataPrintPreviewDialog(
                  context,
                  data: data,
                  branchName:
                      meta?.branchName ??
                      "Ailyans's Higher Secondary School Mianwali",
                  branchAddress: meta?.branchAddress ?? 'Muslim Bazar Mianwali',
                  branchPhone: meta?.branchPhone,
                  branchPrincipal: meta?.branchPrincipal,
                );
              },
            ),
            if (isLeft) ...[
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Print SLC'),
                onPressed: () => context.go('/students/leaving'),
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
    return Container(
      height: 42,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderDefault, width: 1.0),
        ),
      ),
      child: Row(
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
      ),
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
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: OVERVIEW (VIEW VS EDIT)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOverviewTab(StudentProfileBundle bundle, bool isEditMode) {
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

          // Scrollable Sections
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildViewField('First Name', student.nameFirst)),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'Middle Name (Optional)',
                student.nameMiddle ?? '—',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField('Last Name', student.nameLast ?? '—'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildViewField('Date of Birth', student.formattedDob),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: _buildViewField('Gender', student.sex ?? 'Male')),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'Student B-Form / Bay-Form No.',
                student.bFormNo ?? '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildViewField(
                'Nationality',
                student.nationality ?? 'Pakistani',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'Religion / Community',
                student.religion ?? 'Islam',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'Blood Group',
                student.docsDetail?.isNotEmpty == true
                    ? student.docsDetail!
                    : 'B+',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Section 2: Guardian & Family Details
        _buildSectionHeader(
          '2. Guardian & Family Details',
          Icons.family_restroom_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildViewField(
                'Father / Guardian Name',
                student.fName ?? '—',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField('Father CNIC', student.cnicNo ?? '—'),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'Occupation / Profession',
                student.occupation ?? '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildViewField(
                'Previous School Attended',
                student.pSchool ?? '—',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'Previous Class Attended',
                student.pClass ?? '—',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'School Leaving Certificate (SLC)',
                student.slCertificate ?? '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Section 3: Contact & Address Specifications
        _buildSectionHeader(
          '3. Contact Channels & Residential Address',
          Icons.contact_phone_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildViewField(
                'Primary Mobile 1 (SMS Alert)',
                student.mobile1 ?? '—',
                trailing: InkWell(
                  onTap: () {
                    if (student.mobile1 != null &&
                        student.mobile1!.isNotEmpty) {
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
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'Secondary Mobile 2 (Landline / WhatsApp)',
                student.mobile2 ?? '—',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'Emergency Contact Person',
                student.emerContName ?? '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildViewField(
                'Emergency Contact Mobile',
                student.emerContMobile ?? '—',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'Permanent Residential Address',
                student.pAddress ?? '—',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'Present Mailing Address',
                student.tAddress ?? 'Same as permanent',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Section 4: Academic Placement & Fee Concessions
        _buildSectionHeader(
          '4. Academic Placement & Fee Concessions',
          Icons.school_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildViewField(
                'Admitted In Class',
                'Class ${student.admInClass ?? student.admClass ?? 13}',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'Current Enrolled Class',
                'Class ${bundle.currentClassName}-${bundle.currentSectionName}',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'Date of Initial Admission',
                student.formattedDoAdmission,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildViewField(
                'Monthly Tuition Concession',
                'Rs. ${student.discount != null ? student.discount!.toStringAsFixed(2) : "0.00"}',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildViewField(
                'Voucher Adjustment Concession',
                'Rs. ${student.vmDiscount != null ? student.vmDiscount!.toString() : "0.00"}',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildViewField(
                    'Full Fee Waiver',
                    student.fullDiscount == 1
                        ? 'Yes (100% Full Concession)'
                        : 'No',
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
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildViewField(
                'Administrative Remarks & Admission Notes',
                student.remarls ?? '—',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brandPrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(
                label: 'First Name *',
                controller: _firstNameController,
                focusNode: _firstNameFocus,
                hintText: 'e.g. Muhammad',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildFormField(
                label: 'Middle Name (Optional)',
                controller: _middleNameController,
                hintText: 'e.g. Ali',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildFormField(
                label: 'Last Name',
                controller: _lastNameController,
                hintText: 'e.g. Khan',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDatePickerField(
                label: 'Date of Birth *',
                value: _selectedDob,
                onSelected: (date) => setState(() => _selectedDob = date),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Gender *',
                value: _selectedSex,
                items: const ['Male', 'Female'],
                onChanged: (val) => setState(() => _selectedSex = val),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildFormField(
                label: 'Student B-Form / Bay-Form No.',
                controller: _bFormController,
                hintText: '38302-XXXXXXX-X',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(
                label: 'Nationality',
                controller: _nationalityController,
                hintText: 'Pakistani',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Religion / Community',
                value: _selectedReligion,
                items: const ['Islam', 'Christianity', 'Hinduism', 'Other'],
                onChanged: (val) => setState(() => _selectedReligion = val),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildFormField(
                label: 'Blood Group',
                controller: TextEditingController(text: 'B+'),
                hintText: 'B+',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Section 2
        _buildSectionHeader(
          '2. Guardian & Family Details',
          Icons.family_restroom_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(
                label: 'Father / Guardian Name *',
                controller: _fatherNameController,
                focusNode: _fatherNameFocus,
                hintText: 'Father full name',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildFormField(
                label: 'Father CNIC *',
                controller: _cnicController,
                focusNode: _cnicFocus,
                hintText: '38302-XXXXXXX-X',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildFormField(
                label: 'Occupation / Profession',
                controller: _occupationController,
                hintText: 'e.g. Civil Engineer',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(
                label: 'Previous School Attended',
                controller: _pSchoolController,
                hintText: 'Previous school name',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildFormField(
                label: 'Previous Class Attended',
                controller: _pClassController,
                hintText: 'e.g. Class 9',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildFormField(
                label: 'School Leaving Certificate (SLC)',
                controller: _slCertificateController,
                hintText: 'Certificate reference',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Section 3
        _buildSectionHeader(
          '3. Contact Channels & Residential Address',
          Icons.contact_phone_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(
                label: 'Primary Mobile 1 (SMS Alert) *',
                controller: _mobile1Controller,
                focusNode: _mobile1Focus,
                hintText: '0300-XXXXXXX',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildFormField(
                label: 'Secondary Mobile 2',
                controller: _mobile2Controller,
                hintText: '0321-XXXXXXX',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildFormField(
                label: 'Emergency Contact Person',
                controller: _emerContNameController,
                hintText: 'Name & relation',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(
                label: 'Emergency Contact Mobile',
                controller: _emerContMobileController,
                hintText: '0345-XXXXXXX',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildFormField(
                label: 'Permanent Residential Address',
                controller: _pAddressController,
                hintText: 'Permanent street address, city',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
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
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Section 4
        _buildSectionHeader(
          '4. Academic Placement & Fee Concessions',
          Icons.school_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: classesAsync.when(
                loading: () => const SizedBox(
                  height: 40,
                  child: LinearProgressIndicator(),
                ),
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
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildDatePickerField(
                label: 'Date of Initial Admission',
                value: _selectedDoAdmission,
                onSelected: (date) =>
                    setState(() => _selectedDoAdmission = date),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildFormField(
                label: 'Monthly Tuition Concession (Rs.)',
                controller: _discountController,
                hintText: '0.00',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(
                label: 'Voucher Adjustment Concession (Rs.)',
                controller: _vmDiscountController,
                hintText: '0',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
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
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildFormField(
                label: 'Administrative Remarks',
                controller: _remarksController,
                hintText: 'Notes / transfer info',
              ),
            ),
          ],
        ),
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
                    'View Mode — Press F2 or click Edit Profile to unlock and modify student registration fields.',
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
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit Profile (F2)'),
                      onPressed: () {
                        _populateForm(student);
                        ref.read(studentEditModeProvider.notifier).state = true;
                      },
                    ),
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
              Text(
                'ACADEMIC ENROLLMENT & PROMOTION TIMELINE',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
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
          else
            Expanded(
              child: SingleChildScrollView(
                child: ClipRRect(
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
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceSubtle,
                          ),
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
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
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
                ),
              ),
            ),
        ],
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

    return Column(
      children: [
        // 3 KPI Cards Row
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'TOTAL BILLED (2017-2018 SESSION)',
                value: 'Rs. ${currencyFormat.format(totalBilled)}',
                subtitle:
                    '${vouchers.length} Regular Voucher${vouchers.length == 1 ? "" : "s"} Generated',
                icon: Icons.receipt_long_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildKpiCard(
                title: 'TOTAL PAID TO DATE',
                value: 'Rs. ${currencyFormat.format(totalPaid)}',
                valueColor: AppColors.statusSuccessText,
                subtitle: '$realizationRate% Realization Rate',
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildKpiCard(
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
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Voucher Table Card
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.borderDefault),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
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
                      const Spacer(),
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
                        onPressed: () =>
                            _showSnackBar('Print coming in Phase 2'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
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
                  const SizedBox(height: AppSpacing.md),

                  // Table or Empty state
                  if (vouchers.isEmpty)
                    _buildEmptyTabState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No vouchers issued yet',
                      subtitle: 'No monthly tuition or fee vouchers have been created for this student registration.',
                      buttonLabel: 'Generate Voucher',
                      onButtonTap: () => context.go('/fees/vouchers'),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderDefault),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.8),
                            1: FlexColumnWidth(1.8),
                            2: FlexColumnWidth(1.5),
                            3: FlexColumnWidth(1.5),
                            4: FlexColumnWidth(1.5),
                            5: FlexColumnWidth(1.3),
                            6: FlexColumnWidth(1.5),
                            7: FlexColumnWidth(1.5),
                            8: FlexColumnWidth(1.3),
                            9: FlexColumnWidth(1.6),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceSubtle,
                              ),
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
                              final isPaid = v.isPaid == 'Y';
                              return TableRow(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: AppColors.borderDefault,
                                    ),
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
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
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
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(50, 30),
                                      ),
                                      child: Text(
                                        'Print Receipt →',
                                        style: AppTypography.label.copyWith(
                                          fontSize: 11,
                                          color: AppColors.brandPrimary,
                                        ),
                                      ),
                                      onPressed: () => _showSnackBar(
                                        'Print coming in Phase 2',
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            if (dayNumber > 31) return const SizedBox.shrink();

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
          Row(
            children: [
              Expanded(
                child: _buildDocCard(
                  title: 'Print Biodata Dossier',
                  description: 'Comprehensive single-page student summary with demographic records, enrollment history, and guardian contact details for school archives.',
                  buttonLabel: 'Print Dossier →',
                  icon: Icons.badge_outlined,
                  onTap: () => _showSnackBar('Print coming in Phase 2'),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _buildDocCard(
                  title: 'Print School Leaving Certificate (SLC)',
                  description: 'Official transfer clearance certificate issued upon formal withdrawal, verifying conduct, session progression, and clear dues.',
                  buttonLabel: 'Print SLC →',
                  icon: Icons.description_outlined,
                  onTap: () => context.go('/students/leaving'),
                ),
              ),
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
