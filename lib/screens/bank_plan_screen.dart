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
  static const String _rulePrefix = "__rule__";

  String _monthKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}";
  String _ruleKey(String monthKey) => "$_rulePrefix$monthKey";
  bool _isRuleKey(String key) => key.startsWith(_rulePrefix);

  String _monthLabel(DateTime d) {
    const months = [
      "Ocak",
      "Şubat",
      "Mart",
      "Nisan",
      "Mayıs",
      "Haziran",
      "Temmuz",
      "Ağustos",
      "Eylül",
      "Ekim",
      "Kasım",
      "Aralık"
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

  double _defaultPayment(BankDebt bank, double currentDebt) {
    if (bank.minPaymentType == "percentage") {
      return (currentDebt * bank.minPaymentAmount) / 100.0;
    }
    return bank.minPaymentAmount;
  }

  List<_PaymentRule> _rules(BankDebt bank) {
    final items = <_PaymentRule>[];
    bank.customPayments.forEach((key, value) {
      if (!_isRuleKey(key)) return;
      final monthKey = key.replaceFirst(_rulePrefix, "");
      final raw = value.trim();
      if (raw.isEmpty || !raw.contains(":")) return;
      final parts = raw.split(":");
      if (parts.length != 2) return;
      final type = parts.first;
      final parsed = double.tryParse(parts.last.replaceAll(',', '.'));
      if (parsed == null || parsed <= 0) return;
      if (type != "amount" && type != "percentage") return;
      items.add(_PaymentRule(monthKey: monthKey, type: type, value: parsed));
    });
    items.sort((a, b) => a.monthKey.compareTo(b.monthKey));
    return items;
  }

  _PaymentRule? _activeRuleForMonth(List<_PaymentRule> rules, String monthKey) {
    _PaymentRule? active;
    for (final r in rules) {
      if (r.monthKey.compareTo(monthKey) <= 0) {
        active = r;
      }
    }
    return active;
  }

  double _paymentFromRule(_PaymentRule rule, double currentDebt) {
    if (rule.type == "percentage") {
      return (currentDebt * rule.value) / 100.0;
    }
    return rule.value;
  }

  List<_ProjectionRow> _buildProjection(BankDebt bank) {
    final results = <_ProjectionRow>[];
    double currentDebt = bank.totalDebt;
    final rules = _rules(bank);

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

      double payment = _defaultPayment(bank, currentDebt);
      final rule = _activeRuleForMonth(rules, key);
      if (rule != null) {
        payment = _paymentFromRule(rule, currentDebt);
      }

      // Bu aya özel manuel tutar varsa her şeyi override eder.
      final String? customStr = bank.customPayments[key];
      final bool hasMonthCustom =
          customStr != null && customStr.trim().isNotEmpty;
      if (hasMonthCustom) {
        payment = double.tryParse(customStr!.replaceAll(',', '.')) ?? payment;
      }
      final bool isCustom = hasMonthCustom || rule != null;

      // Replit warning: payment <= interest ve 24. ayda kes
      if (payment <= interest && currentDebt > 0) {
        if (monthOffset >= 23) {
          warning = true;
          break;
        }
      }

      // ödeme borç + faizden fazla olamaz
      final double actualPayment = payment > (currentDebt + interest)
          ? (currentDebt + interest)
          : payment;

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
    final rules = _rules(bank);

    while (currentDebt > 0.01 && monthOffset < 60) {
      final date = _addMonths(DateTime.now(), monthOffset);
      final key = _monthKey(date);

      // ✅ doğru faiz hesabı
      final interest = _calcInterestForMonth(
        currentDebt: currentDebt,
        monthlyPercentRate: bank.interestRate,
        interestType: bank.interestType,
      );

      double payment = _defaultPayment(bank, currentDebt);
      final rule = _activeRuleForMonth(rules, key);
      if (rule != null) {
        payment = _paymentFromRule(rule, currentDebt);
      }
      final custom = bank.customPayments[key];
      if (custom != null && custom.trim().isNotEmpty) {
        payment = double.tryParse(custom.replaceAll(',', '.')) ?? payment;
      }

      if (payment <= interest && currentDebt > 0) {
        if (monthOffset >= 23) return true;
      }

      final actualPayment = payment > (currentDebt + interest)
          ? (currentDebt + interest)
          : payment;

      currentDebt =
          (currentDebt + interest - actualPayment).clamp(0.0, double.infinity);

      monthOffset++;
    }

    return false;
  }

  Future<void> _editPaymentPlan(
      BankDebt bank, String monthKey, double currentPayment) async {
    final ruleRaw = bank.customPayments[_ruleKey(monthKey)];
    bool applyForward = false;
    String forwardType = "amount";
    if (ruleRaw != null && ruleRaw.startsWith("amount:")) {
      applyForward = true;
      forwardType = "amount";
    } else if (ruleRaw != null && ruleRaw.startsWith("percentage:")) {
      applyForward = true;
      forwardType = "percentage";
    }

    String initialText = bank.customPayments[monthKey]?.trim() ??
        currentPayment.toStringAsFixed(2);
    if (ruleRaw != null && ruleRaw.contains(":")) {
      initialText = ruleRaw.split(":").last.trim();
    }
    final ctrl = TextEditingController(text: initialText);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text("Ödeme Planını Düzenle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: (applyForward && forwardType == "percentage")
                        ? "Yüzde (%)"
                        : "Tutar",
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: applyForward,
                  title:
                      const Text("Bu aydan itibaren sonraki aylara da uygula"),
                  subtitle: const Text(
                      "İşaretlersen bu ay ve sonrası otomatik güncellenir."),
                  onChanged: (v) => setD(() => applyForward = v ?? false),
                ),
                if (applyForward) ...[
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: "amount",
                        label: Text("Sabit Tutar"),
                      ),
                      ButtonSegment<String>(
                        value: "percentage",
                        label: Text("Yüzde"),
                      ),
                    ],
                    selected: {forwardType},
                    onSelectionChanged: (v) {
                      setD(() => forwardType = v.first);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("İptal"),
            ),
            if (bank.customPayments.containsKey(monthKey) ||
                bank.customPayments.containsKey(_ruleKey(monthKey)))
              TextButton(
                onPressed: () => Navigator.pop(ctx, "clear"),
                child: const Text("Bu Ay Kuralını Temizle"),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, "save"),
              child: const Text("Kaydet"),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    if (result == "clear") {
      bank.customPayments.remove(monthKey);
      bank.customPayments.remove(_ruleKey(monthKey));
      await _service.update(bank);
      setState(() {});
      _toast("Bu ay için özel plan temizlendi.");
      return;
    }

    final parsed = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      _toast("Geçerli bir değer gir.");
      return;
    }

    if (!applyForward) {
      bank.customPayments[monthKey] = parsed.toStringAsFixed(2);
      bank.customPayments.remove(_ruleKey(monthKey));
    } else if (forwardType == "amount") {
      bank.customPayments[_ruleKey(monthKey)] =
          "amount:${parsed.toStringAsFixed(2)}";
      bank.customPayments.remove(monthKey);
    } else {
      bank.customPayments[_ruleKey(monthKey)] =
          "percentage:${parsed.toStringAsFixed(2)}";
      bank.customPayments.remove(monthKey);
    }

    await _service.update(bank);
    setState(() {});
    _toast("Ödeme planı güncellendi");
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

  Widget _mobileProjectionItem(
      BankDebt bank, _ProjectionRow row, bool isPaid, int index) {
    return Container(
      color: isPaid ? Colors.green.withOpacity(0.04) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("${index + 1}. Ay",
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _monthLabel(row.date),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              if (isPaid)
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text("Ödendi",
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.w800)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text("Borç: ${_fmtMoney(row.startingDebt)}",
                  style: const TextStyle(fontSize: 12)),
              Text("Faiz: ${_fmtMoney(row.interest)}",
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text("Kalan: ${_fmtMoney(row.remainingDebt)}",
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _fmtMoney(row.payment),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: row.isCustom
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFFE11D48),
                  ),
                ),
              ),
              if (!isPaid)
                OutlinedButton.icon(
                  onPressed: () =>
                      _editPaymentPlan(bank, row.monthKey, row.payment),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text("Düzenle"),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isPaid)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
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
    final isCompact = MediaQuery.sizeOf(context).shortestSide < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: Text("${bank.name} - Ödeme Planı")),
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
                        style: TextStyle(
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            if (isCompact)
              Column(
                children: [
                  _TopCard(
                    title: "Güncel Toplam Borç",
                    value: _fmtMoney(bank.totalDebt),
                    tint: const Color(0xFF4F46E5),
                  ),
                  const SizedBox(height: 10),
                  _TopCard(
                    title: "Faiz Oranı",
                    value:
                        "%${bank.interestRate} (${bank.interestType == "Daily" ? "Günlük" : "Aylık"})",
                    tint: const Color(0xFF64748B),
                  ),
                  const SizedBox(height: 10),
                  _TopCard(
                    title: "Planlanan Vade",
                    value: "${projection.length} Ay",
                    tint: const Color(0xFFE11D48),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _TopCard(
                      title: "Güncel Toplam Borç",
                      value: _fmtMoney(bank.totalDebt),
                      tint: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TopCard(
                      title: "Faiz Oranı",
                      value:
                          "%${bank.interestRate} (${bank.interestType == "Daily" ? "Günlük" : "Aylık"})",
                      tint: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TopCard(
                      title: "Planlanan Vade",
                      value: "${projection.length} Ay",
                      tint: const Color(0xFFE11D48),
                    ),
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
                          bottom:
                              BorderSide(color: Colors.black.withOpacity(0.08)),
                        ),
                      ),
                      child: isCompact
                          ? const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.calendar_month,
                                        color: Color(0xFF4F46E5)),
                                    SizedBox(width: 8),
                                    Text("Dinamik Ödeme Takvimi",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900)),
                                  ],
                                ),
                                SizedBox(height: 6),
                                Text("Düzenlemek için Düzenle butonuna bas",
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.black54)),
                              ],
                            )
                          : const Row(
                              children: [
                                Icon(Icons.calendar_month,
                                    color: Color(0xFF4F46E5)),
                                SizedBox(width: 8),
                                Text("Dinamik Ödeme Takvimi",
                                    style:
                                        TextStyle(fontWeight: FontWeight.w900)),
                                Spacer(),
                                Text("Düzenlemek için kaleme tıkla",
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.black54)),
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

                          if (isCompact) {
                            return _mobileProjectionItem(bank, row, isPaid, i);
                          }

                          return Container(
                            color:
                                isPaid ? Colors.green.withOpacity(0.04) : null,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 62,
                                  child: Text("${i + 1}. Ay",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _monthLabel(row.date),
                                    style:
                                        const TextStyle(color: Colors.black54),
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
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54)),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: InkWell(
                                      onTap: isPaid
                                          ? null
                                          : () => _editPaymentPlan(
                                              bank, row.monthKey, row.payment),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
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
                                            Icon(Icons.edit,
                                                size: 16,
                                                color: Colors.black
                                                    .withOpacity(0.45)),
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
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 100,
                                  child: isPaid
                                      ? const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Icon(Icons.check_circle,
                                                color: Colors.green, size: 18),
                                            SizedBox(width: 6),
                                            Text("Ödendi",
                                                style: TextStyle(
                                                    color: Colors.green,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                          ],
                                        )
                                      : ElevatedButton(
                                          onPressed: () => _markPaid(
                                              bank, row.date, row.payment),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.green,
                                            elevation: 0,
                                            side: BorderSide(
                                                color: Colors.green
                                                    .withOpacity(0.35)),
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

class _PaymentRule {
  final String monthKey;
  final String type; // amount | percentage
  final double value;

  const _PaymentRule({
    required this.monthKey,
    required this.type,
    required this.value,
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
    return Container(
      constraints: const BoxConstraints(minHeight: 124),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.black.withOpacity(0.60),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
