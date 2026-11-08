import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/providers/voucher_generation_provider.dart';

void main() {
  group('VoucherGenFiltersNotifier due-date rule', () {
    test('setIssueDate shifts dueDate forward when due < new issue', () {
      final notifier = VoucherGenFiltersNotifier();
      notifier.setBillingMonth('October 2026'); // issue=Oct 1, due=Oct 10
      notifier.setIssueDate(DateTime(2026, 10, 15));
      expect(notifier.state.issueDate, DateTime(2026, 10, 15));
      expect(notifier.state.dueDate, DateTime(2026, 10, 24)); // +9
    });

    test('setIssueDate leaves dueDate alone when due >= new issue', () {
      final notifier = VoucherGenFiltersNotifier();
      notifier.setBillingMonth('October 2026');
      notifier.setDueDate(DateTime(2026, 10, 20));
      notifier.setIssueDate(DateTime(2026, 10, 15));
      expect(notifier.state.issueDate, DateTime(2026, 10, 15));
      expect(notifier.state.dueDate, DateTime(2026, 10, 20));
    });

    test('setDueDate rejects due date before issue date (silent no-op)', () {
      final notifier = VoucherGenFiltersNotifier();
      notifier.setBillingMonth('October 2026');
      notifier.setIssueDate(DateTime(2026, 10, 15));
      final dueBefore = notifier.state.dueDate; // 2026-10-24
      notifier.setDueDate(DateTime(2026, 10, 10));
      expect(notifier.state.dueDate, dueBefore); // unchanged, no throw
    });

    test('setBillingMonth preserves day-1 -> day-10 default via constant', () {
      final notifier = VoucherGenFiltersNotifier();
      notifier.setBillingMonth('October 2026');
      expect(notifier.state.issueDate, DateTime(2026, 10, 1));
      expect(notifier.state.dueDate, DateTime(2026, 10, 10)); // 1 + 9
    });
  });
}
