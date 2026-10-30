import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/attendance_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/attendance_pdf_generator.dart';
import '../../models/attendance_roster_row.dart';
import '../../widgets/reports/report_definition.dart';
import '../../widgets/reports/report_preview_modal.dart';

/// Screen 19 — AttendanceScreen at /attendance.
/// Consolidates legacy frmAttandance (§S23) and frmAttPrint (§S26).
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(attendanceProvider.notifier).loadInitialData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);

    // Listen to toasts from provider
    ref.listen<AttendanceState>(attendanceProvider, (prev, next) {
      if (next.toast != null && next.toast != prev?.toast) {
        final isSuccess =
            next.toast == 'Class Attandance Done' ||
            next.toast == 'Attandance Record Updated';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.toast!),
            backgroundColor: isSuccess
                ? AppColors.statusSuccessText
                : AppColors.statusErrorText,
            duration: const Duration(seconds: 3),
          ),
        );
        notifier.clearToast();
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surface,
      endDrawer: _buildLeaveDrawer(context, state, notifier),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Control Bar (fixed height ~72px)
            _buildControlBar(context, state, notifier),

            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderSubtle,
            ),

            // 2. Summary KPI Strip (fixed height ~56px)
            _buildSummaryStrip(context, state),

            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderSubtle,
            ),

            // 3. Roll-Call Roster Grid (Expanded, internal scroll only)
            Expanded(child: _buildRosterGrid(context, state, notifier)),

            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderSubtle,
            ),

            // 4. Pinned Bottom Action Bar (fixed height ~72px)
            _buildBottomActionBar(context, state, notifier),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 1. CONTROL BAR
  // ==========================================================================
  Widget _buildControlBar(
    BuildContext context,
    AttendanceState state,
    AttendanceNotifier notifier,
  ) {
    final dateDisplay = DateFormat('dd-MMM-yyyy').format(state.selectedDate);
    final leaveCount = state.summaryCounts['Leave'] ?? 0;

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.surface,
      child: Row(
        children: [
          // Class Dropdown
          SizedBox(
            width: 155,
            height: 48,
            child: DropdownButtonFormField<int>(
              key: ValueKey(state.selectedClassId),
              initialValue: state.selectedClassId,
              isExpanded: true,
              menuMaxHeight: 400,
              decoration: const InputDecoration(
                labelText: 'Class',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(),
              ),
              items: state.classes.map((cls) {
                return DropdownMenuItem<int>(
                  value: cls['ClassID'] as int,
                  child: Text(
                    cls['CName'] as String? ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  notifier.loadSectionsForClass(val);
                }
              },
            ),
          ),
          const SizedBox(width: AppSpacing.xs),

          // Section Dropdown
          SizedBox(
            width: 130,
            height: 48,
            child: DropdownButtonFormField<int>(
              key: ValueKey(state.selectedClassSecId),
              initialValue: state.selectedClassSecId,
              isExpanded: true,
              menuMaxHeight: 400,
              decoration: const InputDecoration(
                labelText: 'Section',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(),
              ),
              items: state.sections.map((sec) {
                return DropdownMenuItem<int>(
                  value: sec['ClassSecID'] as int,
                  child: Text(
                    sec['SecName'] as String? ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  notifier.selectSection(val);
                }
              },
            ),
          ),
          const SizedBox(width: AppSpacing.xs),

          // Date Picker Field
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: state.selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  notifier.setDate(picked);
                }
              },
              borderRadius: BorderRadius.circular(AppRadius.md),
              hoverColor: AppColors.brandPrimary.withValues(alpha: 0.04),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  border: Border.all(color: AppColors.borderDefault),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateDisplay,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),

          // Teacher Dropdown
          SizedBox(
            width: 200,
            height: 48,
            child: DropdownButtonFormField<int>(
              key: ValueKey('teacher_${state.selectedTeacherId}'),
              initialValue: state.selectedTeacherId,
              hint: const Text('Select Teacher'),
              isExpanded: true,
              menuMaxHeight: 400,
              decoration: const InputDecoration(
                labelText: 'Teacher',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(),
              ),
              items: state.teachers.map((t) {
                return DropdownMenuItem<int>(
                  value: t['TeacherID'] as int,
                  child: Text(
                    t['TName'] as String? ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) => notifier.setTeacher(val),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),

          // Read-only Session Year
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              state.sessionYear,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.brandPrimary,
              ),
            ),
          ),

          const Spacer(),

          // Leave Requests Drawer Button
          OutlinedButton.icon(
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
            icon: Badge(
              isLabelVisible: leaveCount > 0,
              label: Text('$leaveCount'),
              backgroundColor: AppColors.statusWarningText,
              child: const Icon(Icons.description_outlined, size: 15),
            ),
            label: Text('Leave ($leaveCount)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: leaveCount > 0
                  ? AppColors.statusWarningText
                  : AppColors.textPrimary,
              side: BorderSide(
                color: leaveCount > 0
                    ? AppColors.statusWarningText
                    : AppColors.borderDefault,
              ),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),

          // Reload Roster Button
          IconButton(
            tooltip: 'Reload Roster',
            onPressed: () => notifier.loadRoster(),
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2. SUMMARY STRIP
  // ==========================================================================
  Widget _buildSummaryStrip(BuildContext context, AttendanceState state) {
    final present = state.summaryCounts['Present'] ?? 0;
    final absent = state.summaryCounts['Absent'] ?? 0;
    final leave = state.summaryCounts['Leave'] ?? 0;
    final late = state.summaryCounts['Late'] ?? 0;
    final total = state.roster.length;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.surfaceRaised,
      child: Row(
        children: [
          // Edit mode badge if attendance already entered
          if (state.isEditMode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.statusWarningBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.statusWarningText.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_note,
                    size: 16,
                    color: AppColors.statusWarningText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'EDIT MODE',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.statusWarningText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],

          Text(
            'Enrolled: $total',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          _buildMetricChip(
            label: 'Present',
            count: present,
            bgColor: AppColors.statusSuccessBg,
            textColor: AppColors.statusSuccessText,
          ),
          const SizedBox(width: AppSpacing.xs),

          _buildMetricChip(
            label: 'Absent',
            count: absent,
            bgColor: AppColors.statusErrorBg,
            textColor: AppColors.statusErrorText,
          ),
          const SizedBox(width: AppSpacing.xs),

          _buildMetricChip(
            label: 'Leave',
            count: leave,
            bgColor: AppColors.statusWarningBg,
            textColor: AppColors.statusWarningText,
          ),
          const SizedBox(width: AppSpacing.xs),

          _buildMetricChip(
            label: 'Late',
            count: late,
            bgColor: const Color(0xFFEFF6FF),
            textColor: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required int count,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          Text(
            '$count',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 3. ROLL-CALL ROSTER GRID
  // ==========================================================================
  Widget _buildRosterGrid(
    BuildContext context,
    AttendanceState state,
    AttendanceNotifier notifier,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.selectedClassId == null || state.selectedClassSecId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.groups_outlined,
              size: 54,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Select Class and Section to load attendance roll call',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (state.roster.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_off_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No active students enrolled in this section',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Grid Table Header
        Container(
          height: 40,
          color: AppColors.surfaceRaised,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: const Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  'Roll',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  'Reg ID',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Student Name / Father Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 310,
                child: Text(
                  'Status (AttStatus)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 170,
                child: Text(
                  'In / Out Time',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Remarks',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),

        // Scrollable Table Body
        Expanded(
          child: ListView.separated(
            itemCount: state.roster.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderSubtle,
            ),
            itemBuilder: (context, index) {
              final row = state.roster[index];
              final isAlternate = index.isOdd;
              return _AttendanceRowItem(
                key: ValueKey(row.stuRegId),
                row: row,
                isAlternate: isAlternate,
                onStatusChanged: (status) =>
                    notifier.updateStudentStatus(row.stuRegId, status),
                onTimesChanged: (inTime, outTime) =>
                    notifier.updateStudentTimes(
                      row.stuRegId,
                      inTime: inTime,
                      outTime: outTime,
                    ),
                onRemarksChanged: (remarks) =>
                    notifier.updateStudentRemarks(row.stuRegId, remarks),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // 4. PINNED BOTTOM ACTION BAR
  // ==========================================================================
  Widget _buildBottomActionBar(
    BuildContext context,
    AttendanceState state,
    AttendanceNotifier notifier,
  ) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.surface,
      child: Row(
        children: [
          // Cancel / Reset
          OutlinedButton(
            onPressed:
                (state.selectedClassId != null || state.roster.isNotEmpty)
                ? () {
                    final hasRoster = ref
                        .read(attendanceProvider)
                        .roster
                        .isNotEmpty;
                    if (hasRoster) {
                      ref.read(attendanceProvider.notifier).discardEdits();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Edits discarded')),
                      );
                    } else {
                      ref.read(attendanceProvider.notifier).clearSelection();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Selection cleared')),
                      );
                    }
                  }
                : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.borderDefault),
              minimumSize: const Size(90, 42),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Print Roll Call (S26)
          OutlinedButton.icon(
            onPressed: () async {
              final className =
                  state.classes.firstWhere(
                        (c) => c['ClassID'] == state.selectedClassId,
                        orElse: () => {'CName': ''},
                      )['CName']
                      as String? ??
                  '';

              // If no attendance held for class or roster empty
              if (state.roster.isEmpty ||
                  (!state.isEditMode && state.existingAttMasId == null)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No Attandace held for Class $className'),
                    backgroundColor: AppColors.statusErrorText,
                    duration: const Duration(seconds: 3),
                  ),
                );
                return;
              }

              final meta = ref.read(shellMetadataProvider).value;
              final safeBranchName = (meta?.branchName != null &&
                      meta!.branchName.trim().isNotEmpty)
                  ? meta.branchName.trim()
                  : "Ailyans's Higher Secondary School Mianwali";
              final safeBranchAddress = (meta?.branchAddress != null &&
                      meta!.branchAddress.trim().isNotEmpty)
                  ? meta.branchAddress.trim()
                  : 'Muslim Bazar Mianwali';
              final sectionName =
                  state.sections.firstWhere(
                        (s) => s['ClassSecID'] == state.selectedClassSecId,
                        orElse: () => {'SecName': ''},
                      )['SecName']
                      as String? ??
                  '';
              final teacherName =
                  state.teachers.firstWhere(
                        (t) => t['TeacherID'] == state.selectedTeacherId,
                        orElse: () => {'TName': ''},
                      )['TName']
                      as String? ??
                  '';

              await ReportPreviewModal.show(
                context,
                request: ReportRequest(
                  type: ReportType.attendanceRegister,
                  extraParams: {
                    'attendanceData': AttendancePdfData(
                      branchName: safeBranchName,
                      branchAddress: safeBranchAddress,
                      branchPhone: meta?.branchPhone ?? '',
                      branchPrincipal: meta?.branchPrincipal ?? '',
                      className: className,
                      sectionName: sectionName,
                      teacherName: teacherName,
                      sessionYear: state.sessionYear,
                      attDate: state.selectedDate,
                      roster: state.roster,
                      presentCount: state.summaryCounts['Present'] ?? 0,
                      absentCount: state.summaryCounts['Absent'] ?? 0,
                      leaveCount: state.summaryCounts['Leave'] ?? 0,
                      lateCount: state.summaryCounts['Late'] ?? 0,
                      totalCount: state.roster.length,
                    ),
                  },
                ),
              );
            },
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Print Roll Call'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.borderDefault),
              minimumSize: const Size(0, 42),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Mark All Present Bulk Action
          OutlinedButton.icon(
            onPressed: state.roster.isNotEmpty
                ? () => notifier.markAllAs('Present')
                : null,
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text('Mark All Present'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.statusSuccessText,
              side: const BorderSide(color: AppColors.statusSuccessText),
              minimumSize: const Size(0, 42),
            ),
          ),

          const Spacer(),

          // Submit Attendance OR Update Attendance
          if (state.isEditMode)
            ElevatedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      await notifier.updateAttendance();
                    },
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('Update Attendance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(160, 44),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      await notifier.submitAttendance();
                    },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Submit Attendance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(160, 44),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 5. LEAVE REQUESTS RIGHT DRAWER
  // ==========================================================================
  Widget _buildLeaveDrawer(
    BuildContext context,
    AttendanceState state,
    AttendanceNotifier notifier,
  ) {
    final leaveStudents = state.roster
        .where((r) => r.currentStatus == 'Leave')
        .toList();

    return Drawer(
      width: 420,
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_busy,
                    size: 20,
                    color: AppColors.statusWarningText,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Student Leave Requests (${leaveStudents.length})',
                    style: AppTypography.h3.copyWith(fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Drawer Body
            Expanded(
              child: leaveStudents.isEmpty
                  ? const Center(
                      child: Text(
                        'No students currently marked on Leave',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: leaveStudents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, idx) {
                        final stu = leaveStudents[idx];
                        final isApproved = stu.isApproved == 'true';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.borderDefault),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stu.getNameDisplay(),
                                          style: AppTypography.body.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Roll: ${stu.rollNo} | Reg: ${stu.stuRegId}',
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Approved Toggle
                                  Row(
                                    children: [
                                      Text(
                                        isApproved ? 'Approved' : 'Pending',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isApproved
                                              ? AppColors.statusSuccessText
                                              : AppColors.statusWarningText,
                                        ),
                                      ),
                                      Switch(
                                        value: isApproved,
                                        activeTrackColor:
                                            AppColors.statusSuccessText,
                                        onChanged: (val) {
                                          notifier.updateStudentLeave(
                                            stuRegId: stu.stuRegId,
                                            isApproved: val ? 'true' : 'false',
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Requested By
                              TextFormField(
                                initialValue: stu.leaveRequestedBy ?? '',
                                decoration: const InputDecoration(
                                  labelText: 'Requested By (Parent/Guardian)',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) {
                                  notifier.updateStudentLeave(
                                    stuRegId: stu.stuRegId,
                                    leaveRequestedBy: val,
                                  );
                                },
                              ),
                              const SizedBox(height: 8),

                              // Reason
                              TextFormField(
                                initialValue: stu.reason ?? '',
                                decoration: const InputDecoration(
                                  labelText: 'Leave Reason',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) {
                                  notifier.updateStudentLeave(
                                    stuRegId: stu.stuRegId,
                                    reason: val,
                                  );
                                },
                              ),
                              const SizedBox(height: 8),

                              // AttAppcation (verbatim legacy field)
                              TextFormField(
                                initialValue: stu.attAppcation ?? '',
                                decoration: const InputDecoration(
                                  labelText: 'Application Note / Ref',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) {
                                  notifier.updateStudentLeave(
                                    stuRegId: stu.stuRegId,
                                    attAppcation: val,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ATTENDANCE ROW ITEM (Self-managed controllers for snappy typing)
// ============================================================================
class _AttendanceRowItem extends StatefulWidget {
  final AttendanceRosterRow row;
  final bool isAlternate;
  final ValueChanged<String> onStatusChanged;
  final void Function(String? inTime, String? outTime) onTimesChanged;
  final ValueChanged<String> onRemarksChanged;

  const _AttendanceRowItem({
    super.key,
    required this.row,
    required this.isAlternate,
    required this.onStatusChanged,
    required this.onTimesChanged,
    required this.onRemarksChanged,
  });

  @override
  State<_AttendanceRowItem> createState() => _AttendanceRowItemState();
}

class _AttendanceRowItemState extends State<_AttendanceRowItem> {
  late TextEditingController _inTimeCtrl;
  late TextEditingController _outTimeCtrl;
  late TextEditingController _remarksCtrl;

  @override
  void initState() {
    super.initState();
    _inTimeCtrl = TextEditingController(text: widget.row.inTime ?? '');
    _outTimeCtrl = TextEditingController(text: widget.row.outTime ?? '');
    _remarksCtrl = TextEditingController(text: widget.row.attRemarks ?? '');
  }

  @override
  void didUpdateWidget(covariant _AttendanceRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.row.inTime != _inTimeCtrl.text) {
      _inTimeCtrl.text = widget.row.inTime ?? '';
    }
    if (widget.row.outTime != _outTimeCtrl.text) {
      _outTimeCtrl.text = widget.row.outTime ?? '';
    }
    if (widget.row.attRemarks != _remarksCtrl.text) {
      _remarksCtrl.text = widget.row.attRemarks ?? '';
    }
  }

  @override
  void dispose() {
    _inTimeCtrl.dispose();
    _outTimeCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final isPresentOrLate =
        row.currentStatus == 'Present' || row.currentStatus == 'Late';

    return Container(
      height: 52,
      color: widget.isAlternate ? AppColors.surfaceRaised : AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          // Roll No
          SizedBox(
            width: 60,
            child: Text(
              '${row.rollNo}',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),

          // Reg ID
          SizedBox(
            width: 70,
            child: Text(
              '${row.stuRegId}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),

          // Student Name & Father Name
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.getNameDisplay(),
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'S/O ${row.fatherName}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 4-way Segmented Control: Present / Absent / Leave / Late
          SizedBox(
            width: 310,
            child: Row(
              children: [
                _buildStatusChip('Present', AppColors.statusSuccessText),
                const SizedBox(width: 4),
                _buildStatusChip('Absent', AppColors.statusErrorText),
                const SizedBox(width: 4),
                _buildStatusChip('Leave', AppColors.statusWarningText),
                const SizedBox(width: 4),
                _buildStatusChip('Late', const Color(0xFF2563EB)),
              ],
            ),
          ),

          // In / Out Time Fields
          SizedBox(
            width: 170,
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _inTimeCtrl,
                      enabled: isPresentOrLate,
                      style: const TextStyle(fontSize: 11),
                      decoration: InputDecoration(
                        hintText: 'In',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      onChanged: (val) {
                        widget.onTimesChanged(val, _outTimeCtrl.text);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _outTimeCtrl,
                      enabled: isPresentOrLate,
                      style: const TextStyle(fontSize: 11),
                      decoration: InputDecoration(
                        hintText: 'Out',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      onChanged: (val) {
                        widget.onTimesChanged(_inTimeCtrl.text, val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Remarks Field
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _remarksCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Remarks...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                onChanged: widget.onRemarksChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, Color activeColor) {
    final isSelected = widget.row.currentStatus == status;

    return Expanded(
      child: InkWell(
        onTap: () => widget.onStatusChanged(status),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : AppColors.borderDefault.withValues(alpha: 0.6),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
