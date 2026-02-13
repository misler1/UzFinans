import 'package:flutter/material.dart';

import '../models/income.dart';
import '../models/expense.dart';
import '../models/bank_debt.dart';

import '../services/income_service.dart';
import '../services/expense_service.dart';
import '../services/bank_debt_service.dart';

import '../utils/period_utils.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final IncomeService _incomeService = IncomeService();
  final ExpenseService _expenseService = ExpenseService();
  final BankDebtService _bankService = BankDebtService();

  late int selectedMonth;
  late int selectedYear;

  static const List<Map<String, dynamic>> months = [
    {"value": 1, "label": "Ocak"},
    {"value": 2, "label": "Şubat"},
    {"value": 3, "label": "Mart"},
    {"value": 4, "label": "Nisan"},
    {"value": 5, "label": "Mayıs"},
    {"value": 6, "label": "Haziran"},
    {"value": 7, "label": "Temmuz"},
    {"value": 8, "label": "Ağustos"},
    {"value": 9, "label": "Eylül"},
    {"value": 10, "label": "Ekim"},
    {"value": 11, "label": "Kasım"},
    {"value": 12, "label": "Aralık"},
  ];

  @override
  void initState() {
    super.initState();
    final p = PeriodUtils.defaultSelectedPeriod();
    selectedMonth = p.month;
    selectedYear = p.year;
  }

  String _monthLabel(int m) =>
      months.firstWhere((x) => x["value"] == m)["label"] as String;

  List<int> _years() {
    final now = DateTime.now().year;
    return List.generate(7, (i) => now + i);
  }

  String _fmtMoney(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final left = s.length - i;
      buf.write(s[i]);
      if (left > 1 && left % 3 == 1) buf.write('.');
    }
    return "₺$buf";
  }

  List<Income> get _periodIncomes {
    final all = _incomeService.getAll();
    return all
        .where((i) => PeriodUtils.belongsToSelectedPeriod(
              date: i.date,
              selectedMonth: selectedMonth,
              selectedYear: selectedYear,
            ))
        .toList();
  }

  List<Expense> get _periodExpenses {
    final all = _expenseService.getAll();
    return all
        .where((e) => PeriodUtils.belongsToSelectedPeriod(
              date: e.date,
              selectedMonth: selectedMonth,
              selectedYear: selectedYear,
            ))
        .toList();
  }

  double get _incomeExpected =>
      _periodIncomes.fold(0, (s, e) => s + e.amount);

  double get _incomeReceived =>
      _periodIncomes.where((e) => e.isReceived).fold(0, (s, e) => s + e.amount);

  double get _expenseExpected =>
      _periodExpenses.fold(0, (s, e) => s + e.amount);

  double get _expensePaid =>
      _periodExpenses.where((e) => e.isPaid).fold(0, (s, e) => s + e.amount);

  double get _cashNet => _incomeReceived - _expensePaid;

  List<BankDebt> get _banks => _bankService.getAll();

  double get _totalDebt =>
      _banks.fold(0, (s, b) => s + b.totalDebt);

  double get _totalMinPaymentThisMonth =>
      _bankService.totalMinPaymentForCurrentMonth();

  Widget _smallFilter<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.black.withOpacity(0.10)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.black.withOpacity(0.10)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color tint,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tint.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withOpacity(0.70))),
                  const SizedBox(height: 6),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withOpacity(0.55),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
              // Başlık + filtre
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Dashboard",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Genel özet – ${_monthLabel(selectedMonth)} $selectedYear",
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _smallFilter<int>(
                    label: "Ay",
                    value: selectedMonth,
                    items: months
                        .map((m) => DropdownMenuItem<int>(
                              value: m["value"] as int,
                              child: Text(m["label"] as String),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => selectedMonth = v ?? selectedMonth),
                  ),
                  const SizedBox(width: 10),
                  _smallFilter<int>(
                    label: "Yıl",
                    value: selectedYear,
                    items: _years()
                        .map((y) =>
                            DropdownMenuItem<int>(value: y, child: Text("$y")))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => selectedYear = v ?? selectedYear),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Kartlar
              Row(
                children: [
                  _card(
                    title: "Gelir (Alınan / Beklenen)",
                    value: "${_fmtMoney(_incomeReceived)} / ${_fmtMoney(_incomeExpected)}",
                    subtitle: "Seçili dönem",
                    icon: Icons.trending_up,
                    tint: const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 10),
                  _card(
                    title: "Gider (Ödenen / Beklenen)",
                    value: "${_fmtMoney(_expensePaid)} / ${_fmtMoney(_expenseExpected)}",
                    subtitle: "Seçili dönem",
                    icon: Icons.trending_down,
                    tint: const Color(0xFFE11D48),
                  ),
                  const SizedBox(width: 10),
                  _card(
                    title: "Kalan Nakit",
                    value: _fmtMoney(_cashNet),
                    subtitle: "Alınan gelir - ödenen gider",
                    icon: Icons.account_balance_wallet_outlined,
                    tint: _cashNet >= 0 ? const Color(0xFF2563EB) : const Color(0xFFE11D48),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  _card(
                    title: "Toplam Borç",
                    value: _fmtMoney(_totalDebt),
                    subtitle: "Tüm bankalar",
                    icon: Icons.landscape_outlined,
                    tint: const Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 10),
                  _card(
                    title: "Bu Ay Asgari Ödeme",
                    value: _fmtMoney(_totalMinPaymentThisMonth),
                    subtitle: "Ödeme planına göre",
                    icon: Icons.payments_outlined,
                    tint: const Color(0xFF64748B),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Hızlı Özet",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        Text("• Bu dönemde ${_periodIncomes.length} gelir kaydı var."),
                        Text("• Bu dönemde ${_periodExpenses.length} gider kaydı var."),
                        const SizedBox(height: 10),
                        Text("• Toplam banka sayısı: ${_banks.length}"),
                        const SizedBox(height: 10),
                        Text(
                          "Not: Dönem hesabı ayın 6’sı kuralına göre yapılır.",
                          style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 12),
                        ),
                      ],
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
}
