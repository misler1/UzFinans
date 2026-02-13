import 'package:flutter/material.dart';
import '../models/bank_debt.dart';
import '../services/bank_debt_service.dart';

class BankPlanScreen extends StatefulWidget {
  final String bankId;
  const BankPlanScreen({super.key, required this.bankId});

  @override
  State<BankPlanScreen> createState() => _BankPlanScreenState();
}

class _BankPlanScreenState extends State<BankPlanScreen> {
  final BankDebtService _service = BankDebtService();

  String _monthKey(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}";

  String _monthLabel(DateTime d) {
    const months = [
      "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
      "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
    ];
    return "${months[d.month - 1]} ${d.year}";
  }

  String _fmtMoney(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final dec = parts[1];
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final left = intPart.length - i;
      buf.write(intPart[i]);
      if (left > 1 && left % 3 == 1) buf.write('.');
    }
    return "₺$buf,$dec";
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  DateTime _addMonths(DateTime d, int m) => DateTime(d.year, d.month + m, 1);

  // ✅ FAİZ HESABI: rate her zaman "AYLIK % oran" kabul edilir.
  // Monthly: direkt aylık oran kullanılır.
  // Daily: aylık oran -> günlük orana çevrilir (aylık/30) ve 30 gün uygulanır.
  double _calcInterestForMonth({
    required double currentDebt,
    required double monthlyPercentRate, // ör: 5 -> %5 aylık
    required String interestType, // "Monthly" / "Daily"
  }) {
    final monthlyRate = monthlyPercentRate / 100.0;

    if (interestType == "Daily") {
      // ✅ aylık oranı günlük orana çevir (basit yaklaşım)
      final dailyRate = monthlyRate / 30.0;
      return currentDebt * dailyRate * 30.0; // ≈ currentDebt * monthlyRate
    }

    // Monthly
    return currentDebt * monthlyRate;
  }

  List<_ProjectionRow> _buildProjection(BankDebt bank) {
    final results = <_ProjectionRow>[];
    double currentDebt = bank.totalDebt;

    int monthOffset = 0;
    bool warning = false;

    while (currentDebt > 0.01 && monthOffset < 60) {
      final date = _addMonths(DateTime.now(), monthOffset);
      final key = _monthKey(date);

      // ✅ doğru faiz hesabı
      final double interest = _calcInterestForMonth(
        currentDebt: currentDebt,
        monthlyPercentRate: bank.interestRate,
        interestType: bank.interestType,
      );

      // Default payment
      double payment = bank.minPaymentAmount;
      if (bank.minPaymentType == "percentage") {
        payment = (currentDebt * bank.minPaymentAmount) / 100.0;
      }

      // Custom override (Map<String, String>)
      final String? customStr = bank.customPayments[key];
      final bool isCustom = customStr != null && customStr.trim().isNotEmpty;
      if (isCustom) {
        payment = double.tryParse(customStr!.replaceAll(',', '.')) ?? payment;
      }

      // Replit warning: payment <= interest ve 24. ayda kes
      if (payment <= interest && currentDebt > 0) {
        if (monthOffset >= 23) {
          warning = true;
          break;
        }
      }

      // ödeme borç + faizden fazla olamaz
      final double actualPayment =
          payment > (currentDebt + interest) ? (currentDebt + interest) : payment;

      // kalan borç
      final double remainingDouble =
          (currentDebt + interest - actualPayment).clamp(0.0, double.infinity);

      results.add(_ProjectionRow(
        index: monthOffset,
        date: date,
        monthKey: key,
        startingDebt: currentDebt,
        interest: interest,
        payment: actualPayment,
        remainingDebt: remainingDouble,
        isCustom: isCustom,
        hasWarning: false,
      ));

      currentDebt = remainingDouble;
      monthOffset++;
    }

    // warning flag'ini üstte gösteriyorsun, burada ekstra bir şey yok
    if (warning) {
      // boş
    }

    return results;
  }

  bool _hasWarning(BankDebt bank) {
    double currentDebt = bank.totalDebt;
    int monthOffset = 0;

    while (currentDebt > 0.01 && monthOffset < 60) {
      final date = _addMonths(DateTime.now(), monthOffset);
      final key = _monthKey(date);

      // ✅ doğru faiz hesabı
      final interest = _calcInterestForMonth(
        currentDebt: currentDebt,
        monthlyPercentRate: bank.interestRate,
        interestType: bank.interestType,
      );

      double payment = bank.minPaymentAmount;
      if (bank.minPaymentType == "percentage") {
        payment = (currentDebt * bank.minPaymentAmount) / 100;
      }

      final custom = bank.customPayments[key];
      if (custom != null && custom.trim().isNotEmpty) {
        payment = double.tryParse(custom.replaceAll(',', '.')) ?? payment;
      }

      if (payment <= interest && currentDebt > 0) {
        if (monthOffset >= 23) return true;
      }

      final actualPayment =
          payment > (currentDebt + interest) ? (currentDebt + interest) : payment;

      currentDebt =
          (currentDebt + interest - actualPayment).clamp(0.0, double.infinity);

      monthOffset++;
    }

    return false;
  }

