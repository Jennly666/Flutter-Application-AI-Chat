// lib/screens/pin_login_screen.dart

import 'package:flutter/material.dart';
import 'package:ai_chat_flutter/services/auth_service.dart';

class PinLoginScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onSuccess;
  final VoidCallback onResetKey;

  const PinLoginScreen({
    super.key,
    required this.authService,
    required this.onSuccess,
    required this.onResetKey,
  });

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final pin = _pinController.text.trim();

    final ok = await widget.authService.verifyPin(pin);
    if (!mounted) return;

    if (ok) {
      widget.onSuccess();
    } else {
      setState(() {
        _error = 'Неверный PIN';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _resetKey() async {
    await widget.authService.clearAuth();
    widget.onResetKey();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход по PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Введите 4-значный PIN для входа.'),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Войти'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _resetKey,
              child: const Text('Сбросить ключ и ввести новый'),
            ),
          ],
        ),
      ),
    );
  }
}
