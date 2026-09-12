# Vanna.AI Flask API

Uma API Flask que utiliza o Vanna.AI para treinar modelos e gerar consultas SQL a partir de perguntas em linguagem natural.

## Funcionalidades

- **Conexão com Vanna.AI**: Conecta-se ao serviço Vanna.AI usando API key e model name
- **Conexão com Banco de Dados**: Suporte para MySQL, PostgreSQL e SQLite
- **Treinamento de Modelo**: Treina o modelo com DDL statements, documentação e pares pergunta-SQL
- **Geração de SQL**: Gera consultas SQL a partir de perguntas em linguagem natural
- **Execução de Consultas**: Executa consultas e retorna resultados

## Instalação

1. Clone o repositório
2. Instale as dependências:
```bash
pip install -r requirements.txt
```

3. Configure as variáveis de ambiente no arquivo `.env`:
```
VANNA_API_KEY=sua_chave_api_aqui
VANNA_MODEL=nome_do_seu_modelo_aqui
```

4. Execute a aplicação:
```bash
python app.py
```

A API estará disponível em `http://localhost:5000`

## Endpoints

### GET /
Verificação de saúde da API
```json
{
  "status": "ok",
  "message": "Vanna.AI Flask API está funcionando",
  "connected": false
}
```

### POST /connect
Conecta ao Vanna.AI
```json
{
  "api_key": "sua_api_key",
  "model_name": "nome_do_modelo"
}
```

### POST /connect-database
Conecta ao banco de dados
```json
{
  "database": {
    "type": "mysql",
    "host": "localhost",
    "port": 3306,
    "user": "usuario",
    "password": "senha",
    "database": "nome_do_banco"
  }
}
```

Tipos de banco suportados:
- `mysql`: MySQL
- `postgresql`: PostgreSQL  
- `sqlite`: SQLite

### POST /train
Treina o modelo Vanna.AI
```json
{
  "ddl_statements": [
    "CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(100), email VARCHAR(100))",
    "CREATE TABLE orders (id INT PRIMARY KEY, user_id INT, total DECIMAL(10,2))"
  ],
  "documentation": [
    "A tabela users contém informações dos usuários do sistema",
    "A tabela orders contém os pedidos realizados pelos usuários"
  ],
  "sql_data": [
    {
      "question": "Quantos usuários temos?",
      "sql": "SELECT COUNT(*) FROM users"
    },
    {
      "question": "Qual o total de vendas?",
      "sql": "SELECT SUM(total) FROM orders"
    }
  ]
}
```

### POST /generate-sql
Gera SQL a partir de uma pergunta
```json
{
  "question": "Quantos pedidos foram feitos hoje?"
}
```

Resposta:
```json
{
  "question": "Quantos pedidos foram feitos hoje?",
  "sql": "SELECT COUNT(*) FROM orders WHERE DATE(created_at) = CURDATE()"
}
```

### POST /ask
Faz uma pergunta completa (gera SQL e executa)
```json
{
  "question": "Quais são os 5 usuários com mais pedidos?"
}
```

Resposta:
```json
{
  "question": "Quais são os 5 usuários com mais pedidos?",
  "result": {
    "sql": "SELECT u.name, COUNT(o.id) as total_orders FROM users u JOIN orders o ON u.id = o.user_id GROUP BY u.id ORDER BY total_orders DESC LIMIT 5",
    "data": [
      ["João Silva", 15],
      ["Maria Santos", 12],
      ["Pedro Oliveira", 8]
    ]
  }
}
```

## Exemplo de Uso Completo

1. **Conectar ao Vanna.AI:**
```bash
curl -X POST http://localhost:5000/connect \
  -H "Content-Type: application/json" \
  -d '{"api_key": "sua_api_key", "model_name": "seu_modelo"}'
```

2. **Conectar ao banco de dados:**
```bash
curl -X POST http://localhost:5000/connect-database \
  -H "Content-Type: application/json" \
  -d '{
    "database": {
      "type": "mysql",
      "host": "localhost",
      "user": "root",
      "password": "senha",
      "database": "loja"
    }
  }'
```

3. **Treinar o modelo:**
```bash
curl -X POST http://localhost:5000/train \
  -H "Content-Type: application/json" \
  -d '{
    "ddl_statements": [
      "CREATE TABLE produtos (id INT PRIMARY KEY, nome VARCHAR(100), preco DECIMAL(10,2))",
      "CREATE TABLE vendas (id INT PRIMARY KEY, produto_id INT, quantidade INT, data_venda DATE)"
    ],
    "sql_data": [
      {
        "question": "Quantos produtos temos?",
        "sql": "SELECT COUNT(*) FROM produtos"
      }
    ]
  }'
```

4. **Gerar consulta SQL:**
```bash
curl -X POST http://localhost:5000/generate-sql \
  -H "Content-Type: application/json" \
  -d '{"question": "Qual produto mais vendido este mês?"}'
```

## Estrutura do Projeto

```
vanna-api/
├── app.py              # Aplicação Flask principal
├── requirements.txt    # Dependências Python
├── .env               # Variáveis de ambiente
└── README.md          # Documentação
```

## Tratamento de Erros

A API inclui tratamento abrangente de erros com logs detalhados. Todos os endpoints retornam mensagens de erro apropriadas em caso de falha.

## Segurança

- Use variáveis de ambiente para armazenar credenciais sensíveis
- Nunca commite o arquivo `.env` no controle de versão
- Configure CORS adequadamente para produção