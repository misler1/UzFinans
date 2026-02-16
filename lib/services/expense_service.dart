import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../models/expense.dart';

class ExpenseService {
  static const String boxName = "expenses";
  static const String collectionName = 'expenses';

  Box<Expense> get _box => Hive.box<Expense>(boxName);
  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(collectionName);

  List<Expense> getAll() => _box.values.toList();

  // ✅ id ile yaz (sende zaten buydu, koruduk)
  Future<void> add(Expense item) async {
    await _box.put(item.id, item);
    await _collection.doc(item.id).set(_toMap(item));
  }

  Future<void> update(Expense item) async {
    await _box.put(item.id, item);
    await _collection.doc(item.id).set(_toMap(item));
  }

  Future<void> delete(Expense item) async {
    await _box.delete(item.id);
    await _collection.doc(item.id).delete();
  }

  Future<void> clearAll() async {
    final box = Hive.box<Expense>(boxName);
    await box.clear();
    final snap = await _collection.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
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
      await update(e);
    }
  }

  Future<void> syncFromCloud() async {
    final snap = await _collection.get();

    if (snap.docs.isEmpty && _box.isNotEmpty) {
      for (final expense in _box.values) {
        await _collection.doc(expense.id).set(_toMap(expense));
      }
      return;
    }

    final cloudIds = <String>{};
    for (final doc in snap.docs) {
      final expense = _fromMap(doc.id, doc.data());
      await _box.put(expense.id, expense);
      cloudIds.add(expense.id);
    }

    for (final expense in _box.values) {
      if (!cloudIds.contains(expense.id)) {
        await _collection.doc(expense.id).set(_toMap(expense));
      }
    }
  }

  Map<String, dynamic> _toMap(Expense expense) {
    return {
      'name': expense.name,
      'type': expense.type,
      'amount': expense.amount,
      'date': Timestamp.fromDate(expense.date),
      'isPaid': expense.isPaid,
      'recurring': expense.recurring,
      'frequency': expense.frequency,
      'endDate':
          expense.endDate == null ? null : Timestamp.fromDate(expense.endDate!),
      'seriesId': expense.seriesId,
      'occurrenceIndex': expense.occurrenceIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Expense _fromMap(String id, Map<String, dynamic> data) {
    return Expense(
      id: id,
      name: (data['name'] ?? '') as String,
      type: (data['type'] ?? '') as String,
      amount: ((data['amount'] ?? 0) as num).toDouble(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPaid: (data['isPaid'] ?? false) as bool,
      recurring: (data['recurring'] ?? false) as bool,
      frequency: (data['frequency'] ?? 'monthly') as String,
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      seriesId: data['seriesId'] as String?,
      occurrenceIndex: (data['occurrenceIndex'] as num?)?.toInt(),
    );
  }
}
