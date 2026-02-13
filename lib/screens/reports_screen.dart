import 'package:flutter/material.dart';

import '../services/income_service.dart';
import '../services/expense_service.dart';
import '../services/bank_debt_service.dart';

import '../utils/period_utils.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final IncomeService _incomeService = IncomeService();
  final ExpenseService _expenseService = ExpenseService();
  final BankDebtService _bankService = BankDebtService();

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

  String _monthShort(DateTime d) {
    const m = ["Oca","Şub","Mar","Nis","May","Haz","Tem","Ağu","Eyl","Eki","Kas","Ara"];
    return "${m[d.month - 1]} ${d.year % 100}";
  }

  // Son 6 "dönem" (ayı) raporu (ayın 6’sı kuralı ile)
  List<DateTime> _lastPeriods() {
    final p = PeriodUtils.defaultSelectedPeriod();
    final base = DateTime(p.year, p.month, 1);
    return List.generate(6, (i) => DateTime(base.year, base.month - (5 - i), 1));
  }

  bool _belongs(DateTime date, DateTime period) {
    return PeriodUtils.belongsToSelectedPeriod(
      date: date,
      selectedMonth: period.month,
      selectedYear: period.year,
    );
  }

  @override
  Widget build(BuildContext context) {
    final periods = _lastPeriods();
    final incomes = _incomeService.getAll();
    final expenses = _expenseService.getAll();
    final banks = _bankService.getAll();

    final series = periods.map((p) {
      final incExp = incomes.where((i) => _belongs(i.date, p)).fold<double>(0, (s, e) => s + e.amount);
      final incRec = incomes.where((i) => _belongs(i.date, p) && i.isReceived).fold<double>(0, (s, e) => s + e.amount);

      final expExp = expenses.where((e) => _belongs(e.date, p)).fold<double>(0, (s, e) => s + e.amount);
      final expPaid = expenses.where((e) => _belongs(e.date, p) && e.isPaid).fold<double>(0, (s, e) => s + e.amount);

      return _SeriesPoint(
        period: p,
        incomeExpected: incExp,
        incomeReceived: incRec,
        expenseExpected: expExp,
        expensePaid: expPaid,
      );
    }).toList();

    final maxVal = series
        .map((x) => [x.incomeExpected, x.expenseExpected].reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);

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
                        Text("Raporlar",
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text("Gelir–Gider trendi ve borç özetleri",
                            style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Aylara göre gelir-gider
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
                    const Text("Son 6 Dönem – Gelir & Gider",
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 170,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: series.map((p) {
                          final incH = maxVal <= 0 ? 0.0 : (p.incomeExpected / maxVal);
                          final expH = maxVal <= 0 ? 0.0 : (p.expenseExpected / maxVal);

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Bars
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 120 * incH,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16A34A).withOpacity(0.22),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.25)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Container(
                                          height: 120 * expH,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE11D48).withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE11D48).withOpacity(0.20)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(_monthShort(p.period),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Not: Dönem hesabı ayın 6’sı kuralına göre yapılır.",
                      style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Borç kapanma özeti (plan ekranına “özet”)
              Expanded(
                child: Container(
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
                      const Text("Borç Kapanma Özeti",
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      if (banks.isEmpty)
                        const Expanded(child: Center(child: Text("Henüz banka eklenmemiş")))
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: banks.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 18,
                              color: Colors.black.withOpacity(0.06),
                            ),
                            itemBuilder: (_, i) {
                              final b = banks[i];

                              // Basit tahmin: Asgari ödeme miktarı (yüzdeyse, ilk ay borca göre hesapla)
                              double minPay = b.minPaymentAmount;
                              if (b.minPaymentType == "percentage") {
                                minPay = (b.totalDebt * b.minPaymentAmount) / 100.0;
                              }
                              if (minPay <= 0) minPay = 1;

                              // Çok kaba kapanma ayı (faizi hesaba katmadan) — sadece “özet”
                              final roughMonths = (b.totalDebt / minPay).ceil();

                              return Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(b.name,
                                            style: const TextStyle(fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Borç: ${_fmtMoney(b.totalDebt)} • Asgari: ${_fmtMoney(minPay)}",
                                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.15)),
                                    ),
                                    child: Text(
                                      "~$roughMonths ay",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                  )
                                ],
                              );
                            },
                          ),
                        ),
                    ],
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

class _SeriesPoint {
  final DateTime period;
  final double incomeExpected;
  final double incomeReceived;
  final double expenseExpected;
  final double expensePaid;

  _SeriesPoint({
    required this.period,
    required this.incomeExpected,
    required this.incomeReceived,
    required this.expenseExpected,
    required this.expensePaid,
  });
}
