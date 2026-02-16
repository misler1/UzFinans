import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../models/income.dart';

class IncomeService {
  static const String boxName = 'incomes';
  static const String collectionName = 'incomes';

  Box<Income> get _box => Hive.box<Income>(boxName);
  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(collectionName);

  List<Income> getAll() {
    return _box.values.toList();
  }

  Future<void> add(Income income) async {
    await _box.put(income.id, income);
    await _collection.doc(income.id).set(_toMap(income));
  }

  Future<void> update(Income income) async {
    await _box.put(income.id, income);
    await _collection.doc(income.id).set(_toMap(income));
  }

  Future<void> delete(Income income) async {
    await _box.delete(income.id);
    await _collection.doc(income.id).delete();
  }

  Future<void> clearAll() async {
    await _box.clear();
    final snap = await _collection.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
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
      await update(i);
    }
  }

  Future<void> syncFromCloud() async {
    final snap = await _collection.get();

    // Cloud boşsa mevcut local datayı cloud'a taşı.
    if (snap.docs.isEmpty && _box.isNotEmpty) {
      for (final income in _box.values) {
        await _collection.doc(income.id).set(_toMap(income));
      }
      return;
    }

    final cloudIds = <String>{};
    for (final doc in snap.docs) {
      final income = _fromMap(doc.id, doc.data());
      await _box.put(income.id, income);
      cloudIds.add(income.id);
    }

    // Sadece localde kalan yeni kayıtları cloud'a yaz.
    for (final income in _box.values) {
      if (!cloudIds.contains(income.id)) {
        await _collection.doc(income.id).set(_toMap(income));
      }
    }
  }

  Map<String, dynamic> _toMap(Income income) {
    return {
      'name': income.name,
      'type': income.type,
      'amount': income.amount,
      'date': Timestamp.fromDate(income.date),
      'isReceived': income.isReceived,
      'recurring': income.recurring,
      'frequency': income.frequency,
      'endDate':
          income.endDate == null ? null : Timestamp.fromDate(income.endDate!),
      'seriesId': income.seriesId,
      'occurrenceIndex': income.occurrenceIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Income _fromMap(String id, Map<String, dynamic> data) {
    return Income(
      id: id,
      name: (data['name'] ?? '') as String,
      type: (data['type'] ?? '') as String,
      amount: ((data['amount'] ?? 0) as num).toDouble(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isReceived: (data['isReceived'] ?? false) as bool,
      recurring: (data['recurring'] ?? false) as bool,
      frequency: (data['frequency'] ?? 'monthly') as String,
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      seriesId: data['seriesId'] as String?,
      occurrenceIndex: (data['occurrenceIndex'] as num?)?.toInt(),
    );
  }
}
