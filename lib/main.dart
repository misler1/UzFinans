import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/shell.dart';
import 'screens/auth_screen.dart';
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
  await Hive.openBox('app_meta');

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
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final IncomeService _incomeService = IncomeService();
  final ExpenseService _expenseService = ExpenseService();
  final BankDebtService _bankDebtService = BankDebtService();
  final Box _metaBox = Hive.box('app_meta');

  Future<void>? _syncFuture;
  String? _syncUid;

  Future<void> _syncForUser(String uid) async {
    final prevUid = _metaBox.get('owner_uid') as String?;
    if (prevUid != null && prevUid != uid) {
      await _incomeService.clearAllLocalOnly();
      await _expenseService.clearAllLocalOnly();
      await _bankDebtService.clearAllLocalOnly();
    }

    await _incomeService.syncFromCloud();
    await _expenseService.syncFromCloud();
    await _bankDebtService.syncFromCloud();
    await _metaBox.put('owner_uid', uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (user == null) {
          _syncUid = null;
          _syncFuture = null;
          return const AuthScreen();
        }

        if (_syncUid != user.uid || _syncFuture == null) {
          _syncUid = user.uid;
          _syncFuture = _syncForUser(user.uid);
        }

        return FutureBuilder<void>(
          future: _syncFuture,
          builder: (context, syncSnap) {
            if (syncSnap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (syncSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Veri eşitleme başarısız"),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _syncFuture = _syncForUser(user.uid);
                            });
                          },
                          child: const Text("Tekrar Dene"),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return const Shell();
          },
        );
      },
    );
  }
}
