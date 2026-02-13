// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bank_debt.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BankDebtAdapter extends TypeAdapter<BankDebt> {
  @override
  final int typeId = 3;

  @override
  BankDebt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BankDebt(
      id: fields[0] as String,
      name: fields[1] as String,
      debtType: fields[2] as String,
      totalDebt: fields[3] as double,
      interestRate: fields[4] as double,
      interestType: fields[5] as String,
      minPaymentType: fields[6] as String,
      minPaymentAmount: fields[7] as double,
      paymentDueDay: fields[8] as int,
      isActive: fields[9] as bool,
      customPayments: (fields[10] as Map?)?.cast<String, String>(),
      paidMonths: (fields[11] as List?)?.cast<String>(),
      extraPaidTotal: fields[12] as double,
    );
  }

  @override
  void write(BinaryWriter writer, BankDebt obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.debtType)
      ..writeByte(3)
      ..write(obj.totalDebt)
      ..writeByte(4)
      ..write(obj.interestRate)
      ..writeByte(5)
      ..write(obj.interestType)
      ..writeByte(6)
      ..write(obj.minPaymentType)
      ..writeByte(7)
      ..write(obj.minPaymentAmount)
      ..writeByte(8)
      ..write(obj.paymentDueDay)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.customPayments)
      ..writeByte(11)
      ..write(obj.paidMonths)
      ..writeByte(12)
      ..write(obj.extraPaidTotal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BankDebtAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
