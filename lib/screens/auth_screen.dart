import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/trade_sim_controller.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final controller = context.read<TradeSimController>();
    var succeeded = false;
    try {
      succeeded = _isRegistering
          ? await controller.register(
              fullName: _nameController.text,
              email: _emailController.text,
              password: _passwordController.text,
            )
          : await controller.signIn(
              email: _emailController.text,
              password: _passwordController.text,
            );
      if (!succeeded && mounted && controller.errorMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(controller.errorMessage!)));
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível concluir: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 850;
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: wide
                      ? Row(
                          children: [
                            Expanded(child: _brandPanel(colors)),
                            Expanded(child: _formPanel()),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.all(28),
                          child: _formPanel(),
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandPanel(ColorScheme colors) {
    return Container(
      constraints: const BoxConstraints(minHeight: 580),
      padding: const EdgeInsets.all(48),
      color: const Color(0xFF073B2E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.candlestick_chart, color: Colors.white, size: 44),
          const SizedBox(height: 20),
          const Text(
            'TradeSim',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Aprenda, simule e acompanhe seus investimentos em um ambiente feito para você.',
            style: TextStyle(
              color: Color(0xFFD8E9E2),
              fontSize: 17,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          _feature(Icons.show_chart, 'Cotações da bolsa brasileira'),
          _feature(Icons.account_balance_wallet_outlined, 'Carteira simulada'),
          _feature(Icons.bolt_outlined, 'Day trade e swing trade'),
          const SizedBox(height: 36),
          Text(
            'Simulação para fins educacionais. Não é uma corretora.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF73D3A2)),
        const SizedBox(width: 14),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    ),
  );

  Widget _formPanel() {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isRegistering ? 'Crie sua conta' : 'Bem-vindo de volta',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isRegistering
                  ? 'Seu saldo de simulação começa com R\$ 50.000,00.'
                  : 'Entre para acessar sua carteira de simulação.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            if (_isRegistering) ...[
              TextFormField(
                key: const ValueKey('fullNameField'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe seu nome.'
                    : null,
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              key: const ValueKey('emailField'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null ||
                    !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
                  return 'Informe um e-mail válido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('passwordField'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              validator: (value) {
                if (_isRegistering && (value == null || value.length < 6)) {
                  return 'Use ao menos 6 caracteres.';
                }
                if (value == null || value.isEmpty) return 'Informe sua senha.';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isRegistering ? 'Criar conta' : 'Entrar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      context.read<TradeSimController>().clearError();
                      setState(() {
                        _isRegistering = !_isRegistering;
                        _formKey.currentState?.reset();
                      });
                    },
              child: Text(
                _isRegistering
                    ? 'Já tenho uma conta — entrar'
                    : 'Ainda não tenho conta — cadastrar',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
