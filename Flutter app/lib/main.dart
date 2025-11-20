// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/chat_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/api_key_setup_screen.dart';
import 'screens/pin_login_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';

class ErrorBoundaryWidget extends StatelessWidget {
  final Widget child;

  const ErrorBoundaryWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error, stackTrace) {
          debugPrint('Error in ErrorBoundaryWidget: $error');
          debugPrint('Stack trace: $stackTrace');
          return MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.red,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('Flutter error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    };

    await dotenv.load(fileName: ".env");
    debugPrint('Environment loaded');
    debugPrint('API Key present: ${dotenv.env['OPENROUTER_API_KEY'] != null}');
    debugPrint('Base URL: ${dotenv.env['BASE_URL']}');

    final dbService = DatabaseService();
    final authService = AuthService(dbService);

    runApp(
      ErrorBoundaryWidget(
        child: MyApp(authService: authService),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('Error starting app: $e');
    debugPrint('Stack trace: $stackTrace');
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error starting app: $e',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final AuthService authService;

  const MyApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return ScrollConfiguration(
            behavior: const ScrollBehavior(), child: child!);
      },
      title: 'AI Chat',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF262626),
          foregroundColor: Colors.white,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF333333),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
          contentTextStyle: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontFamily: 'Roboto',
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
            ),
          ),
        ),
      ),
      home: AuthGate(authService: authService),
    );
  }
}

enum _AuthFlowState { loading, needKey, needPin, chat }

class AuthGate extends StatefulWidget {
  final AuthService authService;

  const AuthGate({super.key, required this.authService});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  _AuthFlowState _state = _AuthFlowState.loading;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final auth = await widget.authService.getSavedAuth();
    if (!mounted) return;
    setState(() {
      _state = auth == null ? _AuthFlowState.needKey : _AuthFlowState.needPin;
    });
  }

  void _goToChat() {
    setState(() {
      _state = _AuthFlowState.chat;
    });
  }

  void _goToKeySetup() {
    setState(() {
      _state = _AuthFlowState.needKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _AuthFlowState.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );

      case _AuthFlowState.needKey:
        return ApiKeySetupScreen(
          authService: widget.authService,
          onSuccess: _goToChat,
        );

      case _AuthFlowState.needPin:
        return PinLoginScreen(
          authService: widget.authService,
          onSuccess: _goToChat,
          onResetKey: _goToKeySetup,
        );

      case _AuthFlowState.chat:
        return ChangeNotifierProvider(
          create: (_) => ChatProvider(widget.authService),
          child: const ChatScreen(),
        );
    }
  }
}
