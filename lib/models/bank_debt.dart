import 'package:hive/hive.dart';

part 'bank_debt.g.dart';

@HiveType(typeId: 3)
class BankDebt extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // bank.name

  @HiveField(2)
  String debtType; // Credit Card / KMH vb.

  @HiveField(3)
  double totalDebt;

  @HiveField(4)
  double interestRate; // 4.25

  @HiveField(5)
  String interestType; // "Daily" | "Monthly"

  @HiveField(6)
  String minPaymentType; // "amount" | "percentage"

  @HiveField(7)
  double minPaymentAmount; // tutar veya yüzde değer

  @HiveField(8)
  int paymentDueDay; // 1..31

  @HiveField(9)
  bool isActive;

  // Replit'teki customPayments: {"2026-02":"5000"}
  @HiveField(10)
  Map<String, String> customPayments;

  // Replit'teki paidMonths: ["2026-02","2026-03"]
  @HiveField(11)
  List<String> paidMonths;

  @HiveField(12)
  double extraPaidTotal;

  BankDebt({
    required this.id,
    required this.name,
    required this.debtType,
    required this.totalDebt,
    required this.interestRate,
    required this.interestType,
    required this.minPaymentType,
    required this.minPaymentAmount,
    required this.paymentDueDay,
    this.isActive = true,
    Map<String, String>? customPayments,
    List<String>? paidMonths,
    this.extraPaidTotal = 0,
  })  : customPayments = customPayments ?? {},
        paidMonths = paidMonths ?? [];
}
