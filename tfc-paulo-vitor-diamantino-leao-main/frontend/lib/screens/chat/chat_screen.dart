import 'dart:convert';
import 'package:app_agente_inteligente/screens/connection/connectionDB_screen.dart';
import 'package:flutter/material.dart';
import 'package:app_agente_inteligente/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../user/edit_user.dart';
import '../permissions/database_permission_screen.dart'; // Adicionar esta linha

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode(); 
  final List<Map<String, dynamic>> messages = [];
  final Set<int> _expandedMessages = {};

  // Speech-to-Text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isPermissionGranted = false;
  String _transcribedText = '';
  bool _showTranscriptionReview = false;
  
  // Dados do usuário
  String _nomeUsuario = '';
  String _sobrenomeUsuario = '';
  
  // Status das conexões
  bool _vannaConectado = false;
  bool _bancoConectado = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Removido a verificação automática de permissão
    // A permissão será verificada apenas quando o usuário tentar usar o microfone
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _validateUserSession();
    _carregarDadosUsuario();
    _verificarStatusConexoes();
  }

  Future<void> _validateUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final idusuario = prefs.getInt('idusuario');
    
    if (idusuario == null) {
      // Redirecionar para login se não houver sessão
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Função para carregar dados do usuário
  Future<void> _carregarDadosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final idusuario = prefs.getInt('idusuario');
    
    print('🔍 DEBUG: idusuario obtido do SharedPreferences: $idusuario');
    
    if (idusuario != null) {
      try {
        final url = '$backendUrl/api/usuarios/$idusuario';
        print('🌐 DEBUG: Fazendo requisição para: $url');
        
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            
          },
        ).timeout(const Duration(seconds: 10)); 
        
        print('📡 DEBUG: Status da resposta: ${response.statusCode}');
        print('📦 DEBUG: Corpo da resposta: ${response.body}');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('✅ DEBUG: Dados decodificados: $data');
          
          setState(() {
            _nomeUsuario = data['usuario']['nome'] ?? '';
            _sobrenomeUsuario = data['usuario']['sobrenome'] ?? '';
          });
          
          print('👤 DEBUG: Nome carregado: $_nomeUsuario $_sobrenomeUsuario');
        } else {
          print('❌ DEBUG: Erro HTTP ${response.statusCode}: ${response.body}');
          // ✅ ADICIONAR: Mostrar erro para o usuário
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao carregar perfil: ${response.statusCode}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('💥 DEBUG: Erro ao carregar dados do usuário: $e');
        print('📍 DEBUG: Stack trace: ${StackTrace.current}');
        
        // ✅ ADICIONAR: Mostrar erro para o usuário
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro de conexão. Verifique sua internet.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print('DEBUG: idusuario é null - usuário não está logado?');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }
  // Função para verificar apenas o status do Vanna AI
Future<void> _verificarStatusConexoes() async {
  print('🔍 Verificando status das conexões...');
  try {
    // Uma única chamada para a API de status
    final response = await http.get(
      Uri.parse("$vannaUrl/status"),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    
    print('📡 Status Code: ${response.statusCode}');
    print('📦 Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      final vannaStatus = data['vanna_connected'] ?? false;
      final bancoStatus = data['db_connected'] ?? false;
      
      setState(() {
        _vannaConectado = vannaStatus;
        _bancoConectado = bancoStatus;
      });
      
      print('✅ Status atualizado:');
      print('   Vanna conectado: $_vannaConectado');
      print('   Banco conectado: $_bancoConectado');
      print('   Connections OK: ${data['connections_ok']}');
      print('   Modelo: ${data['last_model_name']}');
    } else {
      print('❌ Erro na API: ${response.statusCode}');
      setState(() {
        _vannaConectado = false;
        _bancoConectado = false;
      });
    }
  } catch (e) {
    print('❌ Erro ao verificar status das conexões: $e');
    setState(() {
      _vannaConectado = false;
      _bancoConectado = false;
    });
  }
}
Future<void> _checkMicrophonePermission() async {
  try {
    // Primeiro verifica o status atual
    PermissionStatus currentStatus = await Permission.microphone.status;
    
    if (currentStatus.isGranted) {
      setState(() {
        _isPermissionGranted = true;
      });
      return;
    }
    
    // Se não foi concedida, solicita a permissão
    PermissionStatus status = await Permission.microphone.request();
    
    if (status.isGranted) {
      setState(() {
        _isPermissionGranted = true;
      });
      print('Permissão concedida');
    } else if (status.isDenied) {
      setState(() {
        _isPermissionGranted = false;
      });
      _showMicrophonePermissionDialog();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _isPermissionGranted = false;
      });
      _showMicrophoneSettingsDialog();
    }
  } catch (e) {
    setState(() {
      _isPermissionGranted = false;
    });
    print('Erro ao pedir permissão: $e');
  }
}

