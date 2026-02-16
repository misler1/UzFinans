import 'package:flutter/material.dart';
import '../models/bank_debt.dart';
import '../services/bank_debt_service.dart';
import 'bank_plan_screen.dart';

class BanksScreen extends StatefulWidget {
  const BanksScreen({super.key});

  @override
  State<BanksScreen> createState() => _BanksScreenState();
}

class _BanksScreenState extends State<BanksScreen> {
  final BankDebtService _service = BankDebtService();

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

  Future<void> _openExtraPaymentDialog(List<BankDebt> banks) async {
    String? selectedId;
    final amountCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ara Ödeme Yap"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedId,
              decoration: const InputDecoration(
                labelText: "Banka seç",
                border: OutlineInputBorder(),
              ),
              items: banks
                  .map(
                    (b) => DropdownMenuItem(
                      value: b.id,
                      child:
                          Text("${b.name} (Kalan: ${_fmtMoney(b.totalDebt)})"),
                    ),
                  )
                  .toList(),
              onChanged: (v) => selectedId = v,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Ödeme Tutarı",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              final a =
                  double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
              if (selectedId == null) {
                _toast("Banka seç.");
                return;
              }
              if (a <= 0) {
                _toast("Geçerli tutar gir.");
                return;
              }

              final bank = _service.getById(selectedId!);
              if (bank == null) return;

              bank.totalDebt = (bank.totalDebt - a).clamp(0, double.infinity);
              bank.extraPaidTotal += a;

              await _service.update(bank);

              if (mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text("Ödemeyi Kaydet"),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddEditDialog({BankDebt? edit}) async {
    final nameCtrl = TextEditingController(text: edit?.name ?? "");
    String debtType = edit?.debtType ?? "Credit Card";
    final totalCtrl = TextEditingController(
        text: edit != null ? edit.totalDebt.toString() : "");
    String minType = edit?.minPaymentType ?? "amount";
    final minCtrl = TextEditingController(
        text: edit != null ? edit.minPaymentAmount.toString() : "");
    final rateCtrl = TextEditingController(
        text: edit != null ? edit.interestRate.toString() : "");
    String interestType = edit?.interestType ?? "Monthly";
    final dueDayCtrl = TextEditingController(
        text: edit != null ? edit.paymentDueDay.toString() : "5");
    bool isActive = edit?.isActive ?? true;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        edit == null
                            ? "Banka / Borç Ekle"
                            : "Banka / Borç Düzenle",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: "Banka Adı",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: debtType,
                        decoration: const InputDecoration(
                          labelText: "Tür",
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: "Credit Card", child: Text("Kredi Kartı")),
                          DropdownMenuItem(value: "KMH", child: Text("KMH")),
                          DropdownMenuItem(
                              value: "Overdraft",
                              child: Text("Kredili Mevduat")),
                          DropdownMenuItem(
                              value: "Flexible Account",
                              child: Text("Esnek Hesap")),
                        ],
                        onChanged: (v) =>
                            setD(() => debtType = v ?? "Credit Card"),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: totalCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: "Toplam Borç",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: minCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: "Minimum Aylık Ödeme",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 120,
                            child: DropdownButtonFormField<String>(
                              value: minType,
                              decoration: const InputDecoration(
                                labelText: "Tip",
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: "amount", child: Text("₺")),
                                DropdownMenuItem(
                                    value: "percentage", child: Text("%")),
                              ],
                              onChanged: (v) =>
                                  setD(() => minType = v ?? "amount"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: "Faiz Oranı (%)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: interestType,
                        decoration: const InputDecoration(
                          labelText: "Faiz Dönemi",
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: "Daily", child: Text("Günlük")),
                          DropdownMenuItem(
                              value: "Monthly", child: Text("Aylık")),
                        ],
                        onChanged: (v) =>
                            setD(() => interestType = v ?? "Monthly"),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: dueDayCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Ödeme Günü (Ayın Kaçı?)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Aktif Durum"),
                        value: isActive,
                        onChanged: (v) => setD(() => isActive = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("İptal")),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () async {
                              if (isSaving) return;
                              setD(() => isSaving = true);
                              final name = nameCtrl.text.trim();
                              final total = double.tryParse(
                                      totalCtrl.text.replaceAll(',', '.')) ??
                                  0;
                              final min = double.tryParse(
                                      minCtrl.text.replaceAll(',', '.')) ??
                                  0;
                              final rate = double.tryParse(
                                      rateCtrl.text.replaceAll(',', '.')) ??
                                  0;
                              final due = int.tryParse(dueDayCtrl.text) ?? 5;

                              if (name.isEmpty || total <= 0 || min <= 0) {
                                _toast("Zorunlu alanları doldur.");
                                if (ctx.mounted) {
                                  setD(() => isSaving = false);
                                }
                                return;
                              }

                              try {
                                if (edit == null) {
                                  final d = BankDebt(
                                    id: DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString(),
                                    name: name,
                                    debtType: debtType,
                                    totalDebt: total,
                                    interestRate: rate,
                                    interestType: interestType,
                                    minPaymentType: minType,
                                    minPaymentAmount: min,
                                    paymentDueDay: due.clamp(1, 31),
                                    isActive: isActive,
                                  );
                                  await _service.add(d);
                                } else {
                                  edit.name = name;
                                  edit.debtType = debtType;
                                  edit.totalDebt = total;
                                  edit.interestRate = rate;
                                  edit.interestType = interestType;
                                  edit.minPaymentType = minType;
                                  edit.minPaymentAmount = min;
                                  edit.paymentDueDay = due.clamp(1, 31);
                                  edit.isActive = isActive;
                                  await _service.update(edit);
                                }

                                if (mounted) Navigator.pop(ctx);
                                setState(() {});
                              } catch (_) {
                                _toast("Kaydetme sırasında hata oluştu.");
                              } finally {
                                if (ctx.mounted) {
                                  setD(() => isSaving = false);
                                }
                              }
                            },
                            child: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(edit == null
                                    ? "Bankayı Kaydet"
                                    : "Güncelle"),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BankDebt d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${d.name} silinsin mi?"),
        content:
            const Text("Bu işlem bankayı ve tüm ödeme geçmişini kaldırır."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("İptal")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Sil")),
        ],
      ),
    );
    if (ok == true) {
      await _service.delete(d);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final banks = _service.getAll();
    banks
        .sort((a, b) => b.isActive.toString().compareTo(a.isActive.toString()));

    final totalMin = _service.totalMinPaymentForCurrentMonth();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = MediaQuery.sizeOf(context).shortestSide < 600;
            final crossAxisCount = isCompact ? 1 : 2;
            final childAspectRatio = isCompact ? 1.36 : 1.55;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header
                  if (isCompact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Bankalar & Borçlar",
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        const Text(
                            "Kredi kartları, krediler ve ödemeleri yönetin.",
                            style: TextStyle(color: Colors.black54)),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _openAddEditDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text("Banka/Borç Ekle"),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Bankalar & Borçlar",
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900)),
                              SizedBox(height: 4),
                              Text(
                                  "Kredi kartları, krediler ve ödemeleri yönetin.",
                                  style: TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _openAddEditDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text("Banka/Borç Ekle"),
                        ),
                      ],
                    ),

                  const SizedBox(height: 14),

                  // Stats + Extra payment
                  if (banks.isNotEmpty) ...[
                    if (isCompact)
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: Colors.indigo.withOpacity(0.12)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.trending_down,
                                      color: Colors.indigo),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text("Toplam Aylık Asgari Ödeme",
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      Text(_fmtMoney(totalMin),
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => _openExtraPaymentDialog(banks),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: Colors.black.withOpacity(0.10)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                        Icons.account_balance_wallet_outlined,
                                        color: Colors.indigo),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text("Ara Ödeme Yap",
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800)),
                                        SizedBox(height: 4),
                                        Text(
                                            "Herhangi bir bankaya ekstra ödeme",
                                            style: TextStyle(
                                                color: Colors.black54,
                                                fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: Colors.indigo.withOpacity(0.12)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.trending_down,
                                        color: Colors.indigo),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text("Toplam Aylık Asgari Ödeme",
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 6),
                                        Text(_fmtMoney(totalMin),
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _openExtraPaymentDialog(banks),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: Colors.black.withOpacity(0.10)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                          Icons.account_balance_wallet_outlined,
                                          color: Colors.indigo),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text("Ara Ödeme Yap",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800)),
                                          SizedBox(height: 4),
                                          Text(
                                              "Herhangi bir bankaya ekstra ödeme",
                                              style: TextStyle(
                                                  color: Colors.black54,
                                                  fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                  ],

                  // GRID (List yerine)
                  Expanded(
                    child: banks.isEmpty
                        ? Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: Colors.black.withOpacity(0.10)),
                            ),
                            child: const Center(
                                child: Text("Henüz banka eklenmemiş")),
                          )
                        : GridView.builder(
                            itemCount: banks.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemBuilder: (_, i) {
                              final b = banks[i];

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: Colors.black.withOpacity(0.06)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // ✅ ÜST BLOK (bilgiler)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                b.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w900),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: b.isActive
                                                    ? Colors.green
                                                        .withOpacity(0.10)
                                                    : Colors.grey
                                                        .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                b.isActive ? "Aktif" : "Pasif",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: b.isActive
                                                      ? Colors.green
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          b.debtType,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.black54),
                                        ),
                                        const SizedBox(height: 10),
                                        Text("Toplam Borç",
                                            style: TextStyle(
                                                color: Colors.black
                                                    .withOpacity(0.55),
                                                fontSize: 11)),
                                        Text(
                                          _fmtMoney(b.totalDebt),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text("Faiz Oranı",
                                                      style: TextStyle(
                                                          color: Colors.black54,
                                                          fontSize: 11)),
                                                  Text(
                                                    "%${b.interestRate} (${b.interestType})",
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text("Asgari Ödeme",
                                                      style: TextStyle(
                                                          color: Colors.black54,
                                                          fontSize: 11)),
                                                  Text(
                                                    b.minPaymentType ==
                                                            "percentage"
                                                        ? "%${b.minPaymentAmount}"
                                                        : _fmtMoney(
                                                            b.minPaymentAmount),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Color(0xFFE11D48),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // ✅ ALT BLOK (çizgi + butonlar)
                                    const SizedBox(height: 8),
                                    Divider(
                                      height: 18,
                                      thickness: 1,
                                      color: Colors.black.withOpacity(0.06),
                                    ),

                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        IconButton(
                                          tooltip: "Düzenle",
                                          onPressed: () =>
                                              _openAddEditDialog(edit: b),
                                          icon:
                                              const Icon(Icons.edit, size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        IconButton(
                                          tooltip: "Sil",
                                          onPressed: () => _confirmDelete(b),
                                          icon: Icon(Icons.delete,
                                              size: 20,
                                              color: Colors.grey.shade700),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => BankPlanScreen(
                                                    bankId: b.id),
                                              ),
                                            );
                                            setState(() {});
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.indigo.withOpacity(0.12),
                                            foregroundColor: Colors.indigo,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 10),
                                          ),
                                          icon: const Icon(Icons.open_in_new,
                                              size: 18),
                                          label: const Text("Plan"),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
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
