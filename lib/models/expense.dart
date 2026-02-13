import 'package:hive/hive.dart';

part 'expense.g.dart';

@HiveType(typeId: 2)
class Expense extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String type;

  @HiveField(3)
  double amount;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  bool isPaid;

  @HiveField(6)
  bool recurring;

  @HiveField(7)
  String frequency; // weekly / monthly

  @HiveField(8)
  DateTime? endDate;

  // ✅ YENİ: seri kimliği (tekrarlı kayıtları gruplamak için)
  @HiveField(9)
  String? seriesId;

  // ✅ YENİ: seride kaçıncı kayıt (0,1,2...)
  @HiveField(10)
  int? occurrenceIndex;

  Expense({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.date,
    this.isPaid = false,
    this.recurring = false,
    this.frequency = "monthly",
    this.endDate,
    this.seriesId,
    this.occurrenceIndex,
  });
}
