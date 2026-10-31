import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/global_search_provider.dart';
import '../../core/theme/app_theme_tokens.dart';

/// Screen for Global Omni-Search across Students, Vouchers, Staff, and Books.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  final String initialQuery;
  final String? fromOrigin;

  const GlobalSearchScreen({
    super.key,
    required this.initialQuery,
    this.fromOrigin,
  });

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  late final TextEditingController _searchCtrl;
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormat = NumberFormat('#,##0');

  Timer? _debounceTimer;
  late String _activeQuery;
  String _activeFilter = 'all'; // 'all', 'students', 'vouchers', 'staff', 'books'

  @override
  void initState() {
    super.initState();
    _activeQuery = widget.initialQuery.trim();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant GlobalSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        _searchCtrl.text != widget.initialQuery) {
      _searchCtrl.text = widget.initialQuery;
      _activeQuery = widget.initialQuery.trim();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _activeQuery = value.trim();
        });
      }
    });
  }

  void _onSearchSubmitted(String value) {
    _debounceTimer?.cancel();
    setState(() {
      _activeQuery = value.trim();
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchCtrl.clear();
    setState(() {
      _activeQuery = '';
    });
  }

  void _handleBack() {
    if (widget.fromOrigin != null && widget.fromOrigin!.isNotEmpty) {
      context.go(widget.fromOrigin!);
    } else {
      context.go('/dashboard');
    }
  }

  String _currentSearchReturnUrl() {
    final encoded = Uri.encodeComponent(_activeQuery);
    return '/search?q=$encoded';
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(globalSearchProvider(_activeQuery));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header + Search Bar (56px)
              _buildSearchBarHeader(context),
              const SizedBox(height: AppSpacing.sm),

              // 2. Category Filter Chip Strip (44px)
              searchAsync.when(
                data: (results) => _buildFilterChipStrip(results),
                loading: () => _buildFilterChipStrip(
                  GlobalSearchResults.empty(_activeQuery),
                  isLoading: true,
                ),
                error: (_, _) => _buildFilterChipStrip(
                  GlobalSearchResults.empty(_activeQuery),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // 3. Results Body
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: searchAsync.when(
                      data: (results) => _buildResultsView(results),
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (err, _) => Center(
                        child: Text(
                          'Error loading search results: $err',
                          style: AppTypography.body.copyWith(
                            color: AppColors.statusErrorText,
                          ),
                        ),
                      ),
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

  Widget _buildSearchBarHeader(BuildContext context) {
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            tooltip: 'Back',
            onPressed: _handleBack,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Global Omni-Search',
            style: AppTypography.h2.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Container(
              height: 38.0,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: AppColors.borderDefault),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    size: 18.0,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSearchSubmitted,
                      decoration: InputDecoration(
                        hintText:
                            'Search by Student Name, Reg ID, Voucher ID (e.g. 2610-4808), Staff, or Book...',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                        isDense: true,
                        filled: false,
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.clear,
                        size: 16.0,
                        color: AppColors.textMuted,
                      ),
                      splashRadius: 14.0,
                      onPressed: _clearSearch,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChipStrip(
    GlobalSearchResults results, {
    bool isLoading = false,
  }) {
    final chips = [
      (
        key: 'all',
        label: 'All Results',
        count: results.totalCount,
      ),
      (
        key: 'students',
        label: 'Students',
        count: results.students.length,
      ),
      (
        key: 'vouchers',
        label: 'Fee Vouchers',
        count: results.vouchers.length,
      ),
      (
        key: 'staff',
        label: 'Staff',
        count: results.staff.length,
      ),
      (
        key: 'books',
        label: 'Library Books',
        count: results.books.length,
      ),
    ];

    return SizedBox(
      height: 44.0,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final c = chips[index];
          final isSelected = _activeFilter == c.key;

          return FilterChip(
            selected: isSelected,
            showCheckmark: false,
            label: Text(
              isLoading ? c.label : '${c.label} (${c.count})',
              style: AppTypography.label.copyWith(
                fontSize: 12.0,
                color: isSelected
                    ? AppColors.surfaceRaised
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            backgroundColor: AppColors.surfaceRaised,
            selectedColor: AppColors.brandPrimary,
            side: BorderSide(
              color: isSelected
                  ? AppColors.brandPrimary
                  : AppColors.borderDefault,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            onSelected: (_) {
              setState(() {
                _activeFilter = c.key;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildResultsView(GlobalSearchResults results) {
    if (_activeQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.manage_search,
              size: 56.0,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Search School Database',
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4.0),
            Text(
              'Type a name, Registration ID, or Voucher ID (e.g. 2610-4808) to search across students, fee vouchers, staff, and library books.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (results.totalCount == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_outlined,
              size: 56.0,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No Records Found',
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4.0),
            Text(
              'No matching records found for "$_activeQuery". Try checking the spelling or searching by Reg ID.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final showStudents =
        (_activeFilter == 'all' || _activeFilter == 'students') &&
        results.students.isNotEmpty;
    final showVouchers =
        (_activeFilter == 'all' || _activeFilter == 'vouchers') &&
        results.vouchers.isNotEmpty;
    final showStaff =
        (_activeFilter == 'all' || _activeFilter == 'staff') &&
        results.staff.isNotEmpty;
    final showBooks =
        (_activeFilter == 'all' || _activeFilter == 'books') &&
        results.books.isNotEmpty;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (showVouchers) ...[
            _buildSectionHeader(
              'Fee Vouchers (${results.vouchers.length})',
              Icons.payments_outlined,
            ),
            const SizedBox(height: AppSpacing.xs),
            ...results.vouchers.map(_buildVoucherRow),
            const SizedBox(height: AppSpacing.md),
          ],
          if (showStudents) ...[
            _buildSectionHeader(
              'Students (${results.students.length})',
              Icons.people_outline,
            ),
            const SizedBox(height: AppSpacing.xs),
            ...results.students.map(_buildStudentRow),
            const SizedBox(height: AppSpacing.md),
          ],
          if (showStaff) ...[
            _buildSectionHeader(
              'Staff & Faculty (${results.staff.length})',
              Icons.badge_outlined,
            ),
            const SizedBox(height: AppSpacing.xs),
            ...results.staff.map(_buildStaffRow),
            const SizedBox(height: AppSpacing.md),
          ],
          if (showBooks) ...[
            _buildSectionHeader(
              'Library Books (${results.books.length})',
              Icons.local_library_outlined,
            ),
            const SizedBox(height: AppSpacing.xs),
            ...results.books.map(_buildBookRow),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16.0, color: AppColors.brandPrimary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: AppTypography.label.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 13.0,
          ),
        ),
      ],
    );
  }

  Widget _buildVoucherRow(VoucherSearchHit v) {
    final returnUrl = Uri.encodeComponent(_currentSearchReturnUrl());
    final statusColor = v.isPaidStatus
        ? AppColors.statusSuccessText
        : (v.isRolledOver
            ? AppColors.statusWarningText
            : AppColors.statusErrorText);
    final statusBg = v.isPaidStatus
        ? AppColors.statusSuccessBg
        : (v.isRolledOver
            ? AppColors.statusWarningBg
            : AppColors.statusErrorBg);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          if (v.isUnpaid) {
            context.go(
              '/fees/receipts?voucherId=${Uri.encodeComponent(v.voucherId)}&studentId=${v.stuRegId}&from=$returnUrl',
            );
          } else {
            context.go(
              '/fees/ledger?search=${Uri.encodeComponent(v.voucherId)}&from=$returnUrl',
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              // Monospace Voucher ID Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.brandPrimary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  v.voucherId,
                  style: AppTypography.monospace.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.0,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Student Info & Month
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          v.studentName,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '#${v.stuRegId}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (v.className != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '(${v.className})',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      'Billing Month: ${v.forMonth}${v.sessionYr != null ? " • Session ${v.sessionYr}" : ""}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              ),

              // Amounts & Status Pill
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          v.statusLabel,
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        v.isPaidStatus
                            ? 'Rs. ${_currencyFormat.format(v.paidAmt)}'
                            : 'Rs. ${_currencyFormat.format(v.netDue)}',
                        style: AppTypography.label.copyWith(
                          fontWeight: FontWeight.w700,
                          color: v.isPaidStatus
                              ? AppColors.statusSuccessText
                              : AppColors.statusErrorText,
                          fontSize: 13.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    'Gross: ${_currencyFormat.format(v.subTotal)} • Disc: ${_currencyFormat.format(v.discount)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),

              // Quick Action Buttons
              OutlinedButton.icon(
                icon: const Icon(Icons.person_outline, size: 13.0),
                label: const Text('Student Profile', style: TextStyle(fontSize: 11.0)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  minimumSize: const Size(0, 30),
                ),
                onPressed: () {
                  context.go('/students/${v.stuRegId}?from=$returnUrl');
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              ElevatedButton.icon(
                icon: const Icon(Icons.receipt_long_outlined, size: 13.0),
                label: const Text('Open in Teller', style: TextStyle(fontSize: 11.0)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  minimumSize: const Size(0, 30),
                ),
                onPressed: () {
                  context.go(
                    '/fees/receipts?voucherId=${Uri.encodeComponent(v.voucherId)}&studentId=${v.stuRegId}&from=$returnUrl',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentRow(StudentSearchHit s) {
    final returnUrl = Uri.encodeComponent(_currentSearchReturnUrl());

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          context.go('/students/${s.stuRegId}?from=$returnUrl');
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              // Student Reg ID Badge
              Container(
                width: 48.0,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Text(
                  '#${s.stuRegId}',
                  style: AppTypography.monospace.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11.0,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Name, Father, Class
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          s.fullName,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 1.0,
                          ),
                          decoration: BoxDecoration(
                            color: s.isPresent
                                ? AppColors.statusSuccessBg
                                : AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            s.isPresent ? 'Active' : 'Alumni',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w600,
                              color: s.isPresent
                                  ? AppColors.statusSuccessText
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${s.classSectionDisplay}${s.fatherName != null ? " • S/O ${s.fatherName}" : ""}${s.mobile != null ? " • Mob: ${s.mobile}" : ""}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons
              OutlinedButton.icon(
                icon: const Icon(Icons.payments_outlined, size: 13.0),
                label: const Text('Collect Fee', style: TextStyle(fontSize: 11.0)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  minimumSize: const Size(0, 30),
                ),
                onPressed: () {
                  context.go(
                    '/fees/receipts?studentId=${s.stuRegId}&from=$returnUrl',
                  );
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 13.0),
                label: const Text('View Profile', style: TextStyle(fontSize: 11.0)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  minimumSize: const Size(0, 30),
                ),
                onPressed: () {
                  context.go('/students/${s.stuRegId}?from=$returnUrl');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaffRow(StaffSearchHit t) {
    final returnUrl = Uri.encodeComponent(_currentSearchReturnUrl());

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          context.go('/staff/teachers/${t.teacherId}?from=$returnUrl');
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 48.0,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Text(
                  '#${t.teacherId}',
                  style: AppTypography.monospace.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11.0,
                    color: AppColors.textPrimary,
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
                          t.name,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 1.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            t.category,
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${t.subject != null ? "Subject: ${t.subject}" : ""}${t.fatherName != null ? " • S/O ${t.fatherName}" : ""}${t.phone != null ? " • Phone: ${t.phone}" : ""}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 13.0),
                label: const Text('Faculty Profile', style: TextStyle(fontSize: 11.0)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  minimumSize: const Size(0, 30),
                ),
                onPressed: () {
                  context.go('/staff/teachers/${t.teacherId}?from=$returnUrl');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookRow(BookSearchHit b) {
    final returnUrl = Uri.encodeComponent(_currentSearchReturnUrl());

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          context.go('/library/${b.bookId}?from=$returnUrl');
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 48.0,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Text(
                  b.bookId,
                  style: AppTypography.monospace.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11.0,
                    color: AppColors.textPrimary,
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
                          b.bookName,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (b.categoryName != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 1.0,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              b.categoryName!,
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 10.0,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${b.author != null ? "Author: ${b.author}" : ""}${b.publisher != null ? " • Publisher: ${b.publisher}" : ""}${b.price != null ? " • Price: Rs. ${_currencyFormat.format(b.price)}" : ""}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 13.0),
                label: const Text('Book Profile', style: TextStyle(fontSize: 11.0)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  minimumSize: const Size(0, 30),
                ),
                onPressed: () {
                  context.go('/library/${b.bookId}?from=$returnUrl');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
