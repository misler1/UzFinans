import 'package:hive/hive.dart';
import '../models/expense.dart';

class ExpenseService {
  static const String boxName = "expenses";

  Box<Expense> get _box => Hive.box<Expense>(boxName);

  List<Expense> getAll() => _box.values.toList();

  // ✅ id ile yaz (sende zaten buydu, koruduk)
  Future<void> add(Expense item) async => _box.put(item.id, item);

  Future<void> update(Expense item) async => item.save();

  Future<void> delete(Expense item) async => item.delete();

  Future<void> clearAll() async {
    final box = Hive.box<Expense>(boxName);
    await box.clear();
  }

  // ✅ YENİ: aynı seriesId'ye sahip bütün kayıtları getir
  List<Expense> getBySeriesId(String seriesId) {
    final list = _box.values.where((e) => e.seriesId == seriesId).toList();

    // occurrenceIndex varsa ona göre sırala, yoksa tarihe göre
    list.sort((a, b) {
      final ai = a.occurrenceIndex;
      final bi = b.occurrenceIndex;
      if (ai != null && bi != null) return ai.compareTo(bi);
      return a.date.compareTo(b.date);
    });

    return list;
  }

  // ✅ YENİ: seri düzenlemede toplu güncelle
  Future<void> updateMany(List<Expense> items) async {
    for (final e in items) {
      await e.save();
    }
  }
}
