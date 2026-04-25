import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/admin_screen.dart';
import 'utils/constants.dart';

/// Global navigator key — used for navigation after async operations that
/// may cause the originating widget to be disposed (e.g. account deletion).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const SecureParkApp());
  } catch (e) {
    runApp(_StartupErrorApp(error: e.toString()));
  }
}

class _StartupErrorApp extends StatelessWidget {
  final String error;

  const _StartupErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'App initialization failed:\n\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

class SecureParkApp extends StatelessWidget {
  const SecureParkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const _AppRouter(),
    );
  }
}

/// Listens to auth state and routes to the correct screen based on role.
class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

enum _AuthState { loading, loggedOut, owner, admin }

class _AppRouterState extends State<_AppRouter> {
  _AuthState _state = _AuthState.loading;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _state = _AuthState.loggedOut);
      return;
    }
    // Already logged in (persisted session) — fetch role
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final role =
          (doc.exists ? (doc.data()?['role'] ?? 'owner') : 'owner') as String;
      setState(() =>
          _state = role == 'admin' ? _AuthState.admin : _AuthState.owner);
    } catch (_) {
      if (mounted) setState(() => _state = _AuthState.owner);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _AuthState.loading:
        return const _LoadingScreen();
      case _AuthState.loggedOut:
        return const LoginScreen();
      case _AuthState.owner:
        return const DashboardScreen();
      case _AuthState.admin:
        return const AdminScreen();
    }
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
