import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/groups/data/helpers/period_helper.dart';

void main() {
  group('PeriodHelper', () {
    test('currentWeekPeriodKey handles ISO week transitions (end of year)', () {
      // 2025 ends on Wed (Dec 31). 2026 starts on Thu (Jan 1).
      // Dec 29, 2025 (Mon) is Mon of Week 1, 2026 because Jan 1 is Thu (in same week).
      // Wait, let's verify logic. 
      // Rule: Week 1 is week with first Thursday.
      // Jan 1 2026 is Thursday. So that week is Week 1.
      // Mon Dec 29 2025 is in that week. So it should be 2026-W01.
      
      final date = DateTime(2025, 12, 29); // Monday
      final key = PeriodHelper.currentWeekPeriodKey(date);
      expect(key, '2026-W01');
    });

    test('currentWeekPeriodKey handles regular date', () {
      final date = DateTime(2025, 2, 3); // Monday
      final key = PeriodHelper.currentWeekPeriodKey(date);
      // Jan 1 2025 is Wed. First Thu is Jan 2.
      // Week 1 starts Mon Dec 30 2024.
      // Feb 3 is ... well, let's trust the calc or verify with known value.
      // W01: Dec 30
      // W02: Jan 6
      // W03: Jan 13
      // W04: Jan 20
      // W05: Jan 27
      // W06: Feb 3
      expect(key, '2025-W06');
    });

    test('currentMonthPeriodKey formats correctly', () {
      expect(PeriodHelper.currentMonthPeriodKey(DateTime(2025, 1, 5)), '2025-01');
      expect(PeriodHelper.currentMonthPeriodKey(DateTime(2025, 12, 31)), '2025-12');
    });

    test('getWeekStart returns Monday 00:00', () {
      final date = DateTime(2025, 2, 5, 15, 30); // Wednesday
      final start = PeriodHelper.getWeekStart(date);
      expect(start.weekday, DateTime.monday);
      expect(start.hour, 0);
      expect(start.minute, 0);
      expect(start.year, 2025);
      expect(start.month, 2);
      expect(start.day, 3);
    });

    test('getWeekEnd returns next Monday 00:00 (exclusive)', () {
      final date = DateTime(2025, 2, 5);
      final end = PeriodHelper.getWeekEnd(date);
      expect(end.weekday, DateTime.monday);
      expect(end.day, 10);
      expect(end.hour, 0);
    });

    test('getMonthStart returns 1st of month', () {
      final date = DateTime(2025, 2, 15);
      final start = PeriodHelper.getMonthStart(date);
      expect(start.day, 1);
      expect(start.hour, 0);
    });

    test('getMonthEnd returns 1st of next month (exclusive)', () {
      final date = DateTime(2025, 2, 15);
      final end = PeriodHelper.getMonthEnd(date);
      expect(end.month, 3);
      expect(end.day, 1);
      expect(end.hour, 0);
    });
    
    test('generateChallengeDeterministicId format', () {
      final id = PeriodHelper.generateChallengeDeterministicId('tpl1', '2025-W01');
      expect(id, 'tmpl__tpl1__2025-W01');
    });
  });
}

