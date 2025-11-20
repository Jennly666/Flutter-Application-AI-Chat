// lib/screens/api_key_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:ai_chat_flutter/services/auth_service.dart';

class ApiKeySetupScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onSuccess;

  const ApiKeySetupScreen({
    super.key,
    required this.authService,
    required this.onSuccess,
  });

  @override
  State<ApiKeySetupScreen> createState() => _ApiKeySetupScreenState();
}

class _ApiKeySetupScreenState extends State<ApiKeySetupScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _generatedPin;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _generatedPin = null;
    });

    try {
      final pin = await widget.authService.setupApiKey(_controller.text.trim());
      setState(() {
        _generatedPin = pin;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройка API-ключа')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Введите API-ключ OpenRouter или VSEGPT.\n'
              'По ключу будет определён провайдер и проверен баланс.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'API ключ',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            if (_generatedPin != null) ...[
              const SizedBox(height: 16),
              Text(
                'Ваш PIN: $_generatedPin\n'
                'Обязательно запомните его – он нужен для дальнейшего входа.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: widget.onSuccess,
                child: const Text('Продолжить'),
              ),
            ] else
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Проверить и сохранить'),
              ),
          ],
        ),
      ),
    );
  }
}
