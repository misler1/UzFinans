import 'package:hive/hive.dart';

part 'income.g.dart';

@HiveType(typeId: 1)
class Income extends HiveObject {
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
  bool isReceived;

  @HiveField(6)
  bool recurring;

  @HiveField(7)
  String frequency; // weekly / monthly

  @HiveField(8)
  DateTime? endDate;

  // ✅ YENİ: Aynı tekrarlı seriyi bağlamak için
  @HiveField(9)
  String? seriesId;

  // ✅ YENİ: Seride kaçıncı tekrar (0,1,2,3...)
  @HiveField(10)
  int? occurrenceIndex;

  Income({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.date,
    this.isReceived = false,
    this.recurring = false,
    this.frequency = "monthly",
    this.endDate,
    this.seriesId,
    this.occurrenceIndex,
  });
}
