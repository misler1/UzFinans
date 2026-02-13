import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/income.dart';
import '../models/expense.dart';
import '../models/bank_debt.dart';

import '../services/income_service.dart';
import '../services/expense_service.dart';
import '../services/bank_debt_service.dart';



class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final IncomeService _incomeService = IncomeService();
  final ExpenseService _expenseService = ExpenseService();
  final BankDebtService _bankService = BankDebtService();

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Map<String, dynamic> _incomeToMap(Income i) => {
        "id": i.id,
        "name": i.name,
        "type": i.type,
        "amount": i.amount,
        "date": i.date.toIso8601String(),
        "isReceived": i.isReceived,
        "recurring": i.recurring,
        "frequency": i.frequency,
        "endDate": i.endDate?.toIso8601String(),
      };

  Map<String, dynamic> _expenseToMap(Expense e) => {
        "id": e.id,
        "name": e.name,
        "type": e.type,
        "amount": e.amount,
        "date": e.date.toIso8601String(),
        "isPaid": e.isPaid,
        "recurring": e.recurring,
        "frequency": e.frequency,
        "endDate": e.endDate?.toIso8601String(),
      };

  Map<String, dynamic> _bankToMap(BankDebt b) => {
        "id": b.id,
        "name": b.name,
        "debtType": b.debtType,
        "totalDebt": b.totalDebt,
        "interestRate": b.interestRate,
        "interestType": b.interestType,
        "minPaymentType": b.minPaymentType,
        "minPaymentAmount": b.minPaymentAmount,
        "paymentDueDay": b.paymentDueDay,
        "isActive": b.isActive,
        "extraPaidTotal": b.extraPaidTotal,
        "customPayments": b.customPayments,
        "paidMonths": b.paidMonths,
      };

  Future<void> _exportJson() async {
    final payload = {
      "version": 1,
      "exportedAt": DateTime.now().toIso8601String(),
      "incomes": _incomeService.getAll().map(_incomeToMap).toList(),
      "expenses": _expenseService.getAll().map(_expenseToMap).toList(),
      "banks": _bankService.getAll().map(_bankToMap).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent("  ").convert(payload);
    await Clipboard.setData(ClipboardData(text: jsonStr));
    _toast("Yedek JSON kopyalandı ✅");
  }

  Future<void> _importJson() async {
    final ctrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("JSON İçe Aktar"),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: "Buraya export ettiğin JSON’u yapıştır…",
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("İçe Aktar")),
        ],
      ),
    );

    if (ok != true) return;

    // ✅ BURAYA
    await _incomeService.clearAll();
    await _expenseService.clearAll();
    await _bankService.clearAll();

ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text("Tüm veriler silindi")),
);

setState(() {});


    try {
      final decoded = jsonDecode(ctrl.text.trim());
      if (decoded is! Map<String, dynamic>) {
        _toast("JSON formatı hatalı.");
        return;
      }

      final incomes = (decoded["incomes"] as List?) ?? [];
      final expenses = (decoded["expenses"] as List?) ?? [];
      final banks = (decoded["banks"] as List?) ?? [];

      // Önce temizle (servislerinde clear yoksa, tek tek delete yaparız)
      await _incomeService.clearAll();
      await _expenseService.clearAll();
      await _bankService.clearAll();

      for (final x in incomes) {
        final m = (x as Map).cast<String, dynamic>();
        await _incomeService.add(Income(
          id: m["id"].toString(),
          name: (m["name"] ?? "").toString(),
          type: (m["type"] ?? "-").toString(),
          amount: (m["amount"] as num).toDouble(),
          date: DateTime.parse(m["date"]),
          isReceived: (m["isReceived"] ?? false) as bool,
          recurring: (m["recurring"] ?? false) as bool,
          frequency: (m["frequency"] ?? "monthly").toString(),
          endDate: m["endDate"] == null ? null : DateTime.parse(m["endDate"]),
        ));
      }

      for (final x in expenses) {
        final m = (x as Map).cast<String, dynamic>();
        await _expenseService.add(Expense(
          id: m["id"].toString(),
          name: (m["name"] ?? "").toString(),
          type: (m["type"] ?? "-").toString(),
          amount: (m["amount"] as num).toDouble(),
          date: DateTime.parse(m["date"]),
          isPaid: (m["isPaid"] ?? false) as bool,
          recurring: (m["recurring"] ?? false) as bool,
          frequency: (m["frequency"] ?? "monthly").toString(),
          endDate: m["endDate"] == null ? null : DateTime.parse(m["endDate"]),
        ));
      }

      for (final x in banks) {
        final m = (x as Map).cast<String, dynamic>();
        await _bankService.add(BankDebt(
          id: m["id"].toString(),
          name: (m["name"] ?? "").toString(),
          debtType: (m["debtType"] ?? "Credit Card").toString(),
          totalDebt: (m["totalDebt"] as num).toDouble(),
          interestRate: (m["interestRate"] as num).toDouble(),
          interestType: (m["interestType"] ?? "Monthly").toString(),
          minPaymentType: (m["minPaymentType"] ?? "amount").toString(),
          minPaymentAmount: (m["minPaymentAmount"] as num).toDouble(),
          paymentDueDay: (m["paymentDueDay"] as num).toInt(),
          isActive: (m["isActive"] ?? true) as bool,
          extraPaidTotal: (m["extraPaidTotal"] as num?)?.toDouble() ?? 0,
          customPayments: (m["customPayments"] as Map?)?.cast<String, String>() ?? {},
          paidMonths: (m["paidMonths"] as List?)?.map((e) => e.toString()).toList() ?? [],
        ));
      }

      if (mounted) setState(() {});
      _toast("İçe aktarma tamam ✅");
    } catch (_) {
      _toast("JSON okunamadı. İçerik hatalı olabilir.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Ayarlar",
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text("Yedekleme / geri yükleme",
                            style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Yedekleme", style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _exportJson,
                        icon: const Icon(Icons.copy),
                        label: const Text("Export JSON (Panoya Kopyala)"),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _importJson,
                        icon: const Icon(Icons.file_download),
                        label: const Text("Import JSON (Yapıştır)"),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Not: İçe aktarım mevcut kayıtları temizler ve JSON’daki verileri yeniden yazar.",
                      style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
