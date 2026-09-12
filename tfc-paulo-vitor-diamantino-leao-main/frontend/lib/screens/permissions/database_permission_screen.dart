import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../chat/chat_screen.dart';

class DatabasePermissionScreen extends StatefulWidget {
  const DatabasePermissionScreen({super.key});

  @override
  State<DatabasePermissionScreen> createState() => _DatabasePermissionScreenState();
}

class _DatabasePermissionScreenState extends State<DatabasePermissionScreen> {
  bool _isLoading = false;

  Future<void> _concederPermissao() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      // Corrigir as chaves para serem consistentes
      await prefs.setBool('database_permission_granted', true);
      await prefs.setBool('database_permission_asked', true);
      await prefs.setInt('timestamp_permissao', DateTime.now().millisecondsSinceEpoch);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissão concedida com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Se foi chamada do chat, volta para o chat
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          // Se foi chamada do login, vai para o chat
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar permissão. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _negarPermissao() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      // Corrigir as chaves para serem consistentes
      await prefs.setBool('database_permission_granted', false);
      await prefs.setBool('database_permission_asked', true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissão negada. Você pode alterar isso a qualquer momento.'),
            backgroundColor: Color(0xFFF44336),
          ),
        );
        
        // SEMPRE vai para o chat, mesmo negando a permissão
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar permissão. Tente novamente.'),
            backgroundColor: Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarDetalhesPermissao() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Detalhes da Permissão',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'O que fazemos com seus dados:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• Conectamos ao seu banco de dados para análise'),
              SizedBox(height: 8),
              Text('• Extraímos metadados das tabelas'),
              SizedBox(height: 8),
              Text('• Geramos consultas SQL inteligentes'),
              SizedBox(height: 16),
              Text(
                'Segurança:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• Suas credenciais são criptografadas'),
              SizedBox(height: 8),
              Text('• Você pode revogar a permissão a qualquer momento'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                        MediaQuery.of(context).padding.top - 
                        MediaQuery.of(context).padding.bottom - 48,
            ),
            child: Column(
              children: [
                // Conteúdo principal
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ícone de segurança
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF246BFD).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.security,
                        size: 50,
                        color: Color(0xFF246BFD),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Título
                    const Text(
                      'Permissão de Acesso',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    // Subtítulo
                    const Text(
                      'Conectar ao seu Banco de Dados',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Descrição
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Para oferecer a melhor experiência com IA, precisamos da sua autorização para:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          
                          // Lista de permissões
                          _buildPermissionItem(
                            Icons.storage,
                            'Conectar ao seu banco de dados',
                            'Para análise de estrutura e geração de consultas',
                          ),
                          const SizedBox(height: 12),
                          _buildPermissionItem(
                            Icons.save_alt,
                            'Salvar suas credenciais de forma segura',
                            'Criptografadas e protegidas em nossos servidores',
                          ),
                          const SizedBox(height: 12),
                          _buildPermissionItem(
                            Icons.analytics,
                            'Analisar metadados das tabelas',
                            'Para criar consultas SQL inteligentes',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Link para mais detalhes
                    TextButton(
                      onPressed: _mostrarDetalhesPermissao,
                      child: const Text(
                        'Ver detalhes sobre segurança e privacidade',
                        style: TextStyle(
                          color: Color(0xFF246BFD),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Botões de ação
                Column(
                  children: [
                    // Botão Permitir
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _concederPermissao,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF246BFD),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Permitir Acesso',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Botão Negar - INDENTAÇÃO CORRIGIDA
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _negarPermissao,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black54,
                          side: const BorderSide(color: Colors.black26),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Agora Não',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Texto de rodapé
                    const Text(
                      'Você pode alterar essa permissão a qualquer momento nas configurações do aplicativo.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF246BFD).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF246BFD),
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

