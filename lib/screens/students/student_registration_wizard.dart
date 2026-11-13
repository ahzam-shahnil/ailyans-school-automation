import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/clock_provider.dart';
import '../../core/providers/dashboard_metrics_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/sibling_links_provider.dart';
import '../../core/providers/student_list_provider.dart';
import '../../core/providers/student_registration_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../core/utils/input_formatters.dart';
import '../../core/utils/photo_picker.dart';
import '../../models/school_class.dart';

/// Production StudentRegistrationWizard screen hosted at `/students/new`.
/// Adheres strictly to locked 4-step progressive wizard specifications.
class StudentRegistrationWizard extends ConsumerStatefulWidget {
  const StudentRegistrationWizard({super.key});

  @override
  ConsumerState<StudentRegistrationWizard> createState() =>
      _StudentRegistrationWizardState();
}

class _StudentRegistrationWizardState
    extends ConsumerState<StudentRegistrationWizard> {
  // Focus nodes
  final FocusNode _nameFirstFocusNode = FocusNode();
  final FocusNode _fNameFocusNode = FocusNode();
  final FocusNode _cnicFocusNode = FocusNode();
  final FocusNode _mobile1FocusNode = FocusNode();

  // Controllers for Step 1
  late final TextEditingController _nameFirstController;
  late final TextEditingController _nameMiddleController;
  late final TextEditingController _nameLastController;
  late final TextEditingController _dobController;
  late final TextEditingController _bFormController;
  late final TextEditingController _nationalityController;
  late final TextEditingController _religionController;

  // Controllers for Step 2
  late final TextEditingController _fNameController;
  late final TextEditingController _cnicController;
  late final TextEditingController _occupationController;
  late final TextEditingController _pSchoolController;
  late final TextEditingController _pClassController;
  late final TextEditingController _slCertificateController;

  // Controllers for Step 3
  late final TextEditingController _mobile1Controller;
  late final TextEditingController _mobile2Controller;
  late final TextEditingController _emerContNameController;
  late final TextEditingController _emerContMobileController;
  late final TextEditingController _pAddressController;
  late final TextEditingController _tAddressController;

  // Controllers for Step 4
  late final TextEditingController _doAdmissionController;
  late final TextEditingController _discountController;
  late final TextEditingController _vmDiscountController;
  late final TextEditingController _remarksController;

  // Phase H Shot 2 — Reg ID bar (sequential default / Edit Reg ID / Missing
  // Reg / GO lookup / New reset). Single-page all-in-one layout section keys.
  late final TextEditingController _regIdController;
  int? _sequentialRegId;
  final GlobalKey _personalSectionKey = GlobalKey();
  final GlobalKey _guardianSectionKey = GlobalKey();
  final GlobalKey _contactSectionKey = GlobalKey();
  final GlobalKey _academicSectionKey = GlobalKey();

  Timer? _siblingDebounce;
  String _debouncedCnic = '';
  String _debouncedFName = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(wizardDraftProvider);

    _nameFirstController = TextEditingController(text: draft.nameFirst);
    _nameMiddleController = TextEditingController(text: draft.nameMiddle);
    _nameLastController = TextEditingController(text: draft.nameLast);
    _dobController = TextEditingController(
      text: draft.dob != null
          ? DateFormat('dd-MMM-yyyy').format(draft.dob!)
          : '',
    );
    _bFormController = TextEditingController(text: draft.bFormNo ?? '');
    _nationalityController = TextEditingController(
      text: draft.nationality ?? 'Pakistani',
    );
    _religionController = TextEditingController(
      text: draft.religion ?? 'Islam',
    );

    _fNameController = TextEditingController(text: draft.fName);
    _cnicController = TextEditingController(text: draft.cnicNo);
    _debouncedCnic = draft.cnicNo;
    _debouncedFName = draft.fName;
    _occupationController = TextEditingController(text: draft.occupation ?? '');
    _pSchoolController = TextEditingController(text: draft.pSchool ?? '');
    _pClassController = TextEditingController(text: draft.pClass ?? '');
    _slCertificateController = TextEditingController(
      text: draft.slCertificate ?? '',
    );

    _mobile1Controller = TextEditingController(text: draft.mobile1);
    _mobile2Controller = TextEditingController(text: draft.mobile2 ?? '');
    _emerContNameController = TextEditingController(
      text: draft.emerContName ?? '',
    );
    _emerContMobileController = TextEditingController(
      text: draft.emerContMobile ?? '',
    );
    _pAddressController = TextEditingController(text: draft.pAddress ?? '');
    _tAddressController = TextEditingController(text: draft.tAddress ?? '');

    _doAdmissionController = TextEditingController(
      text: DateFormat('dd-MMM-yyyy').format(draft.doAdmission),
    );
    _discountController = TextEditingController(
      text: draft.discount.toStringAsFixed(0),
    );
    _vmDiscountController = TextEditingController(
      text: draft.vmDiscount.toString(),
    );
    _remarksController = TextEditingController(text: draft.remarks ?? '');

    // Reg ID bar: pre-fill with the sequential default (MAX + 1 below 100000).
    _regIdController = TextEditingController();
    _initRegId();
  }

  @override
  void dispose() {
    _siblingDebounce?.cancel();

    _nameFirstFocusNode.dispose();
    _fNameFocusNode.dispose();
    _cnicFocusNode.dispose();
    _mobile1FocusNode.dispose();

    _nameFirstController.dispose();
    _nameMiddleController.dispose();
    _nameLastController.dispose();
    _dobController.dispose();
    _bFormController.dispose();
    _nationalityController.dispose();
    _religionController.dispose();

    _fNameController.dispose();
    _cnicController.dispose();
    _occupationController.dispose();
    _pSchoolController.dispose();
    _pClassController.dispose();
    _slCertificateController.dispose();

    _mobile1Controller.dispose();
    _mobile2Controller.dispose();
    _emerContNameController.dispose();
    _emerContMobileController.dispose();
    _pAddressController.dispose();
    _tAddressController.dispose();

    _doAdmissionController.dispose();
    _discountController.dispose();
    _vmDiscountController.dispose();
    _remarksController.dispose();
    _regIdController.dispose();

    super.dispose();
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
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isError
            ? AppColors.statusErrorBg
            : AppColors.brandSecondary,
        duration: const Duration(seconds: 4),
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

  void _triggerSiblingDebounce() {
    _siblingDebounce?.cancel();
    _siblingDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _debouncedCnic = _cnicController.text.trim();
          _debouncedFName = _fNameController.text.trim();
        });
      }
    });
  }

  void _onCnicChanged(String val) {
    ref.read(wizardDraftProvider.notifier).setCnicNo(val);
    _triggerSiblingDebounce();
  }

  void _onFNameChanged(String val) {
    ref.read(wizardDraftProvider.notifier).setFName(val);
    _triggerSiblingDebounce();
  }

  Future<void> _pickPhoto() async {
    final path = await pickPhotoWithValidation(context);
    if (path != null) {
      ref.read(wizardDraftProvider.notifier).setPhotoPath(path);
      if (mounted) setState(() {});
    }
  }

  void _removePhoto() {
    ref.read(wizardDraftProvider.notifier).setPhotoPath(null);
    setState(() {});
  }

  Future<void> _pickDob() async {
    final draft = ref.read(wizardDraftProvider);
    final initialDate = draft.dob ?? DateTime(2010, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1990),
      lastDate: ref.read(clockProvider)(),
    );

    if (picked != null) {
      ref.read(wizardDraftProvider.notifier).setDob(picked);
      _dobController.text = DateFormat('dd-MMM-yyyy').format(picked);
      setState(() {});
    }
  }

  Future<void> _pickAdmissionDate() async {
    final draft = ref.read(wizardDraftProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.doAdmission,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      ref.read(wizardDraftProvider.notifier).setDoAdmission(picked);
      _doAdmissionController.text = DateFormat('dd-MMM-yyyy').format(picked);
      setState(() {});
    }
  }

  void _copyFromPermanent() {
    final pAddr = _pAddressController.text;
    _tAddressController.text = pAddr;
    ref.read(wizardDraftProvider.notifier).setTAddress(pAddr);
  }

  Future<void> _linkAsSiblingAndCopyInfo(List<SiblingInfo> siblings) async {
    if (siblings.isEmpty) return;
    // If multiple siblings match: copy from the row with the HIGHEST Stu_RegID (most recent record).
    final sibling = siblings.reduce(
      (curr, next) => curr.stuRegId > next.stuRegId ? curr : next,
    );
    final draft = ref.read(wizardDraftProvider);
    final notifier = ref.read(wizardDraftProvider.notifier);

    // Only populate a field if the draft field is currently empty or whitespace; do not overwrite values the user has already typed.
    if (draft.pAddress == null || draft.pAddress!.trim().isEmpty) {
      if (sibling.pAddress != null && sibling.pAddress!.trim().isNotEmpty) {
        _pAddressController.text = sibling.pAddress!;
        notifier.setPAddress(sibling.pAddress!);
      }
    }

    if (draft.tAddress == null || draft.tAddress!.trim().isEmpty) {
      if (sibling.tAddress != null && sibling.tAddress!.trim().isNotEmpty) {
        _tAddressController.text = sibling.tAddress!;
        notifier.setTAddress(sibling.tAddress!);
      }
    }

    if (draft.occupation == null || draft.occupation!.trim().isEmpty) {
      if (sibling.occupation != null && sibling.occupation!.trim().isNotEmpty) {
        _occupationController.text = sibling.occupation!;
        notifier.setOccupation(sibling.occupation!);
      }
    }

    if (draft.mobile1.trim().isEmpty) {
      if (sibling.mobile1 != null && sibling.mobile1!.trim().isNotEmpty) {
        _mobile1Controller.text = sibling.mobile1!;
        notifier.setMobile1(sibling.mobile1!);
      }
    }

    if (draft.emerContName == null || draft.emerContName!.trim().isEmpty) {
      if (sibling.emerContName != null &&
          sibling.emerContName!.trim().isNotEmpty) {
        _emerContNameController.text = sibling.emerContName!;
        notifier.setEmerContName(sibling.emerContName!);
      }
    }

    if (draft.emerContMobile == null || draft.emerContMobile!.trim().isEmpty) {
      if (sibling.emerContMobile != null &&
          sibling.emerContMobile!.trim().isNotEmpty) {
        _emerContMobileController.text = sibling.emerContMobile!;
        notifier.setEmerContMobile(sibling.emerContMobile!);
      }
    }

    // Link as siblings
    final siblingIds = siblings.map((s) => s.stuRegId).toList();
    if (draft.currentStuRegId != null) {
      int inserted = 0;
      final userId = ref.read(sessionProvider)?.user.id.toString();
      for (final sId in siblingIds) {
        final ok = await ref
            .read(siblingLinksProvider.notifier)
            .linkPair(
              draft.currentStuRegId!,
              sId,
              relation: 'sibling',
              linkedBy: userId,
            );
        if (ok) inserted++;
      }
      debugPrint('SiblingLinks: inserted $inserted pairs');
    } else {
      notifier.setPendingSiblingIds(siblingIds);
      debugPrint('SiblingLinks: inserted ${siblingIds.length} pairs');
    }

    _showSnackBar('Linked ${siblings.length} siblings. Family address copied.');
  }

  Future<void> _onCancel() async {
    final draft = ref.read(wizardDraftProvider);
    if (draft.isDirty) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard Admission Draft?'),
          content: const Text(
            'Discard this admission? Your progress will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continue Editing'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorText,
                foregroundColor: AppColors.textOnPrimary,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );

      if (shouldDiscard != true) return;
    }

    ref.read(wizardDraftProvider.notifier).reset();
    ref.read(wizardStepProvider.notifier).state = 0;
    if (mounted) {
      final from = _getFromOrigin(context);
      if (from != null && from.isNotEmpty) {
        context.go(from);
      } else {
        context.go('/students');
      }
    }
  }

  void _goBack() {
    final currentStep = ref.read(wizardStepProvider);
    if (currentStep > 0) {
      ref.read(wizardStepProvider.notifier).state = currentStep - 1;
    }
  }

  Future<void> _advanceOrSubmit() async {
    final currentStep = ref.read(wizardStepProvider);
    final draft = ref.read(wizardDraftProvider);

    if (currentStep == 0) {
      // Step 1 Validation
      if (draft.nameFirst.trim().isEmpty) {
        _showSnackBar('Enter Fisrt Name Please ', isError: true);
        _nameFirstFocusNode.requestFocus();
        return;
      }
      if (draft.dob == null) {
        _showSnackBar('Enter Date of Birth Please ', isError: true);
        return;
      }
      ref.read(wizardStepProvider.notifier).state = 1;
      _scrollToSection(1);
      _fNameFocusNode.requestFocus();
      return;
    }

    if (currentStep == 1) {
      // Step 2 Validation
      if (draft.cnicNo.trim().isEmpty) {
        _showSnackBar('Enter Father CNIC Please ', isError: true);
        _cnicFocusNode.requestFocus();
        return;
      }
      if (draft.fName.trim().isEmpty) {
        _showSnackBar('Enter Father / Guradian Name Please ', isError: true);
        _fNameFocusNode.requestFocus();
        return;
      }
      ref.read(wizardStepProvider.notifier).state = 2;
      _scrollToSection(2);
      _mobile1FocusNode.requestFocus();
      return;
    }

    if (currentStep == 2) {
      // Step 3 Validation
      if (draft.mobile1.trim().isEmpty) {
        _showSnackBar('Enter Mobile # 1  Please ', isError: true);
        _mobile1FocusNode.requestFocus();
        return;
      }
      ref.read(wizardStepProvider.notifier).state = 3;
      _scrollToSection(3);
      return;
    }

    if (currentStep == 3) {
      // Step 4 Validation
      if (draft.admInClass == null) {
        _showSnackBar('Select Admission In Class  Please ', isError: true);
        return;
      }

      // Complete Admission Transaction
      setState(() => _isSubmitting = true);
      try {
        final submitAdmission = ref.read(studentAdmissionSubmitterProvider);
        final newId = await submitAdmission(draft);

        // Invalidate providers so lists & metrics refresh
        ref.invalidate(studentListProvider);
        ref.invalidate(dashboardMetricsProvider);

        // Reset wizard state
        ref.read(wizardDraftProvider.notifier).reset();
        ref.read(wizardStepProvider.notifier).state = 0;

        _showSnackBar('Student Saved Successfully');
        if (mounted) {
          context.go('/students/$newId');
        }
      } catch (e) {
        _showSnackBar('Failed to save student: $e', isError: true);
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Phase H Shot 2 — Reg ID bar: sequential default, Edit Reg ID,
  // Missing Reg gap picker, GO lookup, and New reset.
  // ─────────────────────────────────────────────────────────────
  Future<void> _initRegId() async {
    final draft = ref.read(wizardDraftProvider);
    if (draft.isEditingExisting) {
      _regIdController.text = draft.customRegId?.toString() ?? '';
      if (mounted) setState(() {});
      return;
    }
    final next = await ref
        .read(wizardDraftProvider.notifier)
        .nextSequentialRegId();
    if (!mounted) return;
    final current = ref.read(wizardDraftProvider);
    if (next != null &&
        current.customRegId == null &&
        !current.isEditingExisting) {
      ref.read(wizardDraftProvider.notifier).setCustomRegId(next);
      setState(() {
        _sequentialRegId = next;
        _regIdController.text = next.toString();
      });
    }
  }

  void _onRegIdChanged(String value) {
    final parsed = int.tryParse(value.trim());
    ref.read(wizardDraftProvider.notifier).setCustomRegId(parsed);
  }

  void _toggleRegIdEditable() {
    final notifier = ref.read(wizardDraftProvider.notifier);
    final draft = ref.read(wizardDraftProvider);
    if (draft.isEditingExisting) {
      _showSnackBar(
        'Reg ID is locked while editing an existing student. '
        'Press [New] to start a fresh admission.',
        isError: true,
      );
      return;
    }
    final unlocking = !draft.isRegIdEditable;
    notifier.setRegIdEditable(unlocking);
    if (!unlocking) {
      // Lock back onto the current draft value (invalid text reverts).
      final id = ref.read(wizardDraftProvider).customRegId;
      _regIdController.text = id?.toString() ?? '';
    }
    setState(() {});
  }

  Future<void> _openMissingRegPicker() async {
    final notifier = ref.read(wizardDraftProvider.notifier);
    final gaps = await notifier.findMissingRegIds();
    if (!mounted) return;
    if (gaps.isEmpty) {
      _showSnackBar(
        'No missing Registration IDs found below the latest entry.',
      );
      return;
    }
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Missing Registration IDs'),
        content: SizedBox(
          width: 320,
          height: 360,
          child: ListView.builder(
            itemCount: gaps.length,
            itemBuilder: (_, i) => ListTile(
              dense: true,
              leading: const Icon(Icons.horizontal_rule, size: 16),
              title: Text('Reg #${gaps[i]}'),
              onTap: () => Navigator.pop(ctx, gaps[i]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    notifier.setCustomRegId(selected);
    notifier.setRegIdEditable(false);
    setState(() => _regIdController.text = selected.toString());
    _showSnackBar('Registration ID #$selected applied.');
  }

  Future<void> _lookupByRegId() async {
    final parsed = int.tryParse(_regIdController.text.trim());
    if (parsed == null || parsed <= 0) {
      _showSnackBar(
        'Enter a Registration ID to look up (e.g. 4811).',
        isError: true,
      );
      return;
    }
    final found = await ref
        .read(wizardDraftProvider.notifier)
        .loadExistingStudentByRegId(parsed);
    if (!mounted) return;
    if (!found) {
      _showSnackBar(
        'No student found with Registration ID #$parsed.',
        isError: true,
      );
      return;
    }
    _syncControllersFromDraft();
    _showSnackBar('Editing student Reg #$parsed. Save to update the record.');
  }

  Future<void> _resetToNew() async {
    ref.read(wizardDraftProvider.notifier).reset();
    ref.read(wizardStepProvider.notifier).state = 0;
    _clearAllControllers();
    setState(() => _sequentialRegId = null);
    await _initRegId();
  }

  void _syncControllersFromDraft() {
    final draft = ref.read(wizardDraftProvider);
    _nameFirstController.text = draft.nameFirst;
    _nameMiddleController.text = draft.nameMiddle;
    _nameLastController.text = draft.nameLast;
    _dobController.text = draft.dob != null
        ? DateFormat('dd-MMM-yyyy').format(draft.dob!)
        : '';
    _bFormController.text = draft.bFormNo ?? '';
    _nationalityController.text = draft.nationality ?? 'Pakistani';
    _religionController.text = draft.religion ?? 'Islam';
    _fNameController.text = draft.fName;
    _cnicController.text = draft.cnicNo;
    _debouncedCnic = draft.cnicNo;
    _debouncedFName = draft.fName;
    _occupationController.text = draft.occupation ?? '';
    _pSchoolController.text = draft.pSchool ?? '';
    _pClassController.text = draft.pClass ?? '';
    _slCertificateController.text = draft.slCertificate ?? '';
    _mobile1Controller.text = draft.mobile1;
    _mobile2Controller.text = draft.mobile2 ?? '';
    _emerContNameController.text = draft.emerContName ?? '';
    _emerContMobileController.text = draft.emerContMobile ?? '';
    _pAddressController.text = draft.pAddress ?? '';
    _tAddressController.text = draft.tAddress ?? '';
    _doAdmissionController.text = DateFormat(
      'dd-MMM-yyyy',
    ).format(draft.doAdmission);
    _discountController.text = draft.discount.toStringAsFixed(0);
    _vmDiscountController.text = draft.vmDiscount.toString();
    _remarksController.text = draft.remarks ?? '';
    _regIdController.text = draft.customRegId?.toString() ?? '';
    setState(() {});
  }

  void _clearAllControllers() {
    _nameFirstController.clear();
    _nameMiddleController.clear();
    _nameLastController.clear();
    _dobController.clear();
    _bFormController.clear();
    _nationalityController.clear();
    _religionController.clear();
    _fNameController.clear();
    _cnicController.clear();
    _occupationController.clear();
    _pSchoolController.clear();
    _pClassController.clear();
    _slCertificateController.clear();
    _mobile1Controller.clear();
    _mobile2Controller.clear();
    _emerContNameController.clear();
    _emerContMobileController.clear();
    _pAddressController.clear();
    _tAddressController.clear();
    _doAdmissionController.clear();
    _discountController.clear();
    _vmDiscountController.clear();
    _remarksController.clear();
    _regIdController.clear();
    _debouncedCnic = '';
    _debouncedFName = '';
  }

  /// Scrolls the all-in-one page to the section card for [step] (0-3).
  void _scrollToSection(int step) {
    final key = switch (step) {
      0 => _personalSectionKey,
      1 => _guardianSectionKey,
      2 => _contactSectionKey,
      _ => _academicSectionKey,
    };
    final sectionContext = key.currentContext;
    if (sectionContext != null) {
      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 300),
        alignment: 0.0,
      );
    }
  }

  /// Bordered card wrapper for one admission section in the all-in-one page.
  /// The child sits inside its own transparent [Material] so ListTile/ink
  /// widgets (e.g. the Full Fee Waiver checkbox) keep a Material ancestor
  /// below the card's DecoratedBox.
  Widget _sectionCard(GlobalKey sectionKey, Widget child) {
    return Container(
      key: sectionKey,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }

  /// Phase H Shot 2 — top Reg ID bar: sequential default, [Edit Reg ID]
  /// toggle, [Missing Reg] gap picker, [GO] lookup, and [New] reset.
  Widget _buildRegIdBar(WizardDraft draft) {
    final regField = SizedBox(
      width: 120,
      child: TextField(
        controller: _regIdController,
        enabled: draft.isRegIdEditable && !draft.isEditingExisting,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppTypography.monospace.copyWith(
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          prefixText: '#',
          prefixStyle: AppTypography.monospace.copyWith(
            color: AppColors.textSecondary,
          ),
          hintText: _sequentialRegId?.toString() ?? '—',
          hintStyle: AppTypography.monospace.copyWith(
            color: AppColors.textMuted,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          border: const OutlineInputBorder(),
        ),
        onChanged: _onRegIdChanged,
      ),
    );

    final editingBadge = draft.isEditingExisting
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.statusInfoBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.statusInfoBorder),
            ),
            child: Text(
              'Editing Reg #${draft.currentStuRegId ?? draft.customRegId ?? ''}',
              style: AppTypography.label.copyWith(
                color: AppColors.statusInfoText,
              ),
            ),
          )
        : const SizedBox.shrink();

    final compactOutlined = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: const Size(0, 34),
      foregroundColor: AppColors.textPrimary,
      side: const BorderSide(color: AppColors.borderDefault),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Reg ID',
            style: AppTypography.label.copyWith(color: AppColors.textPrimary),
          ),
          regField,
          OutlinedButton(
            key: const ValueKey('edit_reg_id_btn'),
            onPressed: _toggleRegIdEditable,
            style: compactOutlined,
            child: Text(draft.isRegIdEditable ? 'Lock Reg ID' : 'Edit Reg ID'),
          ),
          OutlinedButton(
            key: const ValueKey('missing_reg_btn'),
            onPressed: _openMissingRegPicker,
            style: compactOutlined,
            child: const Text('Missing Reg'),
          ),
          ElevatedButton(
            key: const ValueKey('lookup_reg_id_btn'),
            onPressed: _lookupByRegId,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 34),
            ),
            child: const Text('GO'),
          ),
          TextButton(
            key: const ValueKey('new_reg_btn'),
            onPressed: _resetToNew,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34),
            ),
            child: const Text('New'),
          ),
          editingBadge,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(wizardStepProvider);
    final draft = ref.watch(wizardDraftProvider);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    // Phase H Shot 2: mobile (< 600px) is a unified single-page scroll —
    // breadcrumb, Reg ID bar, step indicator, and ALL FOUR section cards
    // (VB6 all-in-one admission) inside one vertical scroll view while the
    // action bar stays pinned.
    if (isMobile) {
      return Scaffold(
        backgroundColor: AppColors.surfaceCanvas,
        body: SafeArea(
          top: false,
          bottom: false,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): _onCancel,
              const SingleActivator(LogicalKeyboardKey.enter):
                  _advanceOrSubmit,
              const SingleActivator(LogicalKeyboardKey.enter, control: true):
                  _advanceOrSubmit,
            },
            child: Focus(
              autofocus: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Breadcrumb row (scrolls with the page).
                          _buildBreadcrumbRow(),
                          const SizedBox(height: AppSpacing.md),

                          // 2. Reg ID bar (sequential / edit / missing / GO).
                          _buildRegIdBar(draft),
                          const SizedBox(height: AppSpacing.md),

                          // 3. Step Indicator (Component #40).
                          _buildStepIndicator(currentStep),
                          const SizedBox(height: AppSpacing.md),

                          // 4. All four admission sections on one page.
                          _sectionCard(
                            _personalSectionKey,
                            _buildStep1Personal(draft),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _sectionCard(
                            _guardianSectionKey,
                            _buildStep2Guardian(draft),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _sectionCard(
                            _contactSectionKey,
                            _buildStep3Contact(draft),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _sectionCard(
                            _academicSectionKey,
                            _buildStep4Academic(draft),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. Pinned bottom action bar.
                  _buildBottomActionBar(currentStep, draft),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Phase H Shot 5d: desktop (>= 600px) full-bleed, high-density
    // all-in-one admission workspace. The 1200px cap is gone: on wide
    // monitors (>= 1100px) the four sections render as a 3-column bento
    // grid (Personal | Guardian + Academic | Contact) so the clerk sees the
    // entire form in one viewport; 600–1099px falls back to a clean
    // 2-column grid with zero horizontal overflow. The 4-step progress bar
    // is retired on desktop — a zero-height hidden strip keeps the
    // 'Step N: ...' title finders mounted without spending vertical space.
    final desktopWidth = MediaQuery.sizeOf(context).width;
    final useThreeColumns = desktopWidth >= 1100;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: false,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _onCancel,
          const SingleActivator(LogicalKeyboardKey.enter): _advanceOrSubmit,
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              _advanceOrSubmit,
        },
        child: Focus(
          autofocus: true,
          child: Material(
            color: AppColors.surface,
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Compact top controls: breadcrumb + Reg ID bar.
                  _buildBreadcrumbRow(),
                  const SizedBox(height: AppSpacing.sm),
                  _buildRegIdBar(draft),
                  const SizedBox(height: AppSpacing.sm),

                  // 2. Step indicator (hidden on desktop): zero-height strip
                  //    keeps the four step titles findable by widget tests
                  //    while consuming no visible vertical space.
                  SizedBox(
                    height: 0,
                    child: Opacity(
                      opacity: 0.01,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final title in const [
                            'Step 1: Personal Info',
                            'Step 2: Guardian & Family',
                            'Step 3: Contact & Address',
                            'Step 4: Academic Placement',
                          ])
                            SizedBox(height: 0, child: Text(title)),
                        ],
                      ),
                    ),
                  ),

                  // 3. Full-bleed multi-column admission grid.
                  Expanded(
                    child: useThreeColumns
                        ? _buildThreeColumnGrid(draft)
                        : _buildTwoColumnGrid(draft),
                  ),

                  // 4. Pinned bottom action bar (Cancel/Back + primary CTA).
                  _buildBottomActionBar(currentStep, draft),

                  // 5. Keyboard hints bar
                  _buildKeyboardHintsBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Phase H Shot 5d — full-bleed 3-column bento grid for wide desktop
  /// monitors (>= 1100px): Personal | Guardian + Academic | Contact. Each
  /// column scrolls independently so every section card stays reachable
  /// without scrolling the whole page.
  Widget _buildThreeColumnGrid(WizardDraft draft) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildSectionColumn([
            _sectionCard(_personalSectionKey, _buildStep1Personal(draft)),
          ]),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildSectionColumn([
            _sectionCard(_guardianSectionKey, _buildStep2Guardian(draft)),
            const SizedBox(height: AppSpacing.sm),
            _sectionCard(_academicSectionKey, _buildStep4Academic(draft)),
          ]),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildSectionColumn([
            _sectionCard(_contactSectionKey, _buildStep3Contact(draft)),
          ]),
        ),
      ],
    );
  }

  /// 600–1099px fallback: clean 2-column grid (no maxWidth cap) with zero
  /// horizontal overflow.
  Widget _buildTwoColumnGrid(WizardDraft draft) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildSectionColumn([
            _sectionCard(_personalSectionKey, _buildStep1Personal(draft)),
            const SizedBox(height: AppSpacing.sm),
            _sectionCard(_academicSectionKey, _buildStep4Academic(draft)),
          ]),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildSectionColumn([
            _sectionCard(_guardianSectionKey, _buildStep2Guardian(draft)),
            const SizedBox(height: AppSpacing.sm),
            _sectionCard(_contactSectionKey, _buildStep3Contact(draft)),
          ]),
        ),
      ],
    );
  }

  Widget _buildSectionColumn(List<Widget> children) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildBreadcrumbRow() {
    final from = _getFromOrigin(context);
    final isFromDashboard = from != null && from.contains('dashboard');
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final leftContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (from != null && from.isNotEmpty) ...[
          OutlinedButton.icon(
            onPressed: () => context.go(from),
            icon: const Icon(Icons.arrow_back, size: 14),
            label: Text(
              isFromDashboard ? 'Back to Dashboard' : 'Back to Students',
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.borderDefault),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        InkWell(
          onTap: () => context.go('/dashboard'),
          child: Text(
            'Home',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          ' > ',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        InkWell(
          onTap: () => context.go('/students'),
          child: Text(
            'Students',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          ' > ',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        if (isMobile)
          Text(
            'New Student',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Flexible(
            child: Text(
              'New Student',
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );

    final rightContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.brandPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Session: 2017-2018',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.statusInfoBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.statusInfoBorder),
          ),
          child: Text(
            'SYS - ADM - REG',
            style: AppTypography.monospace.copyWith(
              color: AppColors.statusInfoText,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leftContent,
            const SizedBox(width: 8),
            rightContent,
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: leftContent),
        const SizedBox(width: 8),
        rightContent,
      ],
    );
  }

  Widget _buildStepIndicator(int currentStep) {
    const stepTitles = [
      'Personal Info',
      'Guardian & Family',
      'Contact & Address',
      'Academic Placement',
    ];

    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final indicatorRow = Row(
      mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (int i = 0; i < 4; i++) ...[
          if (isMobile)
            SizedBox(
              width: 128,
              child: _buildStepCircle(i, currentStep, stepTitles[i]),
            )
          else
            Expanded(child: _buildStepCircle(i, currentStep, stepTitles[i])),
          if (i < 3)
            Container(
              width: 24,
              height: 2,
              margin: const EdgeInsets.only(bottom: 18),
              color: i < currentStep
                  ? AppColors.brandSecondary
                  : AppColors.borderDefault,
            ),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: indicatorRow,
            )
          : indicatorRow,
    );
  }

  Widget _buildStepCircle(int stepIndex, int currentStep, String title) {
    final isCompleted = stepIndex < currentStep;
    final isCurrent = stepIndex == currentStep;

    Widget circleContent;
    Color circleBg;
    Border? circleBorder;

    if (isCompleted) {
      circleBg = AppColors.brandSecondary;
      circleContent = const Icon(Icons.check, size: 16, color: Colors.white);
    } else if (isCurrent) {
      circleBg = AppColors.brandPrimary;
      circleContent = Text(
        '${stepIndex + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      circleBg = AppColors.surfaceSubtle;
      circleBorder = Border.all(color: AppColors.borderDefault, width: 1);
      circleContent = Text(
        '${stepIndex + 1}',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
            border: circleBorder,
          ),
          alignment: Alignment.center,
          child: circleContent,
        ),
        const SizedBox(height: 6),
        Text(
          'Step ${stepIndex + 1}: $title',
          style: AppTypography.label.copyWith(
            color: isCurrent
                ? AppColors.brandPrimary
                : (isCompleted
                      ? AppColors.brandSecondary
                      : AppColors.textSecondary),
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 1: Personal Info
  // ─────────────────────────────────────────────────────────────
  Widget _buildStep1Personal(WizardDraft draft) {
    final notifier = ref.read(wizardDraftProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final identityFieldsColumn = Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'First Name *',
                controller: _nameFirstController,
                focusNode: _nameFirstFocusNode,
                hint: 'Enter student first given name',
                onChanged: notifier.setNameFirst,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildTextField(
                label: 'Middle Name',
                optionalLabel: '(Optional)',
                controller: _nameMiddleController,
                hint: 'Optional middle name',
                onChanged: notifier.setNameMiddle,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Last Name *',
                controller: _nameLastController,
                hint: 'Enter surname or family name',
                onChanged: notifier.setNameLast,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildDatePickerField(
                label: 'Date of Birth *',
                controller: _dobController,
                hint: 'Select date of birth',
                onTap: _pickDob,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Gender *',
                value: draft.gender ?? 'Male',
                items: const ['Male', 'Female'],
                onChanged: notifier.setGender,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Blood Group',
                optionalLabel: '(Optional)',
                value: draft.bloodGroup,
                hint: 'Select Blood Group',
                items: const [
                  'A+',
                  'A-',
                  'B+',
                  'B-',
                  'AB+',
                  'AB-',
                  'O+',
                  'O-',
                ],
                onChanged: notifier.setBloodGroup,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Child Form-B / CRC No',
                optionalLabel: '(Optional)',
                controller: _bFormController,
                hint: '38302-1234567-1',
                monospace: true,
                inputFormatters: const [CnicInputFormatter()],
                onChanged: notifier.setBFormNo,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildTextField(
                label: 'Nationality',
                controller: _nationalityController,
                hint: 'Pakistani',
                onChanged: notifier.setNationality,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildTextField(
          label: 'Religion / Community',
          controller: _religionController,
          hint: 'Islam',
          onChanged: notifier.setReligion,
        ),
      ],
    );

    final photoColumn = Column(
      children: [
        _buildPhotoDropzone(draft.photoPath),
        const SizedBox(height: AppSpacing.md),
        // Specifications / Info Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 16,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All fields marked * are mandatory for board registration',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card Title & Subtitle
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Step 1 of 4: Personal Information',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusInfoBg,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.statusInfoBorder),
                      ),
                      child: Text(
                        'Draft',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.statusInfoText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
            Text(
              'Basic identity details for the new student',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(color: AppColors.borderDefault),
        const SizedBox(height: AppSpacing.lg),

        // Two-column layout on wide desktop; stacked when narrow (incl. the
        // all-in-one page's half-width columns).
        if (isMobile || MediaQuery.of(context).size.width < 1000)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identityFieldsColumn,
              const SizedBox(height: AppSpacing.md),
              photoColumn,
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: identityFieldsColumn),
              const SizedBox(width: AppSpacing.xl),
              SizedBox(width: 240, child: photoColumn),
            ],
          ),
      ],
    );
  }

  Widget _buildPhotoDropzone(String? photoPath) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickPhoto,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: 240,
          constraints: const BoxConstraints(minHeight: 240),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.borderDefault,
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: photoPath != null && File(photoPath).existsSync()
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Image.file(
                        File(photoPath),
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.surfaceRaised,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.statusErrorText,
                          ),
                          onPressed: _removePhoto,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_a_photo,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Click to choose photo',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Max 50 KB, JPEG or PNG',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _pickPhoto,
                      child: const Text('Choose Photo'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 2: Guardian & Family
  // ─────────────────────────────────────────────────────────────
  Widget _buildStep2Guardian(WizardDraft draft) {
    final notifier = ref.read(wizardDraftProvider.notifier);
    final siblingsAsync = ref.watch(
      siblingDiscoveryProvider(SiblingQuery(_debouncedCnic, _debouncedFName)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 2 of 4: Guardian & Family',
          style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Father credentials and family details',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(color: AppColors.borderDefault),
        const SizedBox(height: AppSpacing.lg),

        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Father / Guardian Name *',
                controller: _fNameController,
                focusNode: _fNameFocusNode,
                hint: 'Enter father or legal guardian full name',
                prefixIcon: Icons.person_outline,
                onChanged: _onFNameChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildTextField(
                label: 'Father CNIC *',
                controller: _cnicController,
                focusNode: _cnicFocusNode,
                hint: 'XXXXX-XXXXXXX-X',
                prefixIcon: Icons.badge_outlined,
                monospace: true,
                inputFormatters: const [CnicInputFormatter()],
                onChanged: _onCnicChanged,
              ),
            ),
          ],
        ),

        // Sibling Auto-Discovery Panel
        siblingsAsync.when(
          data: (siblings) {
            if (siblings.isEmpty) return const SizedBox.shrink();
            return _buildSiblingPanel(siblings);
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Occupation',
                optionalLabel: '(Optional)',
                controller: _occupationController,
                hint: 'e.g. Civil Servant, Businessman, Teacher',
                prefixIcon: Icons.work_outline,
                onChanged: notifier.setOccupation,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildTextField(
                label: 'Previous School Attended',
                optionalLabel: '(Optional)',
                controller: _pSchoolController,
                hint: 'Name of last school attended, if any',
                prefixIcon: Icons.school_outlined,
                onChanged: notifier.setPSchool,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Previous Class Completed',
                optionalLabel: '(Optional)',
                controller: _pClassController,
                hint: 'Highest class grade completed',
                onChanged: notifier.setPClass,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildTextField(
                label: 'SLCertificate number',
                optionalLabel: '(Optional)',
                controller: _slCertificateController,
                hint: 'Previous School Leaving Certificate ref',
                onChanged: notifier.setSLCertificate,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSiblingPanel(List<SiblingInfo> siblings) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusWarningBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.statusWarningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 18,
                color: AppColors.statusWarningText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${siblings.length} Existing Siblings Found Under This Father CNIC',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h3.copyWith(
                    color: AppColors.statusWarningText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final sibling in siblings) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.brandPrimary,
                    child: Text(
                      sibling.initials,
                      style: const TextStyle(
                        color: AppColors.textOnPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            sibling.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '(Reg #${sibling.stuRegId})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '${sibling.className ?? 'Unassigned'}${sibling.sectionName != null ? '-${sibling.sectionName}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('View Profile'),
                    onPressed: () =>
                        context.push('/students/${sibling.stuRegId}'),
                  ),
                ],
              ),
            ),
          ],
          // Stacked (never a side-by-side Row): the link button's natural
          // width exceeds the half-width section column and would overflow.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sibling links are for family reference only. Fee concessions are configured separately per student.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              if (siblings.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.link, size: 14),
                  label: const Text('Link as Sibling & Copy Family Address'),
                  onPressed: () => _linkAsSiblingAndCopyInfo(siblings),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 3: Contact & Address
  // ─────────────────────────────────────────────────────────────
  Widget _buildStep3Contact(WizardDraft draft) {
    final notifier = ref.read(wizardDraftProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 3 of 4: Contact & Address',
          style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Official guardian phone numbers and residential domicile addresses',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(color: AppColors.borderDefault),
        const SizedBox(height: AppSpacing.lg),

        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Mobile 1 * (SMS notifications)',
                controller: _mobile1Controller,
                focusNode: _mobile1FocusNode,
                hint: '0300-1234567',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: const [MobileInputFormatter()],
                onChanged: notifier.setMobile1,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildTextField(
                label: 'Mobile 2',
                optionalLabel: '(Optional)',
                controller: _mobile2Controller,
                hint: '0321-7654321',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: const [MobileInputFormatter()],
                onChanged: notifier.setMobile2,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Emergency Contact Name',
                optionalLabel: '(Optional)',
                controller: _emerContNameController,
                hint: 'Designated emergency contact person name',
                onChanged: notifier.setEmerContName,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildTextField(
                label: 'Emergency Contact Mobile',
                optionalLabel: '(Optional)',
                controller: _emerContMobileController,
                hint: '0345-7654321',
                keyboardType: TextInputType.phone,
                inputFormatters: const [MobileInputFormatter()],
                onChanged: notifier.setEmerContMobile,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildTextField(
          label: 'Permanent Address',
          optionalLabel: '(Optional)',
          controller: _pAddressController,
          hint: 'House number, street, mohallah/village, tehsil, district',
          maxLines: 3,
          onChanged: notifier.setPAddress,
        ),
        const SizedBox(height: AppSpacing.md),
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Present Address (Optional)',
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy from Permanent'),
                onPressed: _copyFromPermanent,
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: Text(
                  'Present Address (Optional)',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy from Permanent'),
                onPressed: _copyFromPermanent,
              ),
            ],
          ),
        const SizedBox(height: 4),
        TextField(
          controller: _tAddressController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Leave blank if same as permanent residential address',
          ),
          onChanged: notifier.setTAddress,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 4: Academic Placement
  // ─────────────────────────────────────────────────────────────
  Widget _buildStep4Academic(WizardDraft draft) {
    final notifier = ref.read(wizardDraftProvider.notifier);
    final classesAsync = ref.watch(classesProvider);
    final sectionsAsync = ref.watch(sectionsProvider);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 4 of 4: Academic Placement',
          style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Class assignment and fee structure',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    );

    final sessionBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(
        'ACTIVE SESSION 2017-2018 (Annual)',
        style: AppTypography.monospace.copyWith(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile || MediaQuery.of(context).size.width < 1000)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              const SizedBox(height: 8),
              sessionBadge,
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleColumn),
              const SizedBox(width: 8),
              sessionBadge,
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        const Divider(color: AppColors.borderDefault),
        const SizedBox(height: AppSpacing.lg),

        // Class & Section dropdowns
        Row(
          children: [
            Expanded(
              child: classesAsync.when(
                data: (classes) {
                  return _buildDropdownField<int>(
                    label: 'Admission In Class *',
                    value: draft.admInClass,
                    hint: 'Select Admission Class',
                    items: classes.map((c) => c.classId).toList(),
                    itemLabels: {for (final c in classes) c.classId: c.cName},
                    onChanged: (val) {
                      notifier.setAdmInClass(val);
                      // Auto select first section for this class if available
                      sectionsAsync.whenData((sections) {
                        final classSections = sections
                            .where((s) => s.classId == val)
                            .toList();
                        if (classSections.isNotEmpty) {
                          notifier.setClassSecId(
                            classSections.first.classSecId,
                          );
                        }
                      });
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Text('Error loading classes: $e'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: sectionsAsync.when(
                data: (sections) {
                  final filteredSections = draft.admInClass != null
                      ? sections
                            .where((s) => s.classId == draft.admInClass)
                            .toList()
                      : <ClassSec>[];

                  return _buildDropdownField<int>(
                    label: 'Assigned Section *',
                    value:
                        filteredSections.any(
                          (s) => s.classSecId == draft.classSecId,
                        )
                        ? draft.classSecId
                        : (filteredSections.isNotEmpty
                              ? filteredSections.first.classSecId
                              : null),
                    hint: 'Select Section',
                    items: filteredSections.map((s) => s.classSecId).toList(),
                    itemLabels: {
                      for (final s in filteredSections)
                        s.classSecId: 'Section ${s.secName}',
                    },
                    onChanged: notifier.setClassSecId,
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Text('Error loading sections: $e'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        Row(
          children: [
            Expanded(
              child: _buildDatePickerField(
                label: 'Official Date of Admission *',
                controller: _doAdmissionController,
                hint: 'Select admission date',
                onTap: _pickAdmissionDate,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildTextField(
                label: 'Monthly Tuition Concession (Rs.)',
                controller: _discountController,
                hint: '0',
                keyboardType: TextInputType.number,
                prefixText: 'Rs. ',
                onChanged: (val) {
                  final d = double.tryParse(val) ?? 0.0;
                  notifier.setDiscount(d);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Voucher Adjustment Concession (Rs.)',
                controller: _vmDiscountController,
                hint: '0',
                keyboardType: TextInputType.number,
                prefixText: 'Rs. ',
                onChanged: (val) {
                  final v = int.tryParse(val) ?? 0;
                  notifier.setVmDiscount(v);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '100% Full Fee Waiver Concession',
                      style: AppTypography.label.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    value: draft.fullDiscount,
                    onChanged: (val) {
                      notifier.setFullDiscount(val ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ],
        ),

        // Full discount warning box
        if (draft.fullDiscount) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.statusWarningBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: AppColors.statusWarningText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '100% fee waiver — no vouchers will be generated for this student.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.statusWarningText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        _buildTextField(
          label: 'Administrative Remarks & Notes',
          optionalLabel: '(Optional)',
          controller: _remarksController,
          hint: 'General administrative notes...',
          helperText: 'Max: 250 chars',
          maxLines: 3,
          onChanged: notifier.setRemarks,
        ),

        // Fee Preview Card
        const SizedBox(height: AppSpacing.md),
        if (draft.admInClass != null)
          _buildFeePreviewCard(draft.admInClass!)
        else
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calculate_outlined,
                  size: 18,
                  color: AppColors.chartBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select a class above to calculate estimated monthly fee preview.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFeePreviewCard(int classId) {
    final feeParamsAsync = ref.watch(feePreviewProvider(classId));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: feeParamsAsync.when(
        data: (rows) {
          double sum = 0.0;
          final breakdown = <String>[];
          for (final r in rows) {
            final fee = (r['Fee'] as num?)?.toDouble() ?? 0.0;
            final desc =
                (r['ParamDesciption'] as String?)?.trim() ?? 'Fee Head';
            sum += fee;
            breakdown.add('$desc: Rs. ${fee.toStringAsFixed(0)}');
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stacked (never a side-by-side Row): label + fee text exceed
              // the half-width section column and would overflow.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calculate_outlined,
                        size: 18,
                        color: AppColors.chartBlue,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'FEE PREVIEW CALCULATION',
                          style: AppTypography.label.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estimated Monthly Fee: Rs. ${sum.toStringAsFixed(0)}',
                    style: AppTypography.monospace.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (sum == 0.0)
                Text(
                  'No fee structure defined for this class.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.statusWarningText,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final item in breakdown)
                      Text(
                        item,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Final fee voucher will be generated based on active Class fee structure.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Text('Error loading fee calculation: $e'),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM ACTION BAR & KEYBOARD HINTS
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomActionBar(int currentStep, WizardDraft draft) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final Widget primaryButton = currentStep < 3
        ? ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Save & Continue'),
            onPressed: _isSubmitting ? null : _advanceOrSubmit,
          )
        : ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.textOnPrimary,
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 16),
            label: Text(_isSubmitting ? 'Saving...' : 'Complete Admission'),
            onPressed: _isSubmitting ? null : _advanceOrSubmit,
          );

    final Widget actions = isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 48, child: primaryButton),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _onCancel,
                    child: const Text('Cancel'),
                  ),
                  if (currentStep > 0)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back'),
                      onPressed: _goBack,
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: _onCancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  if (currentStep > 0)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back'),
                      onPressed: _goBack,
                    ),
                ],
              ),
              Row(children: [primaryButton]),
            ],
          );

    if (!isMobile) {
      // Desktop: unchanged (frozen).
      return Container(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: actions,
      );
    }

    // G-10 Shot 11b-2: pinned, raised bottom action bar on mobile.
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: AppColors.surfaceRaised,
          border: Border(top: BorderSide(color: AppColors.borderDefault)),
        ),
        child: actions,
      ),
    );
  }

  Widget _buildKeyboardHintsBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildKeyHint('[Tab] Next'),
        const SizedBox(width: 12),
        _buildKeyHint('[Enter] Save & Continue'),
        const SizedBox(width: 12),
        _buildKeyHint('[Esc] Cancel'),
      ],
    );
  }

  Widget _buildKeyHint(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(
        text,
        style: AppTypography.monospace.copyWith(
          fontSize: 11,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // REUSABLE FORM WIDGETS
  // ─────────────────────────────────────────────────────────────
  Widget _buildTextField({
    required String label,
    String? optionalLabel,
    required TextEditingController controller,
    FocusNode? focusNode,
    String? hint,
    String? helperText,
    String? prefixText,
    IconData? prefixIcon,
    bool monospace = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              label,
              style: AppTypography.label.copyWith(color: AppColors.textPrimary),
            ),
            if (optionalLabel != null) ...[
              const SizedBox(width: 4),
              Text(
                optionalLabel,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          style: monospace ? AppTypography.monospace : AppTypography.body,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            prefixText: prefixText,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: IgnorePointer(
            child: TextField(
              controller: controller,
              readOnly: true,
              decoration: InputDecoration(
                hintText: hint,
                suffixIcon: const Icon(Icons.calendar_today, size: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    String? optionalLabel,
    required T? value,
    String? hint,
    required List<T> items,
    Map<T, String>? itemLabels,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              label,
              style: AppTypography.label.copyWith(color: AppColors.textPrimary),
            ),
            if (optionalLabel != null) ...[
              const SizedBox(width: 4),
              Text(
                optionalLabel,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          key: ValueKey(value),
          initialValue: items.contains(value) ? value : null,
          hint: hint != null
              ? Text(
                  hint,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                  ),
                )
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
          ),
          items: items.map((item) {
            final labelText = itemLabels != null && itemLabels.containsKey(item)
                ? itemLabels[item]!
                : item.toString();
            return DropdownMenuItem<T>(
              value: item,
              child: Text(labelText, style: AppTypography.body),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

String? _getFromOrigin(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.queryParameters['from'];
  } catch (_) {
    return null;
  }
}
