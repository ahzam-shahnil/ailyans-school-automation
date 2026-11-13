import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/available_sessions_provider.dart';
import '../../core/providers/bulk_enrollment_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/providers/student_list_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../models/enrollment_row.dart';
import '../../models/school_class.dart';
import '../../models/student.dart';
import '../../widgets/mobile/mobile_dropdown_field.dart';
import '../../widgets/mobile/mobile_kpi_card.dart';
import '../../widgets/mobile/mobile_status_pill.dart';

/// Screen 9: BulkEnrollmentScreen at `/students/enrollment/bulk`.
///
/// Implements §S7 (`SCHfrmStu_Class` at `0x00426bf8`, `ObjID: 20`) per
/// `docs/03-behavior-specs.md` §S7 and `docs/05-ui-ux-spec.md` Screen 9.
class BulkEnrollmentScreen extends ConsumerStatefulWidget {
  const BulkEnrollmentScreen({super.key});

  @override
  ConsumerState<BulkEnrollmentScreen> createState() =>
      _BulkEnrollmentScreenState();
}

class _BulkEnrollmentScreenState extends ConsumerState<BulkEnrollmentScreen> {
  final TextEditingController _regIdController = TextEditingController();
  final TextEditingController _rollNoController = TextEditingController();
  final FocusNode _regIdFocusNode = FocusNode();
  final FocusNode _rollNoFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final metaAsync = ref.read(shellMetadataProvider);
      if (!metaAsync.hasValue) return;
      final meta = metaAsync.valueOrNull;
      if (meta == null) return;
      final current = ref.read(bulkEnrollmentProvider).selectedSessionYr;
      if (current != meta.sessionYear) {
        ref
            .read(bulkEnrollmentProvider.notifier)
            .setSessionYr(meta.sessionYear);
      }
    });
  }

  @override
  void dispose() {
    _regIdController.dispose();
    _rollNoController.dispose();
    _regIdFocusNode.dispose();
    _rollNoFocusNode.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError
                ? AppColors.statusErrorText
                : AppColors.statusSuccessText,
          ),
        ),
        backgroundColor: isError
            ? AppColors.statusErrorBg
            : AppColors.statusSuccessBg,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleLoadRoster() async {
    final (ok, msg) = await ref
        .read(bulkEnrollmentProvider.notifier)
        .loadRoster();
    if (!mounted) return;
    if (!ok) {
      _showSnackBar(msg, isError: true);
    } else {
      final state = ref.read(bulkEnrollmentProvider);
      final nextRoll = state.roster.isEmpty
          ? 1
          : state.roster
                    .map((r) => r.classRollNo)
                    .reduce((a, b) => a > b ? a : b) +
                1;
      _rollNoController.text = nextRoll.toString();
    }
  }

  Future<void> _handleEnroll() async {
    final regIdText = _regIdController.text;
    final rollNoText = _rollNoController.text;

    final (ok, msg) = await ref
        .read(bulkEnrollmentProvider.notifier)
        .enrollStudent(regIdText: regIdText, rollNoText: rollNoText);

    if (!mounted) return;

    if (!ok) {
      _showSnackBar(msg, isError: true);
    } else {
      _showSnackBar(msg, isError: false);
      _regIdController.clear();
      final state = ref.read(bulkEnrollmentProvider);
      final nextRoll = state.roster.isEmpty
          ? 1
          : state.roster
                    .map((r) => r.classRollNo)
                    .reduce((a, b) => a > b ? a : b) +
                1;
      _rollNoController.text = nextRoll.toString();
      _regIdFocusNode.requestFocus();
    }
  }

  Future<void> _handleAutoReRoll() async {
    final (ok, msg) = await ref
        .read(bulkEnrollmentProvider.notifier)
        .autoReRollNumbers();
    if (!mounted) return;
    _showSnackBar(msg, isError: !ok);
    if (ok) {
      final state = ref.read(bulkEnrollmentProvider);
      final nextRoll = state.roster.isEmpty
          ? 1
          : state.roster
                    .map((r) => r.classRollNo)
                    .reduce((a, b) => a > b ? a : b) +
                1;
      _rollNoController.text = nextRoll.toString();
    }
  }

  Future<void> _handleShowMissing() async {
    final (missing, errorMsg) = await ref
        .read(bulkEnrollmentProvider.notifier)
        .fetchMissingStudents();
    if (!mounted) return;

    if (errorMsg != null) {
      _showSnackBar(errorMsg, isError: errorMsg != 'No Missing Students');
      return;
    }

    if (missing.isEmpty) {
      _showSnackBar('No Missing Students', isError: false);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Missing Students'),
          content: SizedBox(
            width: 500,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: missing.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = missing[index];
                final name = formatStudentFullName(
                  row['NameFirst'] as String?,
                  row['NameMiddle'] as String?,
                  row['NameLast'] as String?,
                );
                return ListTile(
                  dense: true,
                  leading: Text(
                    '#${row['Stu_RegID']}',
                    style: AppTypography.monospace,
                  ),
                  title: Text(name, style: AppTypography.label),
                  subtitle: Text(
                    'Class: ${row['CName'] ?? ''}',
                    style: AppTypography.bodySmall,
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRemoveStudent(EnrollmentRow row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          // Verbatim legacy copy-paste bug from FeeParameter: S7 line 562
          title: const Text('Removing a Parameter from Class'),
          content: Text(
            'Are you sure want to Remove student ${row.fullName} from Class ${row.className ?? ''} and Section ${row.sectionName ?? ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorBg,
                foregroundColor: AppColors.statusErrorText,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final (ok, msg) = await ref
          .read(bulkEnrollmentProvider.notifier)
          .removeStudent(row);
      if (mounted) {
        _showSnackBar(msg, isError: !ok);
        if (ok) {
          final state = ref.read(bulkEnrollmentProvider);
          final nextRoll = state.roster.isEmpty
              ? 1
              : state.roster
                        .map((r) => r.classRollNo)
                        .reduce((a, b) => a > b ? a : b) +
                    1;
          _rollNoController.text = nextRoll.toString();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bulkEnrollmentProvider);
    final classesAsync = ref.watch(classesProvider);
    final sectionsAsync = ref.watch(sectionsProvider);
    final dynamicSessions = ref.watch(availableSessionsProvider).valueOrNull;
    final effectiveSessions = <String>{
      if (state.selectedSessionYr.isNotEmpty) state.selectedSessionYr,
      ...?dynamicSessions,
      ...state.availableSessions,
      '2017-2018',
    }.toList()..sort((a, b) => b.compareTo(a));

    final classes = classesAsync.value ?? <SchoolClass>[];
    final allSections = sectionsAsync.value ?? <ClassSec>[];
    final sections = state.selectedClassId == null
        ? allSections
        : allSections.where((s) => s.classId == state.selectedClassId).toList();

    if (ResponsiveBreakpoints.isMobile(context)) {
      return _buildMobileScaffold(
        state,
        classes,
        sections,
        effectiveSessions,
      );
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _handleLoadRoster,
        const SingleActivator(
          LogicalKeyboardKey.keyR,
          control: true,
          shift: true,
        ): _handleAutoReRoll,
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Title, Subtitle, Count & Help ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Bulk Class Enrollment',
                              style: AppTypography.h2.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 3.0,
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
                                state.isRosterLoaded
                                    ? '${state.roster.length} Enrolled'
                                    : 'Ready',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage the student roster for a class. Load to see enrolled students, add new ones, fix roll numbers, or remove students.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: const Icon(
                      Icons.help_outline,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('How to use Bulk Enrollment'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'This screen lets you manage the student roster for any class.',
                                style: AppTypography.body,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Workflow:',
                                style: AppTypography.label.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '1. Choose a Class, Section, and Session',
                                style: AppTypography.bodySmall,
                              ),
                              const Text(
                                '2. Click Load Roster to see currently enrolled students',
                                style: AppTypography.bodySmall,
                              ),
                              const Text(
                                '3. Use Quick Enroll to add a student by their Reg ID',
                                style: AppTypography.bodySmall,
                              ),
                              const Text(
                                '4. Auto Re-Roll No renumbers all students 1 to N',
                                style: AppTypography.bodySmall,
                              ),
                              const Text(
                                '5. Show Missing Students finds dropped students without an SLC',
                                style: AppTypography.bodySmall,
                              ),
                              const Text(
                                '6. Trash icon removes a student from this section',
                                style: AppTypography.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Note: Enrolling a student here does NOT create them in Stu_Reg - they must already be registered.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    ),
                    tooltip: 'How to use this screen',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── 1. CONTROL STRIP (~56px) ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Row(
                  children: [
                    // Class Selector
                    Expanded(
                      flex: 2,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Class',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: state.selectedClassId,
                            isDense: true,
                            isExpanded: true,
                            hint: const Text('Select Class'),
                            items: classes.map((c) {
                              return DropdownMenuItem<int>(
                                value: c.classId,
                                child: Text(c.cName),
                              );
                            }).toList(),
                            onChanged: (val) {
                              ref
                                  .read(bulkEnrollmentProvider.notifier)
                                  .setClassId(val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Section Selector
                    Expanded(
                      flex: 2,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Section',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: state.selectedSecId,
                            isDense: true,
                            isExpanded: true,
                            hint: const Text('Select Sec'),
                            items: sections.map((s) {
                              return DropdownMenuItem<int>(
                                value: s.classSecId,
                                child: Text(s.secName),
                              );
                            }).toList(),
                            onChanged: (val) {
                              ref
                                  .read(bulkEnrollmentProvider.notifier)
                                  .setSecId(val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Session Selector
                    Expanded(
                      flex: 2,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Session',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value:
                                effectiveSessions.contains(
                                  state.selectedSessionYr,
                                )
                                ? state.selectedSessionYr
                                : (effectiveSessions.isNotEmpty
                                      ? effectiveSessions.first
                                      : '2017-2018'),
                            isDense: true,
                            isExpanded: true,
                            items: effectiveSessions.map((yr) {
                              return DropdownMenuItem<String>(
                                value: yr,
                                child: Text(yr),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref
                                    .read(bulkEnrollmentProvider.notifier)
                                    .setSessionYr(val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Load Roster Button
                    ElevatedButton.icon(
                      onPressed: _handleLoadRoster,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Load Roster (Ctrl+L)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.textOnPrimary,
                        minimumSize: const Size(140, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // ── 2. ACTION TOOLBAR (~48px) ──
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Tooltip(
                    message: 'Renumber all students in this section as 1, 2, 3, ... (in Reg ID order)',
                    child: OutlinedButton.icon(
                      onPressed: state.selectedSecId != null
                          ? _handleAutoReRoll
                          : null,
                      icon: const Icon(Icons.format_list_numbered, size: 16),
                      label: const Text('Auto Re-Roll No'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Tooltip(
                    message: 'Find students who dropped out without a School Leaving Certificate',
                    child: OutlinedButton.icon(
                      onPressed: state.selectedClassId != null
                          ? _handleShowMissing
                          : null,
                      icon: const Icon(Icons.warning_amber_rounded, size: 16),
                      label: const Text('Show Missing Students'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Tooltip(
                    message: 'Print the class roster as a PDF report',
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showSnackBar('Coming in Phase E');
                      },
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Print Class Biodata'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Tooltip(
                    message: 'Toggle monthly fee voucher generation for all students in this section',
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showSnackBar('Toggle functionality coming in Phase E');
                      },
                      icon: const Icon(Icons.receipt_long_outlined, size: 16),
                      label: const Text('Batch Voucher Toggle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // ── 3. QUICK ENROLL STRIP (~64px) ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUICK ENROLL',
                      style: AppTypography.label.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Student Reg ID input
                        Expanded(
                          flex: 3,
                          child: TextField(
                            key: const ValueKey('regIdField'),
                            controller: _regIdController,
                            focusNode: _regIdFocusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Student Reg ID',
                              hintText:
                                  'Enter registered student ID (e.g. 4411)',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) {
                              _rollNoFocusNode.requestFocus();
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),

                        // Roll No input
                        Expanded(
                          flex: 2,
                          child: TextField(
                            key: const ValueKey('rollNoField'),
                            controller: _rollNoController,
                            focusNode: _rollNoFocusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Roll No',
                              hintText: 'Auto-assigned next number',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _handleEnroll(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),

                        // Enroll Button: ALWAYS ENABLED (per S7 specs)
                        ElevatedButton.icon(
                          onPressed: _handleEnroll,
                          icon: const Icon(Icons.person_add_alt_1, size: 16),
                          label: const Text('+ Enroll Student'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                            foregroundColor: AppColors.textOnPrimary,
                            minimumSize: const Size(160, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // ── 4. ROSTER DATA TABLE ──
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Builder(
                      builder: (context) {
                        if (!state.isRosterLoaded) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.group_add_outlined,
                                  size: 48,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No roster loaded',
                                  style: AppTypography.h3.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Choose a Class, Section, and Session above, then click Load Roster to view the enrolled students.',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(
                                  height: 0,
                                  width: 0,
                                  child: OverflowBox(
                                    minWidth: 0,
                                    maxWidth: 0,
                                    minHeight: 0,
                                    maxHeight: 0,
                                    child: Text(
                                      'Select Class, Section, and Session, then click Load Roster',
                                      style: TextStyle(
                                        fontSize: 0,
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (state.roster.isEmpty) {
                          return Center(
                            child: Text(
                              'No students enrolled in this section yet',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: DataTable(
                                    headingRowHeight: 40,
                                    dataRowMinHeight: 40,
                                    dataRowMaxHeight: 44,
                                    columns: const [
                                      DataColumn(label: Text('Reg ID')),
                                      DataColumn(label: Text('Roll No')),
                                      DataColumn(label: Text('Student Name')),
                                      DataColumn(label: Text('Father Name')),
                                      DataColumn(label: Text('Present')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: state.roster.map((row) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              '#${row.stuRegId}',
                                              style: AppTypography.monospace,
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              row.classRollNo
                                                  .toString()
                                                  .padLeft(2, '0'),
                                              style: AppTypography.monospace,
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              row.fullName,
                                              style: AppTypography.label,
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              row.fatherName ?? '-',
                                              style: AppTypography.bodySmall,
                                            ),
                                          ),
                                          DataCell(
                                            Checkbox(
                                              value: row.present,
                                              onChanged: (val) {
                                                if (val != null) {
                                                  ref
                                                      .read(
                                                        bulkEnrollmentProvider
                                                            .notifier,
                                                      )
                                                      .togglePresent(
                                                        row.stuRegId,
                                                        val,
                                                      );
                                                }
                                              },
                                            ),
                                          ),
                                          DataCell(
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color:
                                                    AppColors.statusErrorText,
                                              ),
                                              tooltip: 'Remove Student',
                                              onPressed: () =>
                                                  _confirmRemoveStudent(row),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How to use Bulk Enrollment'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This screen lets you manage the student roster for any class.',
                style: AppTypography.body,
              ),
              SizedBox(height: 12),
              Text(
                'Workflow:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                '1. Select Session Year, Class, and Section\n'
                '2. Click Load Roster to see currently enrolled students\n'
                '3. Type Reg ID and Roll No to enroll a student\n'
                '4. Click Re-roll to reassign sequential roll numbers\n'
                '5. Click Missing to find unassigned students',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileScaffold(
    BulkEnrollmentState state,
    List<SchoolClass> classes,
    List<ClassSec> sections,
    List<String> effectiveSessions,
  ) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMobileHeader(state),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMobileKpiRow(state),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMobileFilterCard(
                      state,
                      classes,
                      sections,
                      effectiveSessions,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (state.isRosterLoaded) ...[
                      _buildMobileEnrollCard(state),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    _buildMobileRosterSection(state),
                  ],
                ),
              ),
            ),
            if (state.isRosterLoaded) _buildMobileStickyFooter(state),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader(BulkEnrollmentState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Bulk Class Enrollment',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 3.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Text(
                      state.isRosterLoaded
                          ? '${state.roster.length} Enrolled'
                          : 'Ready',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Manage student roster and class roll assignments.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.help_outline, size: 20),
          tooltip: 'Keyboard Shortcuts & Help',
          onPressed: _showHelpDialog,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildMobileKpiRow(BulkEnrollmentState state) {
    final activeCount = state.roster.where((r) => r.present).length;
    return Row(
      children: [
        Expanded(
          child: MobileKpiCard(
            label: 'ENROLLED STUDENTS',
            value: '${state.roster.length}',
            icon: Icons.people_outline,
            accentColor: AppColors.accentStudents,
            accentSoftBg: AppColors.accentStudentsSoftBg,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MobileKpiCard(
            label: 'ACTIVE STATUS',
            value: '$activeCount Active',
            icon: Icons.check_circle_outline,
            accentColor: AppColors.chartTeal,
            accentSoftBg: AppColors.chartTeal.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFilterCard(
    BulkEnrollmentState state,
    List<SchoolClass> classes,
    List<ClassSec> sections,
    List<String> effectiveSessions,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'COHORT SELECTION',
            style: AppTypography.label.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          MobileDropdownField<String>(
            label: 'Session Year',
            value: state.selectedSessionYr.isNotEmpty
                ? state.selectedSessionYr
                : null,
            hintText: 'Select Session',
            items: effectiveSessions.map((s) {
              return DropdownMenuItem<String>(
                value: s,
                child: Text(s),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                ref.read(bulkEnrollmentProvider.notifier).setSessionYr(val);
              }
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: MobileDropdownField<int>(
                  label: 'Class',
                  value: state.selectedClassId,
                  hintText: 'Select Class',
                  items: classes.map((c) {
                    return DropdownMenuItem<int>(
                      value: c.classId,
                      child: Text(c.cName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    ref.read(bulkEnrollmentProvider.notifier).setClassId(val);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MobileDropdownField<int>(
                  label: 'Section',
                  value: state.selectedSecId,
                  hintText: 'Select Section',
                  items: sections.map((s) {
                    return DropdownMenuItem<int>(
                      value: s.classSecId,
                      child: Text(s.secName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    ref.read(bulkEnrollmentProvider.notifier).setSecId(val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: state.isLoading ? null : _handleLoadRoster,
              icon: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: const Text('Load Roster'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentStudents,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileEnrollCard(BulkEnrollmentState state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.accentStudents,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'QUICK ENROLL STUDENT',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _regIdController,
                    focusNode: _regIdFocusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Reg ID',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    style: AppTypography.bodySmall,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _rollNoController,
                    focusNode: _rollNoFocusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Roll No',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    style: AppTypography.bodySmall,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: state.isLoading ? null : _handleEnroll,
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('+ Enroll Student'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRosterSection(BulkEnrollmentState state) {
    if (!state.isRosterLoaded) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.format_list_bulleted,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Select Class, Section, and Session, then click Load Roster',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (state.roster.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.people_outline,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No students enrolled in this cohort.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.roster.length,
      itemBuilder: (context, index) {
        final row = state.roster[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3.5, color: AppColors.accentStudents),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '#${row.stuRegId}',
                              style: AppTypography.monospace.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.accentStudents,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                row.fullName,
                                style: AppTypography.label.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            MobileStatusPill(
                              label: 'Roll #${row.classRollNo}',
                              variant: MobileStatusVariant.neutral,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Father: ${row.fatherName ?? '-'}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.statusErrorText,
                              ),
                              onPressed: () => _confirmRemoveStudent(row),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
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
      },
    );
  }

  Widget _buildMobileStickyFooter(BulkEnrollmentState state) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _handleShowMissing,
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Missing'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.borderDefault),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _handleAutoReRoll,
              icon: const Icon(Icons.format_list_numbered, size: 16),
              label: const Text('Re-roll'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
