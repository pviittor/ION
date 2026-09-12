import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_user.dart'; // Tela de login para redirecionar após exclusão

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _sobrenomeController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  int? idusuario;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  // Função para carregar o ID do usuário
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      idusuario = prefs.getInt('idusuario');
    });

    if (idusuario != null) {
      _loadUserData(idusuario!);
    }
  }

  // Função para carregar os dados do usuário a partir da API
  Future<void> _loadUserData(int idusuario) async {
    final url = Uri.parse('http://91.108.125.253:3000/api/usuarios/$idusuario');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print("Dados do usuário: $responseData");
        setState(() {
          userData = responseData['usuario'];
          _nomeController.text = userData?['nome'] ?? '';
          _sobrenomeController.text = userData?['sobrenome'] ?? '';
          _telefoneController.text = userData?['telefone'] ?? '';
        });
      } else {
        print('Erro: ${response.statusCode} - ${response.body}');
        _showSnackBar('Erro ao carregar dados do usuário.', isError: true);
      }
    } catch (e) {
      print('Erro ao fazer requisição: $e');
      _showSnackBar('Erro de conexão com o servidor.', isError: true);
    }
  }

  Future<void> updateUser(int idusuario, String nome, String sobrenome, String telefone, String senha) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('http://91.108.125.253:3000/api/usuarios/$idusuario');

    final body = jsonEncode({
      'nome': nome,
      'sobrenome': sobrenome,
      'telefone': telefone,
      'senha': senha,
      'confirmarSenha': senha,
    });

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        _showSnackBar('Dados atualizados com sucesso!', isError: false);
        _senhaController.clear();
        _confirmarSenhaController.clear();
      } else {
        final errorMessage = jsonDecode(response.body)['mensagem'] ?? 'Erro ao atualizar os dados.';
        _showSnackBar(errorMessage, isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Erro de conexão com o servidor.', isError: true);
    }
  }

  Future<void> deleteUser(int idusuario) async {
    final url = Uri.parse('http://91.108.125.253:3000/api/usuarios/$idusuario');
    
    try {
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('idusuario');

        _showSnackBar('Conta excluída com sucesso!', isError: false);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        final errorMessage = jsonDecode(response.body)['mensagem'] ?? 'Erro ao excluir a conta.';
        _showSnackBar(errorMessage, isError: true);
      }
    } catch (e) {
      _showSnackBar('Erro de conexão com o servidor.', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      final nome = _nomeController.text;
      final sobrenome = _sobrenomeController.text;
      final telefone = _telefoneController.text;
      final senha = _senhaController.text;

      updateUser(idusuario!, nome, sobrenome, telefone, senha);
    }
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red[600], size: 28),
              const SizedBox(width: 12),
              const Text(
                'Excluir Conta',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: const Text(
            'Esta ação é irreversível. Tem certeza que deseja excluir sua conta permanentemente?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (idusuario != null) {
                  deleteUser(idusuario!);
                  Navigator.of(context).pop();
                } else {
                  _showSnackBar('Erro ao excluir conta: ID do usuário não encontrado.', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Excluir',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool hasVisibilityToggle = false,
    bool? isPasswordVisible,
    VoidCallback? onVisibilityToggle,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF246BFD),
            size: 22,
          ),
          suffixIcon: hasVisibilityToggle
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible == true
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey[600],
                  ),
                  onPressed: onVisibilityToggle,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF246BFD), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[400]!),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[400]!, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (idusuario == null || userData == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Carregando...',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF246BFD),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF246BFD)),
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                'Carregando seus dados...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Editar Perfil',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF246BFD),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header com avatar
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF246BFD),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Color(0xFF246BFD),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${userData?['nome'] ?? ''} ${userData?['sobrenome'] ?? ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userData?['telefone'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
            
            // Formulário
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informações Pessoais',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildTextField(
                      controller: _nomeController,
                      label: 'Nome',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira o nome';
                        }
                        return null;
                      },
                    ),
                    
                    _buildTextField(
                      controller: _sobrenomeController,
                      label: 'Sobrenome',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira o sobrenome';
                        }
                        return null;
                      },
                    ),
                    
                    _buildTextField(
                      controller: _telefoneController,
                      label: 'Telefone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira o telefone';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    const Text(
                      'Segurança',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildTextField(
                      controller: _senhaController,
                      label: 'Nova Senha',
                      icon: Icons.lock_outline,
                      obscureText: !_isPasswordVisible,
                      hasVisibilityToggle: true,
                      isPasswordVisible: _isPasswordVisible,
                      onVisibilityToggle: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira a senha';
                        }
                        if (value.length < 6) {
                          return 'A senha deve ter pelo menos 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    
                    _buildTextField(
                      controller: _confirmarSenhaController,
                      label: 'Confirmar Nova Senha',
                      icon: Icons.lock_outline,
                      obscureText: !_isConfirmPasswordVisible,
                      hasVisibilityToggle: true,
                      isPasswordVisible: _isConfirmPasswordVisible,
                      onVisibilityToggle: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, confirme a senha';
                        }
                        if (value != _senhaController.text) {
                          return 'As senhas não coincidem';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Botão Salvar
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF246BFD),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: const Color(0xFF246BFD).withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Salvar Alterações',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Botão Excluir Conta
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _deleteAccount,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[600],
                          side: BorderSide(color: Colors.red[600]!, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Excluir Conta',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