// Diálogo específico para permissão de microfone
void _showMicrophonePermissionDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Permissão de Microfone'),
        content: const Text(
          'Para usar a transcrição de voz, precisamos de acesso ao seu microfone. '
          'Você pode continuar usando o aplicativo normalmente sem esta funcionalidade.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuar sem Transcrição'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Tenta solicitar a permissão novamente
              await _checkMicrophonePermission();
            },
            child: const Text('Tentar Novamente'),
          ),
        ],
      );
    },
  );
}

// Diálogo para quando a permissão foi negada permanentemente
void _showMicrophoneSettingsDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Permissão Necessária'),
        content: const Text(
          'A permissão de microfone foi negada permanentemente. '
          'Para usar a transcrição de voz, você precisa habilitar '
          'a permissão nas configurações do aplicativo.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuar sem Transcrição'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Abrir Configurações'),
          ),
        ],
      );
    },
  );
}

  // Função para verificar e pedir permissão com melhor tratamento
  Future<void> _checkPermission() async {
    try {
      // Primeiro verifica o status atual
      PermissionStatus currentStatus = await Permission.microphone.status;
      
      if (currentStatus.isGranted) {
        setState(() {
          _isPermissionGranted = true;
        });
        return;
      }
      
      // Se não foi concedida, solicita a permissão
      PermissionStatus status = await Permission.microphone.request();
      
      if (status.isGranted) {
        setState(() {
          _isPermissionGranted = true;
        });
        print('Permissão concedida');
      } else if (status.isDenied) {
        setState(() {
          _isPermissionGranted = false;
        });
        _showPermissionDialog();
      } else if (status.isPermanentlyDenied) {
        setState(() {
          _isPermissionGranted = false;
        });
        _showSettingsDialog();
      }
    } catch (e) {
      setState(() {
        _isPermissionGranted = false;
      });
      print('Erro ao pedir permissão: $e');
    }
  }
  void _showPermissionDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPermission = prefs.getBool('database_permission_granted') ?? false;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Configurações de Permissão',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasPermission ? Icons.check_circle : Icons.cancel,
                    color: hasPermission ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Status: ${hasPermission ? "Permitido" : "Negado"}',
                    style: TextStyle(
                      color: hasPermission ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Você pode alterar a permissão para uso das credenciais do banco de dados a qualquer momento.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Esta configuração controla se o aplicativo pode acessar e salvar suas credenciais de banco de dados.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DatabasePermissionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Alterar Permissão'),
            ),
          ],
        );
      },
    );
  }
