import 'package:flutter/material.dart';
import 'package:app_agente_inteligente/config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../user/login_user.dart';

class ResetPasswordEmailPage extends StatefulWidget {
  final String? token; // Token pode vir como parâmetro
  
  const ResetPasswordEmailPage({super.key, this.token});

  @override
  State<ResetPasswordEmailPage> createState() => _ResetPasswordEmailPageState();
}

class _ResetPasswordEmailPageState extends State<ResetPasswordEmailPage> {
  final _tokenController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscureNovaSenha = true;
  bool _obscureConfirmarSenha = true;
  bool _tokenVerified = false;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    if (widget.token != null) {
      _tokenController.text = widget.token!;
      _verifyToken();
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _verifyToken() async {
    if (_tokenController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/password-reset/verify-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': _tokenController.text.trim()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _tokenVerified = true;
          _userEmail = data['email'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Token válido! Agora você pode redefinir sua senha.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final error = jsonDecode(response.body)['error'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Token inválido'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao verificar token'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_tokenVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verifique o token primeiro'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/password-reset/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': _tokenController.text.trim(),
          'newPassword': _novaSenhaController.text.trim(),
          'confirmPassword': _confirmarSenhaController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha redefinida com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Redirecionar para login
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      } else {
        final error = jsonDecode(response.body)['error'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Erro ao redefinir senha'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao conectar com o servidor'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Redefinir Senha'),
        backgroundColor: const Color(0xFF246BFD),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.lock_reset,
                size: 80,
                color: Color(0xFF246BFD),
              ),
              const SizedBox(height: 30),
              const Text(
                'Redefinir Senha',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _tokenVerified 
                    ? 'Digite sua nova senha para $_userEmail'
                    : 'Digite o código recebido por email',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Campo do Token
              TextFormField(
                controller: _tokenController,
                decoration: InputDecoration(
                  labelText: 'Código de Redefinição',
                  hintText: 'Digite o código recebido por email',
                  prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFF246BFD)),
                  suffixIcon: _tokenVerified 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: _isLoading ? null : _verifyToken,
                        ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _tokenVerified ? Colors.green : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF246BFD), width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite o código de redefinição';
                  }
                  return null;
                },
                enabled: !_tokenVerified,
              ),
              
                if (!_tokenVerified) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyToken,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF246BFD),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Verificar Código'),
                ),
              ],
              
              if (_tokenVerified) ...[
                const SizedBox(height: 30),
                
                // Campo Nova Senha
                TextFormField(
                  controller: _novaSenhaController,
                  obscureText: _obscureNovaSenha,
                  decoration: InputDecoration(
                    labelText: 'Nova Senha',
                    hintText: 'Digite sua nova senha',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF246BFD)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNovaSenha ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNovaSenha = !_obscureNovaSenha;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF246BFD), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Digite a nova senha';
                    }
                    if (value.length < 6) {
                      return 'A senha deve ter pelo menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Campo Confirmar Senha
                TextFormField(
                  controller: _confirmarSenhaController,
                  obscureText: _obscureConfirmarSenha,
                  decoration: InputDecoration(
                    labelText: 'Confirmar Senha',
                    hintText: 'Confirme sua nova senha',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF246BFD)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmarSenha ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmarSenha = !_obscureConfirmarSenha;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF246BFD), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value != _novaSenhaController.text) {
                      return 'As senhas não coincidem';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 30),
                
                // Botão Redefinir Senha
                ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF246BFD),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Redefinir Senha',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}