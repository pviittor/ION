import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CadastroUsuarioPage extends StatefulWidget {
  @override
  _CadastroUsuarioPageState createState() => _CadastroUsuarioPageState();
}

class _CadastroUsuarioPageState extends State<CadastroUsuarioPage> {
  final _formKey = GlobalKey<FormState>();
  final nomeController = TextEditingController();
  final sobrenomeController = TextEditingController();
  final emailController = TextEditingController();
  final telefoneController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _aceitouTermos = false; // Nova variável para controlar aceite dos termos

  _cadastrarUsuario() async {
    if (_formKey.currentState!.validate()) {
      // Validação adicional para aceite dos termos
      if (!_aceitouTermos) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Você deve aceitar os Termos de Uso e Política de Privacidade para continuar'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // Remove formatação do telefone antes de enviar
      String telefoneNumeros = telefoneController.text.replaceAll(RegExp(r'\D'), '');

      final dados = {
        'nome': nomeController.text,
        'sobrenome': sobrenomeController.text,
        'email': emailController.text,
        'telefone': telefoneNumeros, // Envia apenas os números
        'senha': senhaController.text,
      };

      try {
        final response = await http.post(
          Uri.parse('http://91.108.125.253:3000/api/cadastro'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(dados),
        );

        if (response.statusCode == 201) {
          final responseBody = jsonDecode(response.body);
          print('Usuário cadastrado com sucesso! ID: ${responseBody['idusuario']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Usuário cadastrado com sucesso!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        } else {
          String mensagemErro = 'Erro ao cadastrar usuário';
          
          try {
            final errorBody = jsonDecode(response.body);
            if (errorBody['mensagem'] != null) {
              mensagemErro = errorBody['mensagem'];
              
              if (mensagemErro.contains('Email já cadastrado')) {
                mensagemErro = 'Este email já está em uso. Tente fazer login ou use outro email.';
              }
            }
          } catch (e) {
            // Se não conseguir decodificar, usa mensagem padrão
            print('Erro ao decodificar resposta de erro: $e');
          }
          
          print('Erro ao cadastrar usuário: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensagemErro),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4), // Mais tempo para ler a mensagem
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro de conexão. Tente novamente.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Função para exibir os termos de uso
  void _mostrarTermosDeUso() async {
    try {
      String termos = await rootBundle.loadString('assets/termos_uso_lgpd.md');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Termos de Uso e Política de Privacidade',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Container(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: Text(
                  termos,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Fechar'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar os termos de uso'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    nomeController.dispose();
    sobrenomeController.dispose();
    emailController.dispose();
    telefoneController.dispose();
    senhaController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }

  // Validadores personalizados
  String? _validarNome(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nome é obrigatório';
    }
    
    // Remove espaços extras e converte para formato adequado
    String nomeFormatado = _formatarNome(value);
    
    if (nomeFormatado.length < 2) {
      return 'Nome deve ter pelo menos 2 caracteres';
    }
    
    if (nomeFormatado.length > 50) {
      return 'Nome deve ter no máximo 50 caracteres';
    }
    
    // Verifica se contém apenas letras, espaços e acentos
    RegExp nomeRegex = RegExp(r'^[a-zA-ZÀ-ÿ\s]+$');
    if (!nomeRegex.hasMatch(nomeFormatado)) {
      return 'Nome deve conter apenas letras';
    }
    
    // Verifica se não contém números
    if (RegExp(r'\d').hasMatch(nomeFormatado)) {
      return 'Nome não pode conter números';
    }
    
    return null;
  }
  
  String? _validarSobrenome(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Sobrenome é obrigatório';
    }
    
    String sobrenomeFormatado = _formatarNome(value);
    
    if (sobrenomeFormatado.length < 2) {
      return 'Sobrenome deve ter pelo menos 2 caracteres';
    }
    
    if (sobrenomeFormatado.length > 50) {
      return 'Sobrenome deve ter no máximo 50 caracteres';
    }
    
    RegExp sobrenomeRegex = RegExp(r'^[a-zA-ZÀ-ÿ\s]+$');
    if (!sobrenomeRegex.hasMatch(sobrenomeFormatado)) {
      return 'Sobrenome deve conter apenas letras';
    }
    
    if (RegExp(r'\d').hasMatch(sobrenomeFormatado)) {
      return 'Sobrenome não pode conter números';
    }
    
    return null;
  }
  
  String? _validarTelefone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Telefone é obrigatório';
    }
    
    // Remove todos os caracteres não numéricos
    String telefoneNumeros = value.replaceAll(RegExp(r'\D'), '');
    
    if (telefoneNumeros.length < 10) {
      return 'Telefone deve ter pelo menos 10 dígitos';
    }
    
    if (telefoneNumeros.length > 11) {
      return 'Telefone deve ter no máximo 11 dígitos';
    }
    
    // Verifica se é um número de celular válido (começa com 9 para celular)
    if (telefoneNumeros.length == 11 && !telefoneNumeros.substring(2, 3).startsWith('9')) {
      return 'Número de celular deve começar com 9';
    }
    
    // Verifica códigos de área válidos (11-99)
    if (telefoneNumeros.length >= 2) {
      int codigoArea = int.tryParse(telefoneNumeros.substring(0, 2)) ?? 0;
      if (codigoArea < 11 || codigoArea > 99) {
        return 'Código de área inválido';
      }
    }
    
    return null;
  }
  
  // Formatadores
  String _formatarNome(String nome) {
    // Remove espaços extras e converte para formato título
    return nome.trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
  
  String _formatarTelefone(String telefone) {
    String numeros = telefone.replaceAll(RegExp(r'\D'), '');
    
    if (numeros.length == 10) {
      // Formato: (11) 1234-5678
      return '(${numeros.substring(0, 2)}) ${numeros.substring(2, 6)}-${numeros.substring(6)}';
    } else if (numeros.length == 11) {
      // Formato: (11) 91234-5678
      return '(${numeros.substring(0, 2)}) ${numeros.substring(2, 7)}-${numeros.substring(7)}';
    }
    
    return telefone;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.red),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Crie Sua Conta',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header com ícone
                Container(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_add,
                          size: 50,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Bem-vindo!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Preencha os dados abaixo para criar sua conta',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Campos do formulário
                _buildTextField(
                  controller: nomeController,
                  label: "Nome",
                  icon: Icons.person,
                  keyboardType: TextInputType.name,
                  validator: _validarNome,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZÀ-ÿ\s]')),
                    LengthLimitingTextInputFormatter(50),
                  ],
                  onChanged: (value) {
                    // Formatação em tempo real
                    if (value.isNotEmpty && value.endsWith(' ')) {
                      String formatted = _formatarNome(value);
                      if (formatted != value) {
                        nomeController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    }
                  },
                ),
                
                SizedBox(height: 20),
                
                _buildTextField(
                  controller: sobrenomeController,
                  label: "Sobrenome",
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                  validator: _validarSobrenome,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZÀ-ÿ\s]')),
                    LengthLimitingTextInputFormatter(50),
                  ],
                  onChanged: (value) {
                    if (value.isNotEmpty && value.endsWith(' ')) {
                      String formatted = _formatarNome(value);
                      if (formatted != value) {
                        sobrenomeController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    }
                  },
                ),
                
                SizedBox(height: 20),
                
                _buildTextField(
                  controller: emailController,
                  label: "E-mail",
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value!.contains('@') ? null : 'Email inválido',
                ),
                
                SizedBox(height: 20),
                
                _buildTextField(
                  controller: telefoneController,
                  label: "Telefone",
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: _validarTelefone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                    _TelefoneInputFormatter(),
                  ],
                ),
                
                SizedBox(height: 20),
                
                _buildTextField(
                  controller: senhaController,
                  label: "Senha",
                  icon: Icons.lock,
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value!.isEmpty) return 'Informe a senha';
                    if (value.length < 6) return 'Senha deve ter pelo menos 6 caracteres';
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                
                SizedBox(height: 20),
                
                _buildTextField(
                  controller: confirmarSenhaController,
                  label: "Confirmar Senha",
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirme sua senha';
                    }
                    if (value != senhaController.text) {
                      return 'As senhas não coincidem';
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                
                SizedBox(height: 30),
                
                // Checkbox de aceite dos termos LGPD
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _aceitouTermos,
                        onChanged: (bool? value) {
                          setState(() {
                            _aceitouTermos = value ?? false;
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 12),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Li e aceito os ',
                                  ),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: _mostrarTermosDeUso,
                                      child: Text(
                                        'Termos de Uso e Política de Privacidade',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          decoration: TextDecoration.underline,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' conforme a LGPD.',
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Ao aceitar, você concorda com o tratamento dos seus dados pessoais conforme descrito em nossa política de privacidade.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 30),
                
                // Botão de cadastro (modificado para incluir validação dos termos)
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      colors: _aceitouTermos 
                          ? [Colors.blue, Colors.blue.shade700]
                          : [Colors.grey.shade400, Colors.grey.shade500],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_aceitouTermos ? Colors.blue : Colors.grey).withOpacity(0.3),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_aceitouTermos) ? null : _cadastrarUsuario,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "Cadastrar",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                
                SizedBox(height: 30),
                
                // Link para login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Já tem uma conta? ",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Fazer Login",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ... Adicionar esta classe antes do fechamento da classe _CadastroUsuarioPageState
class _TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text;
    
    // Remove todos os caracteres não numéricos
    String digitsOnly = newText.replaceAll(RegExp(r'\D'), '');
    
    // Limita a 11 dígitos
    if (digitsOnly.length > 11) {
      digitsOnly = digitsOnly.substring(0, 11);
    }
    
    String formatted = '';
    
    if (digitsOnly.length >= 1) {
      formatted += '(';
      if (digitsOnly.length >= 2) {
        formatted += digitsOnly.substring(0, 2) + ') ';
        if (digitsOnly.length >= 3) {
          if (digitsOnly.length <= 6) {
            formatted += digitsOnly.substring(2);
          } else {
            if (digitsOnly.length == 10) {
              // Telefone fixo: (11) 1234-5678
              formatted += digitsOnly.substring(2, 6) + '-' + digitsOnly.substring(6);
            } else {
              // Celular: (11) 91234-5678
              formatted += digitsOnly.substring(2, 7);
              if (digitsOnly.length > 7) {
                formatted += '-' + digitsOnly.substring(7);
              }
            }
          }
        }
      } else {
        formatted += digitsOnly;
      }
    } else {
      formatted = digitsOnly;
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