void _showSettingsDialog() {
  // Mostrar diálogo informando que a permissão é necessária
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Permissão Necessária'),
        content: const Text(
          'Para acessar as configurações do banco de dados, você precisa conceder permissão para uso das credenciais.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DatabasePermissionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Alterar Permissão'),
          ),
        ],
      );
    },
  );
}

  void _toggleListening() async {
  if (_isListening) {
    await _speech.stop();
    setState(() {
      _isListening = false;
      if (_transcribedText.isNotEmpty) {
        _showTranscriptionReview = true;
      }
    });
  } else {
    // Verifica a permissão antes de tentar usar o microfone
    if (!_isPermissionGranted) {
      await _checkMicrophonePermission();
      if (!_isPermissionGranted) {
        return; // Sai se a permissão não foi concedida
      }
    }
    
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _transcribedText = '';
        _showTranscriptionReview = false;
      });
      
      await _speech.listen(onResult: (result) {
        setState(() {
          _transcribedText = result.recognizedWords;
          _messageController.text = _transcribedText;
        });
      });
      
      setState(() {
        _isListening = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech-to-Text não está disponível'),
        ),
      );
    }
  }
}


  void _confirmAndSendTranscription() {
    setState(() {
      _showTranscriptionReview = false;
    });
    _sendMessage();
  }

  void _cancelTranscription() {
    setState(() {
      _transcribedText = '';
      _messageController.clear();
      _showTranscriptionReview = false;
    });
  }

  Widget _buildTranscriptionReview() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Texto transcrito:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_transcribedText),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _cancelTranscription,
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _confirmAndSendTranscription,
                child: const Text('Enviar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({
        'from': 'user',
        'type': 'text',
        'content': text,
        'timestamp': DateTime.now(),
      });
      _messageController.clear();
    });

    // Mostrar indicador de carregamento
    setState(() {
      messages.add({
        'from': 'bot',
        'type': 'loading',
        'content': 'Processando sua pergunta...',
        'timestamp': DateTime.now(),
      });
    });

    try {
      // Enviar pergunta para a API Vanna
      final prefs = await SharedPreferences.getInstance();
      final idusuario = prefs.getInt('idusuario');
      
      // Debug para verificar o valor
      print('Debug - idusuario recuperado: $idusuario');
      print('Debug - Todas as chaves no SharedPreferences: ${prefs.getKeys()}');
      
      // Validação do user_id
      if (idusuario == null) {
        setState(() {
          messages.removeWhere((msg) => msg['type'] == 'loading');
          messages.add({
            'text': 'Erro: Sessão expirada. Faça login novamente.',
            'isUser': false,
            'type': 'error',
            'timestamp': DateTime.now(),
          });
        });
        
        // Redirecionar para login
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      
      print('Debug - Enviando requisição com user_id: $idusuario');
      
      final requestBody = {
        'question': text,
        'user_id': idusuario,
        'allow_llm_to_see_data': true,
      };
      print('DEBUG - Corpo da requisição: $requestBody');
      print('DEBUG - user_id sendo enviado: $idusuario (tipo: ${idusuario.runtimeType})');

      final response = await http.post(
        Uri.parse("$vannaUrl/ask"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      print('Debug - Response status: ${response.statusCode}');
      print('Debug - Response body: ${response.body}');

      setState(() {
        messages.removeWhere((msg) => msg['type'] == 'loading');
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _processVannaResponse(data, text);
      } else {
        setState(() {
          messages.add({
            'from': 'bot',
            'type': 'error',
            'content': 'Desculpe, não consegui processar a pergunta. Código: ${response.statusCode}',
            'timestamp': DateTime.now(),
          });
        });
      }
    } catch (error) {
      setState(() {
        messages.removeWhere((msg) => msg['type'] == 'loading');
      });
      
      print('Erro ao comunicar com o servidor: $error');
      setState(() {
        messages.add({
          'from': 'bot',
          'type': 'error',
          'content': 'Erro ao comunicar com o servidor Vanna.AI',
          'timestamp': DateTime.now(),
        });
      });
    }
  }

  // Processar resposta da API Vanna
  Future<void> _processVannaResponse(Map<String, dynamic> data, String originalQuestion) async {
    final result = data['result'];
    final sql = data['sql']; // Capturar o SQL gerado
    
    if (result == null) {
      setState(() {
        messages.add({
          'from': 'bot',
          'type': 'text',
          'content': 'Não consegui gerar uma resposta para sua pergunta.',
          'timestamp': DateTime.now(),
        });
      });
      return;
    }

    // Se result é uma string (resposta de texto simples)
    if (result is String) {
      setState(() {
        messages.add({
          'from': 'bot',
          'type': 'text',
          'content': result,
          'sql': sql, // Incluir SQL na mensagem
          'timestamp': DateTime.now(),
        });
      });
      return;
    }

    // Se result é uma lista (dados tabulares)
    if (result is List && result.isNotEmpty) {
      // Adicionar resposta com tabela
      setState(() {
        messages.add({
          'from': 'bot',
          'type': 'table',
          'content': 'Aqui estão os resultados da sua consulta:',
          'data': result,
          'sql': sql, // Incluir SQL na mensagem
          'question': originalQuestion,
          'timestamp': DateTime.now(),
        });
      });

      // COMENTADO: Geração de gráfico desabilitada
      // await _generateChart(result, originalQuestion);
    } else {
      setState(() {
        messages.add({
          'from': 'bot',
          'type': 'text',
          'content': 'Consulta executada, mas não retornou dados.',
          'sql': sql, // Incluir SQL na mensagem
          'timestamp': DateTime.now(),
        });
      });
    }
  }
  Widget _buildMessage(Map<String, dynamic> message, int index) {
    bool isUser = message['from'] == 'user';
    String type = message['type'] ?? 'text';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.grey[300] : Colors.blue[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: _buildMessageContent(message, type, index),
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> message, String type, int messageIndex) {
    bool isBot = message['from'] == 'bot';
    String? sql = message['sql'];
    bool isExpanded = _expandedMessages.contains(messageIndex);
    
    Widget content;
    
    switch (type) {
      case 'loading':
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(message['content'] ?? ''),
          ],
        );
        break;
      
      case 'table':
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message['content'] ?? ''),
            const SizedBox(height: 8),
            _buildDataTable(message['data']),
          ],
        );
        break;
      
      case 'error':
        content = Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message['content'] ?? '')),
          ],
        );
        break;
      
      default: // text
        content = Text(message['content'] ?? '');
        break;
    }
    
    // Se é uma mensagem do bot e tem SQL, adicionar funcionalidade de expandir
    if (isBot && sql != null && sql.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedMessages.remove(messageIndex);
                } else {
                  _expandedMessages.add(messageIndex);
                }
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.blue,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  isExpanded ? 'Ocultar SQL' : 'Ver SQL gerado',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SQL Gerado:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    sql,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    
    return content;
  }

  // Construir tabela de dados
  Widget _buildDataTable(List<dynamic>? data) {
    if (data == null || data.isEmpty) {
      return const Text('Nenhum dado disponível');
    }

    final firstRow = data[0] as Map<String, dynamic>;
    final columns = firstRow.keys.toList();
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns.map((col) => DataColumn(
          label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold)),
        )).toList(),
        rows: data.take(50).map((row) { 
          final rowData = row as Map<String, dynamic>;
          return DataRow(
            cells: columns.map((col) => DataCell(
              Text(rowData[col]?.toString() ?? ''),
            )).toList(),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (BuildContext context) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.person),
                                  title: Text('$_nomeUsuario $_sobrenomeUsuario'),
                                  subtitle: const Text('Informações do usuário'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    child: const CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 32,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_nomeUsuario $_sobrenomeUsuario',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Alterar Dados Cadastrais'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                );
              },
            ),
            ListTile(
              title: const Text('Conectar seu Banco de Dados'),
              onTap: () async {
                // Verificar se a permissão foi concedida
                final prefs = await SharedPreferences.getInstance();
                final hasPermission = prefs.getBool('database_permission_granted') ?? false;
                
                if (!hasPermission) {
                  // Mostrar diálogo informando que a permissão é necessária
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Permissão Necessária'),
                        content: const Text(
                          'Para conectar ao banco de dados, você precisa conceder '
                          'permissão para uso das credenciais. '
                          'Isso é necessário para que o aplicativo possa acessar '
                          'e analisar sua base de dados.'
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const DatabasePermissionScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Revisar Permissão'),
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ConexaoBancoPage()),
                );
              },
            ),
            // Adicionar o botão de sair como opção do menu
            // Adicionar espaço para empurrar o botão de sair para o final
            const SizedBox(height: 430),
            // Botão de sair posicionado no final do menu
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text(
                'Sair do Aplicativo',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                // Mostrar diálogo de confirmação
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Sair do Aplicativo'),
                      content: const Text('Tem certeza que deseja sair do aplicativo?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Sair'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text(
          'Chat',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.security),
            tooltip: 'Configurações de Permissão',
            onPressed: _showPermissionDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemBuilder: (context, index) => _buildMessage(messages[index], index),
            ),
          ),
          if (_showTranscriptionReview) _buildTranscriptionReview(),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Faça uma pergunta sobre seus dados...',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.red : Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.red : Colors.blue).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isListening ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: _toggleListening,
                    splashRadius: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: _sendMessage,
                    splashRadius: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

    );
  }
}
