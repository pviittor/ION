import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ConexaoBancoPage extends StatefulWidget {
  @override
  _ConexaoBancoPageState createState() => _ConexaoBancoPageState();
}

class _ConexaoBancoPageState extends State<ConexaoBancoPage> {
  final _formKey = GlobalKey<FormState>();
  final _vannaFormKey = GlobalKey<FormState>();
  final dominioController = TextEditingController();
  final portaController = TextEditingController();
  final nomeBancoController = TextEditingController();
  final usuarioBancoController = TextEditingController();
  final senhaBancoController = TextEditingController();
  final apiKeyController = TextEditingController();
  final modelController = TextEditingController();

  String tipoBanco = 'postgresql';
   // Valor padrão
  bool isLoadingVanna = false;
  bool isLoadingBanco = false;

  int? idUsuario;
  // Iniciar sempre como false para forçar conexão manual
  bool bancoCadastrado = false;
  bool vannaConfigurado = false;
  // Adicionar variáveis para controlar se os dados estão preenchidos
  bool dadosBancoPreenchidos = false;
  bool dadosVannaPreenchidos = false;

  @override
  void initState() {
    super.initState();
    _carregarIdUsuario();
    _carregarDadosDoBanco();
  }

  Future<void> _carregarIdUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      idUsuario = prefs.getInt('idusuario');
    });
  }

  void conectarBanco() async {
    if (_formKey.currentState!.validate()) {
      if (idUsuario == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ID do usuário não encontrado. Faça login novamente.")),
        );
        return;
      }
  
      setState(() {
        isLoadingBanco = true;
      });
  
      try {
        final salvarResponse = await http.post(
          Uri.parse("http://91.108.125.253:3000/api/credenciais"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'idusuario': idUsuario,
            'dominio_banco': dominioController.text.trim(),
            'porta_banco': int.parse(portaController.text.trim()),
            'nome_banco': nomeBancoController.text.trim(),
            'nome_usuario': usuarioBancoController.text.trim(),
            'senha_usuario': senhaBancoController.text.trim(),
            'tipo_banco': tipoBanco, // Adicionar tipo do banco
          }),
        );

        if (salvarResponse.statusCode != 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao salvar os dados do banco.")),
          );
          return;
        }

        // 2. SEGUNDO: Verificar se Vanna.AI está conectado
        if (!vannaConfigurado) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Conecte ao Vanna.AI primeiro!")),
          );
          return;
        }

        // 3. TERCEIRO: Conectar ao banco de dados via API Flask
        final connectDbResponse = await http.post(
          Uri.parse("http://91.108.125.253:5000/connect-database"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'db_type': tipoBanco, // Usar tipo selecionado
            'host': dominioController.text.trim(),
            'port': int.parse(portaController.text.trim()),
            'database': nomeBancoController.text.trim(),
            'user': usuarioBancoController.text.trim(),
            'password': senhaBancoController.text.trim(),
          }),
        );

        if (connectDbResponse.statusCode == 200) {
          final responseData = jsonDecode(connectDbResponse.body);
          setState(() {
            bancoCadastrado = true;
            isLoadingBanco = false; // Desativar loading
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ Banco conectado: ${responseData['db_type']}")),
          );
        } else {
          setState(() {
            isLoadingBanco = false; // Desativar loading
          });
          final errorData = jsonDecode(connectDbResponse.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Erro ao conectar ao banco: ${errorData['error'] ?? 'Erro desconhecido'}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erro de conexão: $e")),
        );
      }
    }
  }

  void configurarVanna() async {
    if (_vannaFormKey.currentState!.validate()) {
      if (idUsuario == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ID do usuário não encontrado. Faça login novamente.")),
        );
        return;
      }
  
      // Ativar loading
      setState(() {
        isLoadingVanna = true;
      });
  
      // ✅ ADICIONAR ESTES PRINTS DE DEBUG
      print('=== DEBUG VANNA CONFIG ===');
      print('API Key: "${apiKeyController.text.trim()}"');
      print('Model: "${modelController.text.trim()}"');
      print('API Key vazia: ${apiKeyController.text.trim().isEmpty}');
      print('Model vazio: ${modelController.text.trim().isEmpty}');
      print('========================');
  
      try {
        // 1. Salvar credenciais no backend local (Node.js)
        final vannaResponse = await http.put(
          Uri.parse("http://91.108.125.253:3000/api/credenciais/$idUsuario"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'api_key': apiKeyController.text.trim(),
            'model': modelController.text.trim(),
          }),
        );
  
        if (vannaResponse.statusCode != 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao salvar credenciais do Vanna.AI.")),
          );
          return;
        }
  
        // 2. Conectar ao Vanna.AI usando a API Flask
        // Na função configurarVanna() - linha 155-156
        final connectResponse = await http.post(
          Uri.parse("http://91.108.125.253:5000/connect"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'api_key': apiKeyController.text.trim(),
            'model_name': modelController.text.trim(),
          }),
        );
  
        // ✅ ADICIONAR ESTES PRINTS AQUI
        print('=== RESPONSE DEBUG ===');
        print('Status Code: ${connectResponse.statusCode}');
        print('Response Headers: ${connectResponse.headers}');
        print('Response Body: ${connectResponse.body}');
        print('====================');
  
        if (connectResponse.statusCode == 200) {
          final responseData = jsonDecode(connectResponse.body);
          if (responseData['connected'] == true) {
            setState(() {
              vannaConfigurado = true;
              isLoadingVanna = false; // Desativar loading
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("✅ Vanna.AI conectado com sucesso!")),
            );
          } else {
            setState(() {
              isLoadingVanna = false; // Desativar loading
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("❌ Falha na conexão com Vanna.AI: ${responseData['error'] ?? 'Erro desconhecido'}")),
            );
          }
        } else {
          final errorData = jsonDecode(connectResponse.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Erro ao conectar ao Vanna.AI: ${errorData['error'] ?? 'Erro desconhecido'}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erro de conexão: $e")),
        );
      }
    } else {
      print('Formulário não passou na validação'); // ✅ ADICIONAR ESTE PRINT
    }
  }

  void conectarBancoVanna() async {
    if (!vannaConfigurado) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Conecte ao Vanna.AI primeiro!")),
      );
      return;
    }

    if (idUsuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ID do usuário não encontrado. Faça login novamente.")),
      );
      return;
    }

    try {
      // Conectar ao banco de dados via API Flask
      final connectDbResponse = await http.post(
        Uri.parse("http://91.108.125.253:5000/connect-database"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'db_type': tipoBanco, // Usar tipo selecionado
          'host': dominioController.text.trim(),
          'port': int.parse(portaController.text.trim()),
          'database': nomeBancoController.text.trim(),
          'user': usuarioBancoController.text.trim(),
          'password': senhaBancoController.text.trim(),
        }),
      );

      if (connectDbResponse.statusCode == 200) {
        final responseData = jsonDecode(connectDbResponse.body);
        setState(() {
          bancoCadastrado = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Banco de dados conectado: ${responseData['db_type']}")),
        );
      } else {
        final errorData = jsonDecode(connectDbResponse.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erro ao conectar banco: ${errorData['error'] ?? 'Erro desconhecido'}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Erro de conexão com banco: $e")),
      );
    }
  }

  Future<void> _treinarBanco() async {
    if (!bancoCadastrado || !vannaConfigurado) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Configure primeiro o banco e o Vanna.AI antes de treinar.")),
      );
      return;
    }
  
    if (idUsuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ID do usuário não encontrado. Faça login novamente.")),
      );
      return;
    }
  
    // Mostrar indicador de carregamento melhorado
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          content: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                SizedBox(height: 20),
                Text(
                  "🤖 Treinando Agente Inteligente",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Extraindo estrutura das tabelas...\nTreinando modelo com IA...",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  
    try {
      // Usar o endpoint de treinamento automático
      final treinarResponse = await http.post(
        Uri.parse("http://91.108.125.253:5000/conectar-e-treinar-automatico"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': apiKeyController.text.trim(),
          'model': modelController.text.trim(),
          'tipo_banco': tipoBanco, 
          'dominio': dominioController.text.trim(),
          'porta': int.parse(portaController.text.trim()),
          'nomeBanco': nomeBancoController.text.trim(),
          'usuario': usuarioBancoController.text.trim(),
          'senha': senhaBancoController.text.trim(),
        }),
      );
  
      // Fechar o dialog de carregamento
      Navigator.of(context).pop();
  
      if (treinarResponse.statusCode == 200) {
        final responseData = jsonDecode(treinarResponse.body);
        
        // Acessar os resultados dentro do objeto 'results'
        final results = responseData['results'] ?? {};
        
        // Verificar o status do treinamento
        String message = "";
        Color backgroundColor = Colors.green;
        IconData icon = Icons.check_circle;
        
        if (results['ddl_training'] == 'success' && 
            results['documentation_training'] == 'success') {
          message = "🎉 Treinamento Concluído com Sucesso!\n\n" +
                   "📊 ${results['ddl_count'] ?? 0} tabelas analisadas\n" +
                   "📚 ${results['doc_count'] ?? 0} documentações geradas\n" +
                   "🔍 ${results['sql_examples_count'] ?? 0} exemplos SQL criados\n\n" +
                   "✅ Seu agente está pronto para responder perguntas!";
          backgroundColor = Colors.green;
          icon = Icons.celebration;
        } else if (results['ddl_training'] == 'no_tables_found') {
          message = "⚠️ Nenhuma tabela encontrada no banco de dados.\n\n" +
                   "Verifique se o esquema está correto e tente novamente.";
          backgroundColor = Colors.orange;
          icon = Icons.warning;
        } else {
          message = "⚠️ Treinamento Parcialmente Concluído\n\n" +
                   "DDL: ${results['ddl_training'] ?? 'não executado'}\n" +
                   "Documentação: ${results['documentation_training'] ?? 'não executado'}\n\n" +
                   "Alguns recursos podem não funcionar corretamente.";
          backgroundColor = Colors.orange;
          icon = Icons.info;
        }
        
        // Mostrar dialog de sucesso em vez de SnackBar
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  Icon(icon, color: backgroundColor, size: 30),
                  SizedBox(width: 10),
                  Text(
                    "Resultado do Treinamento",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                message,
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    "OK",
                    style: TextStyle(
                      color: backgroundColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        
      } else {
        final errorData = jsonDecode(treinarResponse.body);
        
        // Mostrar dialog de erro
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 30),
                  SizedBox(width: 10),
                  Text(
                    "Erro no Treinamento",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              content: Text(
                "❌ Falha no treinamento:\n\n${errorData['error'] ?? 'Erro desconhecido'}\n\nVerifique as configurações e tente novamente.",
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    "OK",
                    style: TextStyle(
                      color: Colors.red,
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
    } catch (e) {
      // Fechar o dialog de carregamento em caso de erro
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Erro de conexão: $e"),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _carregarDadosDoBanco() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('idusuario');
  
    if (id == null) return;
  
    setState(() {
      idUsuario = id;
    });
  
    final response = await http.get(
      Uri.parse('http://91.108.125.253:3000/api/credenciais/$id'),
    );
  
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
  
      setState(() {
        dominioController.text = data['dominio_banco'] ?? '';
        portaController.text = data['porta_banco'].toString();
        nomeBancoController.text = data['nome_banco'] ?? '';
        usuarioBancoController.text = data['nome_usuario'] ?? '';
        senhaBancoController.text = data['senha_usuario'] ?? '';
        String tipoRecebido = (data['tipo_banco'] ?? 'postgresql').toString().toLowerCase();
          if (tipoRecebido == 'postgresql' || tipoRecebido == 'mysql') {
            tipoBanco = tipoRecebido;
          } else {
            tipoBanco = 'postgresql'; // Valor padrão seguro
          }   
        // ✅ Campos do Vanna.AI - JÁ ESTÃO SrENDO CARREGADOS!
        apiKeyController.text = data['api_key'] ?? '';
        modelController.text = data['model'] ?? '';
        
        // ✅ Indicadores visuais
        dadosBancoPreenchidos = data['dominio_banco'] != null && data['dominio_banco'].toString().isNotEmpty;
        dadosVannaPreenchidos = data['api_key'] != null && data['api_key'].toString().isNotEmpty;
        
        // Sempre iniciar como desconectado - usuário deve clicar nos botões
        bancoCadastrado = false;
        vannaConfigurado = false;
      });
    } else {
      print('Nenhuma credencial encontrada ou erro ao buscar.');
    }
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Color backgroundColor = Colors.blue,
    bool isEnabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEnabled
              ? [backgroundColor, backgroundColor.withOpacity(0.8)]
              : [Colors.grey, Colors.grey.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: (isEnabled ? backgroundColor : Colors.grey).withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (isEnabled && !isLoading) ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Configuração do Sistema',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue,
iconTheme: IconThemeData(color: Colors.white),      
),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // ETAPA 1: CONFIGURAÇÃO VANNA.AI (MOVIDO PARA CIMA)
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Form(
                  key: _vannaFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            vannaConfigurado ? Icons.check_circle : Icons.smart_toy,
                            color: vannaConfigurado ? Colors.green : Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ETAPA 1: CONECTE O VANNA.AI',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: vannaConfigurado ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Chip(
                        label: Text('Vanna.AI'),
                        backgroundColor: Colors.orange.shade100,
                        avatar: Icon(Icons.smart_toy, size: 16, color: Colors.orange),
                      ),
                      SizedBox(height: 20),
                      TextFormField(
                        controller: apiKeyController,
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          border: OutlineInputBorder(),
                          hintText: 'Insira sua chave da API do Vanna.AI',
                        ),
                        validator: (value) => value!.isEmpty ? 'Informe a API Key' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: modelController,
                        decoration: InputDecoration(
                          labelText: 'Model',
                          border: OutlineInputBorder(),
                          hintText: 'Insira o nome do modelo',
                        ),
                        validator: (value) => value!.isEmpty ? 'Informe o modelo' : null,
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: _buildGradientButton(
                            text: vannaConfigurado ? '✅ Vanna.AI Conectado' : 'Conectar Vanna.AI',
                            onPressed: vannaConfigurado ? null : configurarVanna,
                            isLoading: isLoadingVanna,
                            backgroundColor: vannaConfigurado ? Colors.green : Colors.orange,
                            isEnabled: !vannaConfigurado,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // ETAPA 2: DADOS DO BANCO (MOVIDO PARA BAIXO)
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            bancoCadastrado ? Icons.check_circle : Icons.storage,
                            color: bancoCadastrado ? Colors.green : (vannaConfigurado ? Colors.blue : Colors.grey),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ETAPA 2: DADOS DO BANCO',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: bancoCadastrado ? Colors.green : (vannaConfigurado ? Colors.blue : Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!vannaConfigurado)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Complete primeiro a configuração do Vanna.AI',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Chip(
                            label: Text(tipoBanco == 'postgresql' ? 'PostgreSQL' : 'MySQL'),
                            backgroundColor: tipoBanco == 'postgresql' ? Colors.blue.shade100 : Colors.orange.shade100,
                            avatar: Icon(Icons.storage, size: 16, color: tipoBanco == 'postgresql' ? Colors.blue : Colors.orange),
                          ),
                          SizedBox(width: 10),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Dropdown para seleção do tipo de banco
                      DropdownButtonFormField<String>(
                        value: tipoBanco,
                        decoration: InputDecoration(
                          labelText: 'Tipo do Banco de Dados',
                          border: OutlineInputBorder(),
                          // Adicionar estilo visual quando desabilitado
                          enabled: vannaConfigurado,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'postgresql',
                            child: Row(
                              children: [
                                Icon(Icons.storage, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text('PostgreSQL'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'mysql',
                            child: Row(
                              children: [
                                Icon(Icons.storage, color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Text('MySQL'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: vannaConfigurado ? (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              tipoBanco = newValue;
                              // Resetar status de conexão quando mudar o tipo
                              bancoCadastrado = false;
                            });
                          }
                        } : null, // null desabilita o dropdown
                        validator: (value) => value == null ? 'Selecione o tipo do banco' : null,
                      ),
                      SizedBox(height: 20),
                      TextFormField(
                        controller: dominioController,
                        enabled: vannaConfigurado,
                        decoration: InputDecoration(
                          labelText: 'Domínio/URL',
                          border: OutlineInputBorder(),
                          hintText: tipoBanco == 'mysql' ? 'Ex: localhost ou IP do servidor MySQL' : 'Ex: localhost ou IP do servidor PostgreSQL',
                        ),
                        validator: (value) => value!.isEmpty ? 'Informe o domínio/URL' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: portaController,
                        enabled: vannaConfigurado,
                        decoration: InputDecoration(
                          labelText: 'Porta',
                          border: OutlineInputBorder(),
                          hintText: tipoBanco == 'mysql' ? 'Padrão: 3306' : 'Padrão: 5432',
                        ),
                        validator: (value) => value!.isEmpty ? 'Informe a porta' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: nomeBancoController,
                        enabled: vannaConfigurado,
                        decoration: InputDecoration(
                          labelText: 'Nome do Banco',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value!.isEmpty ? 'Informe o nome do banco' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: usuarioBancoController,
                        enabled: vannaConfigurado,
                        decoration: InputDecoration(
                          labelText: 'Usuário do Banco',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value!.isEmpty ? 'Informe o usuário' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: senhaBancoController,
                        enabled: vannaConfigurado,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Senha do Banco',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value!.isEmpty ? 'Informe a senha' : null,
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: _buildGradientButton(
                            text: bancoCadastrado 
                              ? '✅ Banco Conectado' 
                              : (dadosBancoPreenchidos ? 'Conectar Banco' : 'Salvar Dados do Banco'),
                            onPressed: (!vannaConfigurado || bancoCadastrado) ? null : conectarBanco,
                            isLoading: isLoadingBanco,
                            backgroundColor: bancoCadastrado ? Colors.green : Colors.blue,
                            isEnabled: vannaConfigurado && !bancoCadastrado,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 30),
            
            // BOTÃO TREINAR (só aparece quando tudo estiver configurado)
            if (vannaConfigurado && bancoCadastrado)
              Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 70,
                  child: ElevatedButton(
                    onPressed: _treinarBanco,
                    child: Text(
                      'Treinar Agente',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 12,
                      shadowColor: Colors.green.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      
    );
  }
}
