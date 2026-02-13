import 'package:hive/hive.dart';
import '../models/income.dart';

class IncomeService {
  static const String boxName = 'incomes';

  Box<Income> get _box => Hive.box<Income>(boxName);

  List<Income> getAll() {
    return _box.values.toList();
  }

  Future<void> add(Income income) async {
    await _box.add(income);
  }

  Future<void> update(Income income) async {
    await income.save();
  }

  Future<void> delete(Income income) async {
    await income.delete();
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  // ✅ YENİ: Aynı seriesId olan gelirleri getir (seri)
  List<Income> getBySeriesId(String seriesId) {
    final list = _box.values.where((x) => x.seriesId == seriesId).toList();
    list.sort(
      (a, b) => (a.occurrenceIndex ?? 0).compareTo(b.occurrenceIndex ?? 0),
    );
    return list;
  }

  // ✅ YENİ: Birden çok geliri kaydet (seri güncelleme için)
  Future<void> updateMany(List<Income> incomes) async {
    for (final i in incomes) {
      await i.save();
    }
  }
}
