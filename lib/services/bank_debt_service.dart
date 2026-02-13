import 'package:hive/hive.dart';
import '../models/bank_debt.dart';

class BankDebtService {
  final Box<BankDebt> _box = Hive.box<BankDebt>('bank_debts');

  List<BankDebt> getAll() => _box.values.toList();

  BankDebt? getById(String id) => _box.get(id);

  Future<void> add(BankDebt d) async => _box.put(d.id, d);

  Future<void> update(BankDebt d) async => d.save();

  Future<void> delete(BankDebt d) async => d.delete();

  // Bu ayki toplam asgari ödeme
  double totalMinPaymentForCurrentMonth() {
    final now = DateTime.now();
    final currentMonthKey =
        "${now.year}-${now.month.toString().padLeft(2, '0')}";

    final active = getAll().where((b) => b.isActive);

    double sum = 0;
    for (final b in active) {
      if (b.paidMonths.contains(currentMonthKey)) continue;

      final debt = b.totalDebt;
      double payment = b.minPaymentAmount;

      if (b.minPaymentType == "percentage") {
        payment = (debt * b.minPaymentAmount) / 100;
      }

      sum += payment;
    }
    return sum;
  }

  // ✅ DOĞRU YER BURASI
  Future<void> clearAll() async {
    await _box.clear();
  }
}
