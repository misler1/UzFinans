import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../models/bank_debt.dart';

class BankDebtService {
  final Box<BankDebt> _box = Hive.box<BankDebt>('bank_debts');
  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('bank_debts');

  List<BankDebt> getAll() => _box.values.toList();

  BankDebt? getById(String id) => _box.get(id);

  Future<void> add(BankDebt d) async {
    await _box.put(d.id, d);
    unawaited(
      _collection
          .doc(d.id)
          .set(_toMap(d))
          .timeout(const Duration(seconds: 8))
          .catchError((_) {}),
    );
  }

  Future<void> update(BankDebt d) async {
    await _box.put(d.id, d);
    unawaited(
      _collection
          .doc(d.id)
          .set(_toMap(d))
          .timeout(const Duration(seconds: 8))
          .catchError((_) {}),
    );
  }

  Future<void> delete(BankDebt d) async {
    await _box.delete(d.id);
    unawaited(
      _collection
          .doc(d.id)
          .delete()
          .timeout(const Duration(seconds: 8))
          .catchError((_) {}),
    );
  }

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
    final snap = await _collection.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> syncFromCloud() async {
    final snap = await _collection.get();

    if (snap.docs.isEmpty && _box.isNotEmpty) {
      for (final item in _box.values) {
        await _collection.doc(item.id).set(_toMap(item));
      }
      return;
    }

    final cloudIds = <String>{};
    for (final doc in snap.docs) {
      final bank = _fromMap(doc.id, doc.data());
      await _box.put(bank.id, bank);
      cloudIds.add(bank.id);
    }

    for (final bank in _box.values) {
      if (!cloudIds.contains(bank.id)) {
        await _collection.doc(bank.id).set(_toMap(bank));
      }
    }
  }

  Map<String, dynamic> _toMap(BankDebt b) {
    return {
      'name': b.name,
      'debtType': b.debtType,
      'totalDebt': b.totalDebt,
      'interestRate': b.interestRate,
      'interestType': b.interestType,
      'minPaymentType': b.minPaymentType,
      'minPaymentAmount': b.minPaymentAmount,
      'paymentDueDay': b.paymentDueDay,
      'isActive': b.isActive,
      'customPayments': b.customPayments,
      'paidMonths': b.paidMonths,
      'extraPaidTotal': b.extraPaidTotal,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  BankDebt _fromMap(String id, Map<String, dynamic> data) {
    return BankDebt(
      id: id,
      name: (data['name'] ?? '') as String,
      debtType: (data['debtType'] ?? '') as String,
      totalDebt: ((data['totalDebt'] ?? 0) as num).toDouble(),
      interestRate: ((data['interestRate'] ?? 0) as num).toDouble(),
      interestType: (data['interestType'] ?? 'Monthly') as String,
      minPaymentType: (data['minPaymentType'] ?? 'amount') as String,
      minPaymentAmount: ((data['minPaymentAmount'] ?? 0) as num).toDouble(),
      paymentDueDay: ((data['paymentDueDay'] ?? 1) as num).toInt(),
      isActive: (data['isActive'] ?? true) as bool,
      customPayments:
          Map<String, String>.from(data['customPayments'] as Map? ?? {}),
      paidMonths: List<String>.from(data['paidMonths'] as List? ?? []),
      extraPaidTotal: ((data['extraPaidTotal'] ?? 0) as num).toDouble(),
    );
  }
}