  Future<void> _editCustomPayment(BankDebt bank, String monthKey, double currentPayment) async {
    final ctrl = TextEditingController(text: currentPayment.toStringAsFixed(2));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ödeme Tutarını Düzenle"),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: "Tutar"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Kaydet")),
        ],
      ),
    );

    if (ok == true) {
      bank.customPayments[monthKey] = ctrl.text.trim();
      await _service.update(bank);
      setState(() {});
      _toast("Ödeme planı güncellendi");
    }
  }

  Future<void> _markPaid(BankDebt bank, DateTime date, double amount) async {
    final key = _monthKey(date);

    if (bank.paidMonths.contains(key)) return;

    bank.totalDebt = (bank.totalDebt - amount).clamp(0, double.infinity);
    bank.paidMonths.add(key);

    await _service.update(bank);

    _toast("${_monthLabel(date)} için ${_fmtMoney(amount)} ödeme kaydedildi.");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bank = _service.getById(widget.bankId);

    if (bank == null) {
      return const Scaffold(
        body: Center(child: Text("Banka bulunamadı")),
      );
    }

    final projection = _buildProjection(bank);
    final hasWarning = _hasWarning(bank);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text("${bank.name} - Ödeme Planı"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (hasWarning)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Dikkat: Ödeme miktarı faizi karşılamıyor! Plan 24. ayda kesildi.",
                        style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                _TopCard(
                  title: "Güncel Toplam Borç",
                  value: _fmtMoney(bank.totalDebt),
                  tint: const Color(0xFF4F46E5),
                ),
                const SizedBox(width: 10),
                _TopCard(
                  title: "Faiz Oranı",
                  value: "%${bank.interestRate} (${bank.interestType == "Daily" ? "Günlük" : "Aylık"})",
                  tint: const Color(0xFF64748B),
                ),
                const SizedBox(width: 10),
                _TopCard(
                  title: "Planlanan Vade",
                  value: "${projection.length} Ay",
                  tint: const Color(0xFFE11D48),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.03),
                        border: Border(
                          bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.calendar_month, color: Color(0xFF4F46E5)),
                          SizedBox(width: 8),
                          Text("Dinamik Ödeme Takvimi",
                              style: TextStyle(fontWeight: FontWeight.w900)),
                          Spacer(),
                          Text("Düzenlemek için kaleme tıkla",
                              style: TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView.separated(
                        itemCount: projection.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.black.withOpacity(0.06),
                        ),
                        itemBuilder: (_, i) {
                          final row = projection[i];
                          final isPaid = bank.paidMonths.contains(row.monthKey);

                          return Container(
                            color: isPaid ? Colors.green.withOpacity(0.04) : null,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 62,
                                  child: Text("${i + 1}. Ay",
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _monthLabel(row.date),
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(_fmtMoney(row.startingDebt),
                                        style: const TextStyle(fontSize: 11)),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(_fmtMoney(row.interest),
                                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: InkWell(
                                      onTap: isPaid
                                          ? null
                                          : () => _editCustomPayment(bank, row.monthKey, row.payment),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            _fmtMoney(row.payment),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: row.isCustom
                                                  ? const Color(0xFF4F46E5)
                                                  : const Color(0xFFE11D48),
                                            ),
                                          ),
                                          if (!isPaid) ...[
                                            const SizedBox(width: 6),
                                            Icon(Icons.edit, size: 16, color: Colors.black.withOpacity(0.45)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(_fmtMoney(row.remainingDebt),
                                        style: const TextStyle(fontWeight: FontWeight.w900)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 100,
                                  child: isPaid
                                      ? const Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.green, size: 18),
                                            SizedBox(width: 6),
                                            Text("Ödendi",
                                                style: TextStyle(
                                                    color: Colors.green, fontWeight: FontWeight.w800)),
                                          ],
                                        )
                                      : ElevatedButton(
                                          onPressed: () => _markPaid(bank, row.date, row.payment),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.green,
                                            elevation: 0,
                                            side: BorderSide(color: Colors.green.withOpacity(0.35)),
                                          ),
                                          child: const Text("Ödeme Yap"),
                                        ),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectionRow {
  final int index;
  final DateTime date;
  final String monthKey;
  final double startingDebt;
  final double interest;
  final double payment;
  final double remainingDebt;
  final bool isCustom;
  final bool hasWarning;

  _ProjectionRow({
    required this.index,
    required this.date,
    required this.monthKey,
    required this.startingDebt,
    required this.interest,
    required this.payment,
    required this.remainingDebt,
    required this.isCustom,
    required this.hasWarning,
  });
}

class _TopCard extends StatelessWidget {
  final String title;
  final String value;
  final Color tint;

  const _TopCard({
    required this.title,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tint.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.black.withOpacity(0.60),
              ),
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
