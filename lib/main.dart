import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/shell.dart';

import 'models/income.dart';
import 'models/expense.dart';
import 'models/bank_debt.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Adapters
  Hive.registerAdapter(IncomeAdapter());
  Hive.registerAdapter(ExpenseAdapter());
  Hive.registerAdapter(BankDebtAdapter());

  // Boxes
  await Hive.openBox<Income>('incomes');
  await Hive.openBox<Expense>('expenses');
  await Hive.openBox<BankDebt>('bank_debts');

  runApp(const UzFinansApp());
}

class UzFinansApp extends StatelessWidget {
  const UzFinansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UzFinans',
      theme: AppTheme.lightTheme,
      home: const Shell(),
    );
  }
}
