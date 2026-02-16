import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseService _service = ExpenseService();

  late int selectedMonth;
  late int selectedYear;

  // ✅ Otomatik ay seçimi mi, manuel mi?
  bool _autoMonthSelected = true;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    // Ayın 6'sı ve sonrası => filtre otomatik bir sonraki ay
    if (now.day >= 6) {
      if (now.month == 12) {
        selectedMonth = 1;
        selectedYear = now.year + 1;
      } else {
        selectedMonth = now.month + 1;
        selectedYear = now.year;
      }
    } else {
      selectedMonth = now.month;
      selectedYear = now.year;
    }

    _autoMonthSelected = true;
  }

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

  String _monthLabel(int m) =>
      months.firstWhere((x) => x["value"] == m)["label"] as String;

  List<int> _years() {
    final now = DateTime.now().year;
    return List.generate(7, (i) => now + i);
  }

  // Replit mantığı: gün >= 6 ise bir sonraki aya say
  bool _belongsToSelectedPeriod(DateTime date) {
    if (date.day >= 6) {
      final nextMonth = DateTime(date.year, date.month + 1, date.day);
      return nextMonth.month == selectedMonth && nextMonth.year == selectedYear;
    }
    return date.month == selectedMonth && date.year == selectedYear;
  }

  List<Expense> get _filteredExpenses {
    final all = _service.getAll();
    final list = all.where((e) => _belongsToSelectedPeriod(e.date)).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  double get _totalPlanned =>
      _filteredExpenses.fold(0, (sum, e) => sum + e.amount);

  double get _paidTotal =>
      _filteredExpenses.where((e) => e.isPaid).fold(0, (s, e) => s + e.amount);

  int get _progressPercent {
    final total = _totalPlanned;
    if (total <= 0) return 0;
    return ((_paidTotal / total) * 100).round();
  }

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')} ${_monthLabel(d.month)} ${d.year}";

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

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // --- yardımcı: tekrarlı satırlar üret ---
  List<DateTime> _generateDates({
    required DateTime start,
    required DateTime end,
    required String frequency, // weekly/monthly
  }) {
    final dates = <DateTime>[];
    DateTime cur = DateTime(start.year, start.month, start.day);

    while (!cur.isAfter(end)) {
      dates.add(cur);
      if (frequency == "weekly") {
        cur = cur.add(const Duration(days: 7));
      } else {
        cur = DateTime(cur.year, cur.month + 1, cur.day);
      }
    }
    return dates;
  }

  Future<void> _openAddEditDialog({Expense? edit}) async {
    // ✅ Seri düzenleme mi?
    List<Expense> seriesItems = [];
    final isSeriesEdit = (edit != null && (edit.seriesId ?? "").isNotEmpty);

    if (isSeriesEdit) {
      seriesItems = _service.getBySeriesId(edit!.seriesId!);

      // ✅ OTOMATİK AY SEÇİMİNDE: geçmiş ayları gizle
      if (_autoMonthSelected) {
        final startOfSelected = DateTime(selectedYear, selectedMonth, 1);
        seriesItems = seriesItems
            .where((x) => !x.date.isBefore(startOfSelected))
            .toList();

        seriesItems.sort((a, b) =>
            (a.occurrenceIndex ?? 0).compareTo(b.occurrenceIndex ?? 0));
      }
    }

    final nameCtrl = TextEditingController(
      text:
          edit?.name ?? (seriesItems.isNotEmpty ? seriesItems.first.name : ""),
    );
    final typeCtrl = TextEditingController(
      text:
          edit?.type ?? (seriesItems.isNotEmpty ? seriesItems.first.type : ""),
    );

    final amountCtrl = TextEditingController(
      text: edit != null
          ? edit.amount.toString()
          : (seriesItems.isNotEmpty ? seriesItems.first.amount.toString() : ""),
    );

    DateTime selectedDate = edit?.date ??
        (seriesItems.isNotEmpty ? seriesItems.first.date : DateTime.now());
    bool recurring = edit?.recurring ??
        (seriesItems.isNotEmpty ? seriesItems.first.recurring : false);
    String frequency = edit?.frequency ??
        (seriesItems.isNotEmpty ? seriesItems.first.frequency : "monthly");
    DateTime? endDate = edit?.endDate ??
        (seriesItems.isNotEmpty ? seriesItems.first.endDate : null);

    // Tekrarlı önizleme satırları (tarih + tutar)
    List<DateTime> previewDates = [];
    List<TextEditingController> previewAmountCtrls = [];

    bool syncAllAmounts = true;

    void disposePreviewCtrls() {
      for (final c in previewAmountCtrls) {
        c.dispose();
      }
      previewAmountCtrls = [];
    }

    void rebuildPreview() {
      if (!recurring || endDate == null) {
        previewDates = [];
        disposePreviewCtrls();
        return;
      }

      // ✅ Seri düzenlemede: planı mevcut kayıtların içinden kur
      if (isSeriesEdit && seriesItems.isNotEmpty) {
        previewDates = seriesItems.map((e) => e.date).toList();
        disposePreviewCtrls();
        previewAmountCtrls = List.generate(
          seriesItems.length,
          (i) => TextEditingController(text: seriesItems[i].amount.toString()),
        );
        return;
      }

      // ✅ Yeni seri eklerken: otomatik üret
      previewDates = _generateDates(
          start: selectedDate, end: endDate!, frequency: frequency);
      disposePreviewCtrls();
      previewAmountCtrls = previewDates
          .map((_) => TextEditingController(text: amountCtrl.text))
          .toList();
    }

    // amount değişince (sync açıkken) tüm satırlara uygula
    void amountListener() {
      if (!syncAllAmounts) return;
      if (previewAmountCtrls.isEmpty) return;
      for (final c in previewAmountCtrls) {
        c.text = amountCtrl.text;
      }
    }

    amountCtrl.addListener(amountListener);
    rebuildPreview();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: dialogCtx,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setDialogState(() {
                  selectedDate = picked;
                  rebuildPreview();
                });
              }
            }

            Future<void> pickEndDate() async {
              final picked = await showDatePicker(
                context: dialogCtx,
                initialDate: endDate ?? selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setDialogState(() {
                  endDate = picked;
                  rebuildPreview();
                });
              }
            }

            Future<void> pickPreviewDate(int index) async {
              final picked = await showDatePicker(
                context: dialogCtx,
                initialDate: previewDates[index],
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setDialogState(() {
                  previewDates[index] = picked;
                });
              }
            }

            Widget roundedField({
              required TextEditingController controller,
              required String label,
              TextInputType? keyboardType,
            }) {
              return TextField(
                controller: controller,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  labelText: label,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.black.withOpacity(0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.black.withOpacity(0.10)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.4,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              );
            }

            Widget chipLikeButton({
              required VoidCallback onTap,
              required IconData icon,
              required String text,
            }) {
              return InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.10)),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(text)),
                      const Icon(Icons.expand_more, size: 18),
                    ],
                  ),
                ),
              );
            }

            Future<void> onSave() async {
              final name = nameCtrl.text.trim();
              final type = typeCtrl.text.trim();
              final defaultAmount =
                  double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;

              if (name.isEmpty) {
                _toast("Lütfen gider ismi gir.");
                return;
              }
              if (defaultAmount <= 0) {
                _toast("Lütfen geçerli bir tutar gir.");
                return;
              }
              if (recurring && endDate == null) {
                _toast("Tekrarlı gider için bitiş tarihi seçmelisin.");
                return;
              }

              // ✅ SERİ DÜZENLEME
              if (isSeriesEdit && seriesItems.isNotEmpty) {
                for (int i = 0; i < seriesItems.length; i++) {
                  final newAmount = double.tryParse(
                          previewAmountCtrls[i].text.replaceAll(',', '.')) ??
                      seriesItems[i].amount;

                  seriesItems[i].name = name;
                  seriesItems[i].type = type.isEmpty ? "-" : type;
                  seriesItems[i].amount = newAmount;
                  seriesItems[i].date = previewDates[i];
                  seriesItems[i].recurring = true;
                  seriesItems[i].frequency = frequency;
                  seriesItems[i].endDate = endDate;
                }

                await _service.updateMany(seriesItems);

                if (mounted) Navigator.pop(dialogCtx);
                setState(() {});
                return;
              }

              // ✅ TEK KAYIT DÜZENLEME (serisiz)
              if (edit != null) {
                edit.name = name;
                edit.type = type.isEmpty ? "-" : type;
                edit.amount = defaultAmount;
                edit.date = selectedDate;
                edit.recurring = recurring;
                edit.frequency = frequency;
                edit.endDate = endDate;

                await _service.update(edit);

                if (mounted) Navigator.pop(dialogCtx);
                setState(() {});
                return;
              }

              // ✅ YENİ KAYIT
              if (recurring && endDate != null && previewDates.isNotEmpty) {
                final seriesId =
                    DateTime.now().millisecondsSinceEpoch.toString();

                for (int i = 0; i < previewDates.length; i++) {
                  final a = double.tryParse(
                          previewAmountCtrls[i].text.replaceAll(',', '.')) ??
                      defaultAmount;

                  final expense = Expense(
                    id: "${DateTime.now().millisecondsSinceEpoch}-$i",
                    name: name,
                    type: type.isEmpty ? "-" : type,
                    amount: a,
                    date: previewDates[i],
                    isPaid: false,
                    recurring: true,
                    frequency: frequency,
                    endDate: endDate,
                    seriesId: seriesId,
                    occurrenceIndex: i,
                  );
                  await _service.add(expense);
                }
              } else {
                final expense = Expense(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  type: type.isEmpty ? "-" : type,
                  amount: defaultAmount,
                  date: selectedDate,
                  isPaid: false,
                  recurring: false,
                  frequency: frequency,
                  endDate: endDate,
                  seriesId: null,
                  occurrenceIndex: null,
                );
                await _service.add(expense);
              }

              if (mounted) Navigator.pop(dialogCtx);
              setState(() {});
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          edit == null ? "Gider Ekle" : "Gideri Düzenle",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Detayları gir ve kaydet.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withOpacity(0.55),
                          ),
                        ),
                        const SizedBox(height: 14),
                        roundedField(controller: nameCtrl, label: "Gider İsmi"),
                        const SizedBox(height: 10),
                        roundedField(controller: typeCtrl, label: "Tür"),
                        const SizedBox(height: 10),
                        roundedField(
                          controller: amountCtrl,
                          label: "Varsayılan Tutar",
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                        const SizedBox(height: 10),
                        chipLikeButton(
                          onTap: pickDate,
                          icon: Icons.calendar_month,
                          text: "Başlangıç: ${_fmtDate(selectedDate)}",
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Tekrarlı mı?"),
                          value: recurring,
                          onChanged: (v) {
                            setDialogState(() {
                              recurring = v;
                              rebuildPreview();
                            });
                          },
                        ),
                        if (recurring) ...[
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: frequency,
                            decoration: InputDecoration(
                              labelText: "Sıklık",
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: "weekly", child: Text("Haftalık")),
                              DropdownMenuItem(
                                  value: "monthly", child: Text("Aylık")),
                            ],
                            onChanged: (v) {
                              setDialogState(() {
                                frequency = v ?? "monthly";
                                rebuildPreview();
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: chipLikeButton(
                                  onTap: pickEndDate,
                                  icon: Icons.event,
                                  text: endDate == null
                                      ? "Bitiş Tarihi Seç"
                                      : "Bitiş: ${_fmtDate(endDate!)}",
                                ),
                              ),
                              if (endDate != null) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () {
                                    setDialogState(() {
                                      endDate = null;
                                      rebuildPreview();
                                    });
                                  },
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: "Bitişi temizle",
                                ),
                              ],
                            ],
                          ),
                          if (endDate != null && previewDates.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Tekrar Planı (Tarih / Tutar)",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black.withOpacity(0.75),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Text("Hepsine uygula",
                                        style: TextStyle(fontSize: 12)),
                                    Switch(
                                      value: syncAllAmounts,
                                      onChanged: (v) {
                                        setDialogState(() {
                                          syncAllAmounts = v;
                                          if (syncAllAmounts) {
                                            for (final c
                                                in previewAmountCtrls) {
                                              c.text = amountCtrl.text;
                                            }
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.black.withOpacity(0.08)),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: previewDates.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Colors.black.withOpacity(0.06),
                                ),
                                itemBuilder: (_, i) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: InkWell(
                                            onTap: () => pickPreviewDate(i),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.black
                                                      .withOpacity(0.10),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .calendar_month_outlined,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _fmtDate(previewDates[i]),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          flex: 2,
                                          child: TextField(
                                            controller: previewAmountCtrls[i],
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            decoration: InputDecoration(
                                              labelText: "Tutar",
                                              isDense: true,
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: const Text("İptal"),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: onSave,
                              icon: const Icon(Icons.save),
                              label: Text(edit == null ? "Kaydet" : "Güncelle"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // dialog kapandıktan sonra temizle
    amountCtrl.removeListener(amountListener);
    nameCtrl.dispose();
    typeCtrl.dispose();
    amountCtrl.dispose();
    for (final c in previewAmountCtrls) {
      c.dispose();
    }
  }

  Future<void> _confirmDelete(Expense expense) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Silinsin mi?"),
        content: Text("${expense.name} kaydı silinecek."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _service.delete(expense);
      setState(() {});
    }
  }

  Widget _statCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color tint,
  }) {
    return Container(
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
    );
  }

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

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
              width: 52, child: Text("Durum", style: TextStyle(fontSize: 12))),
          Expanded(
              flex: 3, child: Text("Gider", style: TextStyle(fontSize: 12))),
          Expanded(
              flex: 2, child: Text("Tarih", style: TextStyle(fontSize: 12))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text("Tutar", style: TextStyle(fontSize: 12)),
            ),
          ),
          SizedBox(width: 76),
        ],
      ),
    );
  }

  Widget _rowItem(Expense expense) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Checkbox(
              value: expense.isPaid,
              onChanged: (v) async {
                expense.isPaid = v ?? false;
                await _service.update(expense);
                setState(() {});
              },
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              expense.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(_fmtDate(expense.date)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _fmtMoney(expense.amount),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          SizedBox(
            width: 76,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: "Düzenle",
                  onPressed: () => _openAddEditDialog(edit: expense),
                  icon: const Icon(Icons.edit, size: 18),
                ),
                IconButton(
                  tooltip: "Sil",
                  onPressed: () => _confirmDelete(expense),
                  icon:
                      Icon(Icons.delete, size: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileRowItem(Expense expense) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Checkbox(
        value: expense.isPaid,
        onChanged: (v) async {
          expense.isPaid = v ?? false;
          await _service.update(expense);
          setState(() {});
        },
      ),
      title: Text(
        expense.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(_fmtDate(expense.date)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _fmtMoney(expense.amount),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          IconButton(
            tooltip: "Düzenle",
            onPressed: () => _openAddEditDialog(edit: expense),
            icon: const Icon(Icons.edit, size: 18),
          ),
          IconButton(
            tooltip: "Sil",
            onPressed: () => _confirmDelete(expense),
            icon: Icon(Icons.delete, size: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredExpenses;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = MediaQuery.sizeOf(context).shortestSide < 600;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (isCompact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Giderler",
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Aylık gider özeti",
                          style:
                              TextStyle(color: Colors.black.withOpacity(0.55)),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _smallFilter<int>(
                              label: "Ay",
                              value: selectedMonth,
                              items: months
                                  .map((m) => DropdownMenuItem<int>(
                                        value: m["value"] as int,
                                        child: Text(m["label"] as String),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                selectedMonth = v ?? selectedMonth;
                                _autoMonthSelected = false;
                              }),
                            ),
                            _smallFilter<int>(
                              label: "Yıl",
                              value: selectedYear,
                              items: _years()
                                  .map((y) => DropdownMenuItem<int>(
                                        value: y,
                                        child: Text("$y"),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                selectedYear = v ?? selectedYear;
                                _autoMonthSelected = false;
                              }),
                            ),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: () => _openAddEditDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text("Gider Ekle"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Giderler",
                                style: TextStyle(
                                    fontSize: 26, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Aylık gider özeti",
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
                          onChanged: (v) => setState(() {
                            selectedMonth = v ?? selectedMonth;
                            _autoMonthSelected = false;
                          }),
                        ),
                        const SizedBox(width: 10),
                        _smallFilter<int>(
                          label: "Yıl",
                          value: selectedYear,
                          items: _years()
                              .map((y) => DropdownMenuItem<int>(
                                  value: y, child: Text("$y")))
                              .toList(),
                          onChanged: (v) => setState(() {
                            selectedYear = v ?? selectedYear;
                            _autoMonthSelected = false;
                          }),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () => _openAddEditDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text("Gider Ekle"),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (isCompact)
                    Column(
                      children: [
                        _statCard(
                          title: "Planlanan",
                          value: _fmtMoney(_totalPlanned),
                          subtitle: "Seçili dönem",
                          icon: Icons.trending_down,
                          tint: const Color(0xFFE11D48),
                        ),
                        const SizedBox(height: 10),
                        _statCard(
                          title: "Ödenen",
                          value: _fmtMoney(_paidTotal),
                          subtitle: "İşaretli ödemeler",
                          icon: Icons.credit_card,
                          tint: const Color(0xFF0F766E),
                        ),
                        const SizedBox(height: 10),
                        _statCard(
                          title: "Durum",
                          value: "%$_progressPercent",
                          subtitle: "Tutar bazlı ilerleme",
                          icon: Icons.calendar_month,
                          tint: const Color(0xFF4F46E5),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            title: "Planlanan",
                            value: _fmtMoney(_totalPlanned),
                            subtitle: "Seçili dönem",
                            icon: Icons.trending_down,
                            tint: const Color(0xFFE11D48),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            title: "Ödenen",
                            value: _fmtMoney(_paidTotal),
                            subtitle: "İşaretli ödemeler",
                            icon: Icons.credit_card,
                            tint: const Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            title: "Durum",
                            value: "%$_progressPercent",
                            subtitle: "Tutar bazlı ilerleme",
                            icon: Icons.calendar_month,
                            tint: const Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: Colors.black.withOpacity(0.06)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                    color: Colors.black.withOpacity(0.08)),
                              ),
                            ),
                            child: Text(
                              "Gider Kayıtları – ${_monthLabel(selectedMonth)} $selectedYear",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (!isCompact) _tableHeader(),
                          Expanded(
                            child: filtered.isEmpty
                                ? const Center(
                                    child: Text("Bu dönemde gider yok"))
                                : ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (_, i) => isCompact
                                        ? _mobileRowItem(filtered[i])
                                        : _rowItem(filtered[i]),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
