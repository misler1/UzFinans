import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/shell.dart';
import 'firebase_options.dart';

import 'models/income.dart';
import 'models/expense.dart';
import 'models/bank_debt.dart';
import 'services/income_service.dart';
import 'services/expense_service.dart';
import 'services/bank_debt_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();

  // Adapters
  Hive.registerAdapter(IncomeAdapter());
  Hive.registerAdapter(ExpenseAdapter());
  Hive.registerAdapter(BankDebtAdapter());

  // Boxes
  await Hive.openBox<Income>('incomes');
  await Hive.openBox<Expense>('expenses');
  await Hive.openBox<BankDebt>('bank_debts');

  // İlk açılışta cloud ile local verileri hizala.
  await IncomeService().syncFromCloud();
  await ExpenseService().syncFromCloud();
  await BankDebtService().syncFromCloud();

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
