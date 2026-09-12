import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../chat/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../password_recovery/request_password_reset_email.dart';
import '../permissions/database_permission_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;
  String? mensagemErro;

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  Future<void> fazerLogin(String email, String senha, BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      isLoading = true;
      mensagemErro = null;
    });

    try {
      final url = Uri.parse('http://91.108.125.253:3000/api/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final idUsuario = data['usuario']['id'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('idusuario', idUsuario);
        
        final permissionAsked = prefs.getBool('database_permission_asked') ?? false;
        
        if (!permissionAsked) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DatabasePermissionScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        }
      } else {
        final erro = jsonDecode(response.body)['mensagem'];
        setState(() => mensagemErro = erro);
      }
    } catch (e) {
      setState(() => mensagemErro = 'Erro ao conectar com o servidor');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        validator: validator,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF246BFD),
            size: 22,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF246BFD), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    bool isPrimary = true,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: isPrimary
            ? const LinearGradient(
                colors: [Color(0xFF246BFD), Color(0xFF3B82F6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: isPrimary ? null : Colors.white,
        border: isPrimary ? null : Border.all(color: const Color(0xFF246BFD), width: 2),
        boxShadow: [
          BoxShadow(
            color: (isPrimary ? const Color(0xFF246BFD) : Colors.grey).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    text,
                    style: TextStyle(
                      color: isPrimary ? Colors.white : const Color(0xFF246BFD),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      'assets/logo_ion.png',
                      width: 125,
                      height: 125,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Título
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Entrar',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Acesse sua conta para continuar',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Campo Email
                  _buildTextField(
                    controller: emailController,
                    hintText: 'Email',
                    icon: Icons.email_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira seu email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Por favor, insira um email válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Campo Senha
                  _buildTextField(
                    controller: senhaController,
                    hintText: 'Senha',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira sua senha';
                      }
                      if (value.length < 6) {
                        return 'A senha deve ter pelo menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Link Esqueceu senha
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RequestPasswordResetEmailPage()),
                        );
                      },
                      child: const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Esqueceu sua senha? ',
                              style: TextStyle(color: Colors.black, fontSize: 16),
                            ),
                            TextSpan(
                              text: 'Clique aqui',
                              style: TextStyle(
                                color: Color(0xFF246BFD),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Mensagem de erro
                  if (mensagemErro != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mensagemErro!,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Botão Entrar
                  _buildGradientButton(
                    text: 'Acessar',
                    onPressed: isLoading
                        ? null
                        : () => fazerLogin(emailController.text, senhaController.text, context),
                    isLoading: isLoading,
                  ),
                  const SizedBox(height: 20),
                  
                  // Divisor
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'ou',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Botão Cadastrar
                  _buildGradientButton(
                    text: 'Cadastre-se',
                    onPressed: () {
                      Navigator.pushNamed(context, '/cadastro');
                    },
                    isPrimary: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

