import json
import logging
import os
import traceback

from flask import Flask, request, jsonify
from flask_cors import CORS
from vanna.remote import VannaDefault
import pandas as pd
import requests  # Adicionar esta importação
import vanna as vn


# Constantes
DEFAULT_VALUE_3306 = 3306
DEFAULT_VALUE_5432 = 5432
DEFAULT_VALUE_80 = 80
DEFAULT_VALUE_5000 = 5000
DEFAULT_VALUE_400 = 400

app = Flask(__name__)
CORS(app)

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# URL do backend Node.js
NODE_BACKEND_URL = "http://91.108.125.253:3000"

# Função para buscar credenciais do usuário
def fetch_user_credentials(user_id):
    """Busca as credenciais do usuário no backend Node.js"""
    try:
        response = requests.get(f"{NODE_BACKEND_URL}/api/credenciais/{user_id}")
        if response.status_code == 200:
            return response.json()
        else:
            logger.error(f"Erro ao buscar credenciais do usuário {user_id}: {response.status_code}")
            return None
    except Exception as e:
        logger.error(f"Erro na requisição para buscar credenciais: {str(e)}")
        return None

# Configuração do Vanna
class VannaService:
    def __init__(self):
        self.vn = None
        self.is_connected = False
        self.db_connected = False
        self.last_db_config = None
        self.last_api_key = None
        self.last_model_name = None

    def _test_vanna_connectivity(self, api_key, model_name):
        """Testa se as credenciais realmente funcionam com o Vanna.AI"""
        try:
            # Validação básica de formato
            if not api_key or len(api_key) < 10:
                return \
                    False, self._classify_error(Exception("API Key muito curta ou inválida"), "api_key_format")

            if not model_name or len(model_name.strip()) == 0:
                return \
                    False, self._classify_error(Exception("Nome do modelo vazio"), "model_name_format")

            # Cria uma instância temporária para teste
            test_vn = VannaDefault(model=model_name, api_key=api_key)

            logger.info("🔍 Testando conectividade com Vanna.AI...")

            # Teste 1: Validar API Key - Tentar acessar dados de treinamento
            try:
                training_data = test_vn.get_training_data()
                logger.info("✅ Teste 1 passou: API Key válida")
            except Exception as e:
                error_msg = str(e).lower()
                if any(keyword in error_msg for keyword in \
                        ["unauthorized", "invalid api key", "forbidden", "401", "403"]):
                    logger.error(f"❌ Teste 1 falhou: API Key inválida - {str(e)}")
                    return False, self._classify_error(e, "api_key_invalid")
                else:
                    # Se falhou por outro motivo, pode ser problema de rede
                    logger.error(f"❌ Teste 1 falhou: Erro de conectividade - {str(e)}")
                    return False, self._classify_error(e, "connection")

            # Teste 2: Validar se o modelo existe e é acessível
            try:
                # Tenta obter informações específicas do modelo
                model_info = \
                    test_vn.get_model_info() if hasattr(test_vn, 'get_model_info') else None

                # Teste alternativo: tentar uma operação que requer o modelo específico
                test_vn.generate_sql("SELECT 1", allow_llm_to_see_data=False)
                logger.info("✅ Teste 2 passou: Modelo acessível")

            except Exception as e:
                error_msg = str(e).lower()
                if any(keyword in error_msg for keyword in \
                        ["model not found", "invalid model", "model does not exist", "404"]):
                    logger.error(f"❌ Teste 2 falhou: Modelo não encontrado - {str(e)}")
                    return False, self._classify_error(e, "model_not_found")
                elif any(keyword in error_msg for keyword in ["no training data", "model not trained", "insufficient training"]):
                    # Se o erro é sobre falta de treinamento, o modelo existe mas não foi treinado
                    logger.info("✅ Teste 2 passou: Modelo existe (não treinado ainda)")
                else:
                    # Outros erros podem indicar problemas de permissão ou conectividade
                    logger.error(f"❌ Teste 2 falhou: Erro inesperado - {str(e)}")
                    return False, self._classify_error(e, "model_access")

            # Teste 3: Verificar permissões de escrita (opcional, mas importante)
            try:
                # Tenta uma operação que requer permissão de escrita
                # Nota: Este teste pode ser removido se causar problemas
                test_ddl = "-- Test DDL for validation"
                test_vn.train(ddl=test_ddl)
                logger.info("✅ Teste 3 passou: Permissões de escrita OK")

                # Remove o DDL de teste imediatamente
                try:
                    test_vn.remove_training_data(test_ddl)
                except Exception:
                    pass  # Ignora erro ao remover

            except Exception as e:
                error_msg = str(e).lower()
                if any(keyword in error_msg for keyword in \
                        ["permission denied", "forbidden", "read-only", "403"]):
                    logger.warning(f"⚠️ Teste 3: Permissões limitadas - {str(e)}")
                    # Não falha aqui, apenas avisa
                else:
                    logger.info("✅ Teste 3: Permissões adequadas (erro esperado)")

            logger.info("🎉 Validação de credenciais concluída com sucesso!")
            return True, "Credenciais validadas e conectividade confirmada"

        except Exception as e:
            logger.error(f"💥 Erro durante teste de conectividade: {str(e)}")
            return False, self._classify_error(e, "connection")

    # TODO: Considere quebrar esta função em funções menores
    # Função atual tem 86 linhas
    def _classify_error(self, error, test_type):
        """Classifica erros e retorna mensagens específicas"""
        error_msg = str(error).lower()

        if test_type in ["api_key_invalid", "api_key_format"] or any(keyword in error_msg for keyword in ["unauthorized", "invalid api key", "forbidden", "401", "403"]):
            return {
                'title': 'API Key Inválida',
                'message': 'A API Key fornecida não é válida ou não tem permissões adequadas.',
                'details': 'Não foi possível autenticar com o serviço Vanna.AI usando esta API Key.',
                'suggestions': [
                    'Verifique se copiou a API Key completa do painel Vanna.AI',
                    'Confirme se a API Key não expirou',
                    'Certifique-se de que tem permissões de leitura/escrita',
                    'Tente gerar uma nova API Key no painel',
                    'Verifique se a API Key está no formato correto (vn-xxxxxxxxx)'
                ]
            }

        elif test_type in ["model_not_found", "model_name_format"] or any(keyword in error_msg for keyword in ["model not found", "invalid model", "model does not exist", "404"]):
            return {
                'title': 'Modelo Não Encontrado',
                'message': 'O modelo especificado não existe na sua conta Vanna.AI.',
                'details': 'O nome do modelo não foi encontrado nos seus modelos disponíveis.',
                'suggestions': [
                    'Verifique o nome exato do modelo no painel Vanna.AI',
                    'Confirme se o modelo foi criado corretamente',
                    'Lembre-se que nomes são case-sensitive',
                    'Crie um novo modelo se necessário',
                    'Verifique se você tem acesso ao modelo especificado'
                ]
            }

        elif test_type == "model_access":
            return {
                'title': '🚫 Acesso ao Modelo Negado',
                'message': 'Não foi possível acessar o modelo especificado.',
                'details': 'O modelo existe mas você pode não ter permissões adequadas.',
                'suggestions': [
                    'Verifique se você é o proprietário do modelo',
                    'Confirme se tem permissões de leitura no modelo',
                    'Verifique se o modelo não está bloqueado',
                    'Entre em contato com o administrador da conta'
                ]
            }

        elif ("connection" in error_msg or "network" in error_msg or 
              "timeout" in error_msg or test_type == "connection"):
            return {
                'title': 'Problema de Conectividade',
                'message': 'Não foi possível estabelecer conexão com o serviço Vanna.AI.',
                'details': 'Problema de rede ou indisponibilidade temporária do serviço.',
                'suggestions': [
                    'Verifique sua conexão com a internet',
                    'Tente novamente em alguns minutos',
                    'Verifique se não há firewall bloqueando',
                    'Consulte o status do serviço Vanna.AI',
                    'Verifique se o proxy/VPN não está interferindo'
                ]
            }

        else:
            return {
                'title': '❌ Erro de Validação',
                'message': 'Ocorreu um problema durante a validação das credenciais.',
                'details': f'Erro técnico: {str(error)}',
                'suggestions': [
                    'Verifique suas credenciais novamente',
                    'Tente reconectar em alguns minutos',
                    'Consulte a documentação do Vanna.AI',
                    'Entre em contato com o suporte se persistir'
                ]
            }

    # TODO: Considere quebrar esta função em funções menores
    # Função atual tem 73 linhas
    def _verify_connections(self):
        """Verifica se ambas as conexões (Vanna e DB) estão ativas"""
        try:
            # Verifica conexão com Vanna.AI
            if not self.is_connected or not self.vn:
                return False, "Não conectado ao Vanna.AI. Use o endpoint /connect primeiro."

            # Testa a conexão com Vanna fazendo uma operação simples
            try:
                self.vn.get_training_data()
            except Exception as e:
                logger.warning(f"Conexão com Vanna.AI perdida: {str(e)}")
                self.is_connected = False
                return False, "Conexão com Vanna.AI perdida. Reconecte usando /connect."

            # Verifica conexão com banco de dados
            if not self.db_connected:
                return \
                    False, "Não conectado ao banco de dados. Use o endpoint /connect-database primeiro."

            # Testa a conexão com o banco fazendo uma query simples
            try:
                self.vn.run_sql("SELECT 1 as test_connection LIMIT 1")
            except Exception as e:
                logger.warning(f"Conexão com banco perdida: {str(e)}")
                self.db_connected = False
                return \
                    False, "Conexão com banco de dados perdida. Reconecte usando /connect-database."

            return True, "Todas as conexões estão ativas"

        except Exception as e:
            logger.error(f"Erro ao verificar conexões: {str(e)}")
            return False, f"Erro ao verificar conexões: {str(e)}"

    def _attempt_reconnection(self):
        """Tenta reconectar automaticamente usando as últimas configurações salvas"""
        try:
            reconnected = False

            # Reconecta ao Vanna.AI se necessário e se temos as credenciais
            if not self.is_connected and self.last_api_key and self.last_model_name:
                logger.info("Tentando reconectar ao Vanna.AI...")
                if self.connect(self.last_api_key, self.last_model_name):
                    logger.info("Reconexão com Vanna.AI bem-sucedida")
                    reconnected = True

            # Reconecta ao banco se necessário e se temos a configuração
            if not self.db_connected and self.last_db_config:
                logger.info("Tentando reconectar ao banco de dados...")
                if self.connect_to_database(self.last_db_config):
                    logger.info("Reconexão com banco bem-sucedida")
                    reconnected = True

            return reconnected
        except Exception as e:
            logger.error(f"Erro na tentativa de reconexão: {str(e)}")
            return False

    def connect(self, api_key=None, model_name=None):
        """Conecta ao Vanna.AI com validação completa de credenciais"""
        try:
            if not api_key or not model_name:
                return \
                    False, "🔧 Dados obrigatórios: Por favor, forneça a API Key e o nome do modelo."

            logger.info(f"🚀 Iniciando validação de credenciais para modelo: {model_name}")

            # Testa a conectividade real antes de definir como conectado
            is_valid, validation_result = self._test_vanna_connectivity(api_key, model_name)

            if not is_valid:
                self.is_connected = False
                self.vn = None

                # Formata mensagem de erro baseada no resultado da validação
                if isinstance(validation_result, dict):
                    error_msg = \
                        f"{validation_result['title']}\n\n{validation_result['message']}\n{validation_result['details']}\n\n💡 Sugestões:\n"
                    error_msg += "\n".join([f"• {s}" for s in validation_result['suggestions']])
                    return False, error_msg
                else:
                    return False, str(validation_result)

            # Se chegou até aqui, as credenciais são válidas
            logger.info("✅ Credenciais validadas! Estabelecendo conexão...")

            # Agora cria a instância oficial
            self.vn = VannaDefault(model=model_name, api_key=api_key)

            # Salva as credenciais para reconexão futura
            self.last_api_key = api_key
            self.last_model_name = model_name
            self.is_connected = True

            logger.info(f"🎉 Conectado ao Vanna.AI com sucesso - Modelo: {model_name}")
            return \
                True, f"✅ Conectado com sucesso ao Vanna.AI!\n📋 Modelo: {model_name}\n🔑 API Key validada"

        except Exception as e:
            logger.error(f"💥 Erro inesperado durante conexão: {str(e)}")
            self.is_connected = False
            self.vn = None

            # Classifica erro inesperado
            error_info = self._classify_error(e, "connection")
            error_msg = \
                f"{error_info['title']}\n\n{error_info['message']}\n{error_info['details']}\n\n💡 Sugestões:\n"
            error_msg += "\n".join([f"• {s}" for s in error_info['suggestions']])

            return False, error_msg

    # TODO: Considere quebrar esta função em funções menores
    # Função atual tem 53 linhas
    def connect_to_database(self, db_config):
        """Conecta ao banco de dados"""
        try:
            if not self.is_connected or not self.vn:
                raise ValueError("Não conectado ao Vanna.AI. Use o endpoint /connect primeiro.")

            # Suporta tanto 'type' quanto 'db_type'
            db_type = db_config.get('db_type', db_config.get('type', '')).lower()

            if db_type == 'mysql':
                # URL encode da senha se contiver caracteres especiais
                from urllib.parse import quote_plus
                password = quote_plus(str(db_config['password']))
                connection_string = \
                    f"mysql+pymysql://{db_config['user']}:{password}@{db_config['host']}:{db_config.get('port', 3306)}/{db_config['database']}?ssl_disabled=true"
                self.vn.connect_to_mysql(
                    host=db_config['host'],
                    dbname=db_config['database'],
                    user=db_config['user'],
                    password=db_config['password'],
                    port=db_config.get('port', 3306),

                )
            elif db_type == 'postgresql':
                # URL encode da senha se contiver caracteres especiais
                from urllib.parse import quote_plus
                password = quote_plus(str(db_config['password']))
                connection_string = \
                    f"postgresql://{db_config['user']}:{password}@{db_config['host']}:{db_config.get('port', 5432)}/{db_config['database']}"
                self.vn.connect_to_postgres(
                    host=db_config['host'],
                    dbname=db_config['database'],
                    user=db_config['user'],
                    password=db_config['password'],
                    port=db_config.get('port', 5432)
                )
            elif db_type == 'sqlite':
                connection_string = f"sqlite:///{db_config['database']}"
                self.vn.connect_to_sqlite(
                    db_config['database']
                )
            else:
                raise ValueError(f"Tipo de banco não suportado: {db_type}")

            # Configura allow_llm_to_see_data após a conexão
            try:
                if hasattr(self.vn, 'allow_llm_to_see_data'):
                    self.vn.allow_llm_to_see_data = True
                    logger.info("allow_llm_to_see_data configurado para True")
            except Exception as e:
                logger.warning(f"Não foi possível configurar allow_llm_to_see_data: {e}")

            logger.info(f"Conectado ao banco de dados: {db_type}")
            logger.info(f"String de conexão: {connection_string}")

            # Salva a configuração para reconexão futura
            self.last_db_config = db_config.copy()
            self.db_connected = True

            logger.info(f"Conectado ao banco de dados: {db_type}")
            logger.info(f"String de conexão: {connection_string}")
            return True
        except Exception as e:
            logger.error(f"Erro ao conectar ao banco: {str(e)}")
            self.db_connected = False
            return False

    # TODO: Considere quebrar esta função em funções menores
    # Função atual tem 67 linhas
    def train_on_ddl_robust(self, ddl_statements):
        """Treina o modelo com DDL statements - versão robusta para bancos grandes"""
        import time
        import json

        try:
            if not self.is_connected:
                raise ValueError("Não conectado ao Vanna.AI")

            total_ddls = len(ddl_statements)
            successful_trainings = 0
            failed_trainings = 0

            logger.info(f"🚀 Iniciando treinamento robusto com {total_ddls} DDL statements")

            for i, ddl in enumerate(ddl_statements, 1):
                logger.info(f"📝 Processando DDL {i}/{total_ddls}...")

                # Validações antes do envio
                if not ddl or not ddl.strip():
                    logger.warning(f"⚠️ DDL {i} está vazio, pulando...")
                    continue

                # Limitar tamanho do DDL (evitar statements muito grandes)
                if len(ddl) > 10000:  # 10KB limit
                    logger.warning(f"⚠️ DDL {i} muito grande ({len(ddl)} chars), dividindo...")
                    # Dividir DDL grande em partes menores
                    ddl_parts = self._split_large_ddl(ddl)
                    for part_idx, part in enumerate(ddl_parts):
                        success = self._train_single_ddl(part, f"{i}.{part_idx+1}")
                        if success:
                            successful_trainings += 1
                        else:
                            failed_trainings += 1
                    continue

                # Treinar DDL individual
                success = self._train_single_ddl(ddl, str(i))
                if success:
                    successful_trainings += 1
                else:
                    failed_trainings += 1

                # Pausa progressiva (mais longa para bancos grandes)
                pause_time = min(2.0, 0.5 + (i * 0.01))  # Aumenta gradualmente
                time.sleep(pause_time)

                # Log de progresso a cada 10 DDLs
                if i % 10 == 0:
                    logger.info(f"📊 Progresso: {i}/{total_ddls} ({(i/total_ddls)*100:.1f}%)")
            success_rate = (successful_trainings / total_ddls) * 100 if total_ddls > 0 else 0
            logger.info(
                f"✅ Treinamento concluído: {successful_trainings} sucessos, {failed_trainings} falhas ({success_rate:.1f}% sucesso)")

            # Considerar sucesso se pelo menos 80% dos DDLs foram treinados
            return success_rate >= 80.0

        except Exception as e:
            logger.error(f"❌ Erro geral no treinamento robusto: {str(e)}")
            return False

    # TODO: Considere quebrar esta função em funções menores
    # Função atual tem 61 linhas
    def _train_single_ddl(self, ddl, ddl_id):
        """Treina um único DDL com retry e tratamento de erro"""
        import time

        max_retries = 3
        base_delay = 1.0

        for attempt in range(max_retries):
            try:
                logger.debug(f"🔄 Tentativa {attempt+1}/{max_retries} para DDL {ddl_id}")

                # Timeout personalizado para cada tentativa
                start_time = time.time()
                result = self.vn.train(ddl=ddl)
                elapsed_time = time.time() - start_time

                # Verificar se a resposta é válida
                if result is not None:
                    logger.info(f"✅ DDL {ddl_id} treinado com sucesso em {elapsed_time:.2f}s")
                    return True
                else:
                    logger.warning(
                        f"⚠️ DDL {ddl_id} retornou resposta vazia (tentativa {attempt+1})")

            except json.JSONDecodeError as json_err:
                logger.error(
                    f"❌ Erro JSON no DDL {ddl_id} (tentativa {attempt+1}): {str(json_err)}")
                if attempt == max_retries - 1:
                    logger.error(
                        f"💀 DDL {ddl_id} falhou definitivamente após {max_retries} tentativas")
                    return False

            except Exception as e:
                logger.error(f"❌ Erro no DDL {ddl_id} (tentativa {attempt+1}): {str(e)}")
                if attempt == max_retries - 1:
                    return False

            # Delay exponencial entre tentativas
            delay = base_delay * (2 ** attempt)
            logger.info(f"⏳ Aguardando {delay}s antes da próxima tentativa...")
            time.sleep(delay)
        return False

    def _split_large_ddl(self, ddl):
        """Divide DDLs muito grandes em partes menores"""
        # Dividir por statements (;)
        statements = [stmt.strip() for stmt in ddl.split(';') if stmt.strip()]

        parts = []
        current_part = ""

        for stmt in statements:
            if len(current_part + stmt) > 5000:  # 5KB por parte
                if current_part:
                    parts.append(current_part.rstrip() + ';')
                current_part = stmt + ';'
            else:
                current_part += stmt + ';'

        if current_part:
            parts.append(current_part)

        return parts

    def train_on_documentation(self, documentation):
        """Versão com melhor tratamento de erros"""
        try:
            if not self.is_connected:
                raise ValueError("Não conectado ao Vanna.AI")

            if not documentation or len(documentation) == 0:
                logger.warning("Lista de documentação vazia")
                return False

            successful_docs = 0
            for i, doc in enumerate(documentation):
                try:
                    if doc and doc.strip():  # Verificar se não está vazio
                        self.vn.train(documentation=doc)
                        successful_docs += 1
                    else:
                        logger.warning(f"Documentação {i+1} está vazia")
                except Exception as doc_error:
                    logger.error(f"Erro ao treinar documentação {i+1}: {str(doc_error)}")
                    continue

            if successful_docs > 0:
                logger.info(
                    f"Treinamento concluído com {successful_docs}/{len(documentation)} documentações")
                return True
            else:
                logger.error("Nenhuma documentação foi treinada com sucesso")
                return False

        except Exception as e:
            logger.error(f"Erro no treinamento de documentação: {str(e)}")
            return False

    def train_on_sql(self, sql_data):
        """Treina o modelo com pares pergunta-SQL"""
        try:
            if not self.is_connected:
                raise ValueError("Não conectado ao Vanna.AI")

            for item in sql_data:
                question = item.get('question')
                sql = item.get('sql')
                if question and sql:
                    self.vn.train(question=question, sql=sql)

            logger.info(f"Treinamento concluído com {len(sql_data)} pares pergunta-SQL")
            return True
        except Exception as e:
            logger.error(f"Erro no treinamento SQL: {str(e)}")
            return False

    def generate_sql(self, question, allow_llm_to_see_data=True):
        """Gera SQL a partir de uma pergunta"""
        try:
            if not self.is_connected:
                raise ValueError("Não conectado ao Vanna.AI")

            sql = self.vn.generate_sql(question, allow_llm_to_see_data=allow_llm_to_see_data)
            return sql
        except Exception as e:
            logger.error(f"Erro ao gerar SQL: {str(e)}")
            return None

    def ask_question(self, question, allow_llm_to_see_data=True):
        """Faz uma pergunta completa (gera SQL e executa) com verificação robusta"""
        try:
            # Verifica conexões e tenta reconectar se necessário
            connections_ok, error_msg = self._verify_connections()

            if not connections_ok:
                logger.warning(f"Problema de conexão detectado: {error_msg}")

                # Tenta reconectar automaticamente APENAS se temos as credenciais salvas
                if self.last_api_key and self.last_model_name and self.last_db_config:
                    logger.info("Tentando reconexão automática...")
                    if self._attempt_reconnection():
                        # Verifica novamente após reconexão
                        connections_ok, error_msg = self._verify_connections()
                        if not connections_ok:
                            return {
                                "question": question,
                                "error": f"Falha na reconexão automática: {error_msg}",
                                "success": False
                            }
                    else:
                        return {
                            "question": question,
                            "error": f"Reconexão automática falhou: {error_msg}",
                            "success": False
                        }
                else:
                    # Não tenta reconectar se não temos as credenciais
                    return {
                        "question": question,
                        "error": error_msg,
                        "success": False
                    }

            # Gera SQL usando Vanna
            sql = self.generate_sql(question, allow_llm_to_see_data)
            if not sql:
                return {
                    "question": question,
                    "error": "Não foi possível gerar SQL para a pergunta",
                    "success": False
                }

            # Executa o SQL e obtém resultado
            result = self.vn.run_sql(sql)

            # Converte resultado para formato serializável
            result_data = None
            if result is not None:
                if isinstance(result, pd.DataFrame):
                    result_data = result.to_dict('records')
                elif hasattr(result, 'to_dict'):
                    result_data = result.to_dict()
                else:
                    result_data = result

            return {
                "question": question,
                "sql": sql,
                "result": result_data,
                "success": result_data is not None,
                "allow_llm_to_see_data": allow_llm_to_see_data
            }

        except Exception as e:
            logger.error(f"Erro ao fazer pergunta: {str(e)}")
            return {
                "question": question,
                "error": str(e),
                "success": False
            }

    # TODO: Considere quebrar esta função em funções menores
    # Função atual tem 73 linhas
    def set_allow_llm_to_see_data(self, allow=True):
        """Configura se o LLM pode ver os dados do banco"""
        try:
            if hasattr(self.vn, 'allow_llm_to_see_data'):
                self.vn.allow_llm_to_see_data = allow
                logger.info(f"allow_llm_to_see_data configurado para: {allow}")
                return True
            else:
                logger.warning(
                    "Propriedade allow_llm_to_see_data não disponível nesta versão do Vanna")
                return False
        except Exception as e:
            logger.error(f"Erro ao configurar allow_llm_to_see_data: {str(e)}")
            return False

# Instância global SEM conexão automática
vanna_service = VannaService()

# Dicionário para armazenar instâncias por usuário
user_services = {}

def validate_user_id():
    """Valida e extrai user_id do request"""
    data = request.get_json()
    if not data:
        raise ValueError("Dados JSON são obrigatórios")

    user_id = data.get('user_id')
    if user_id is None:
        raise ValueError("user_id é obrigatório")

    return user_id, data

def get_user_vanna_service(user_id):
    """Obtém ou cria uma instância VannaService específica para o usuário com suas credenciais"""
    if user_id not in user_services:
        # Buscar credenciais do usuário no backend Node.js
        user_credentials = fetch_user_credentials(user_id)

        if not user_credentials:
            raise ValueError(f"Credenciais não encontradas para o usuário {user_id}")

        # Criar nova instância para o usuário
        user_service = VannaService()

        # Conectar ao Vanna.AI com as credenciais do usuário
        api_key = user_credentials.get('api_key')
        model = user_credentials.get('model')

        if api_key and model:
            success, message = user_service.connect(api_key, model)
            if not success:
                raise ValueError(f"Erro ao conectar ao Vanna.AI para usuário {user_id}: {message}")
        else:
            raise ValueError(f"Credenciais Vanna.AI não configuradas para o usuário {user_id}")

        # Conectar ao banco de dados específico do usuário
        db_config = {
            'db_type': user_credentials.get('tipo_banco').lower(),
            'host': user_credentials.get('dominio_banco'),
            'port': user_credentials.get('porta_banco'),
            'database': user_credentials.get('nome_banco'),
            'user': user_credentials.get('nome_usuario'),
            'password': user_credentials.get('senha_usuario')
        }

        # Validar se todas as credenciais do banco estão presentes
        required_fields = ['host', 'database', 'user', 'password']
        missing_fields = [field for field in required_fields if not db_config.get(field)]

        if missing_fields:
            raise ValueError(f"Credenciais do banco incompletas para usuário {user_id}. Campos faltando: {missing_fields}")

        # Conectar ao banco
        success = user_service.connect_to_database(db_config)
        if not success:
            raise ValueError(f"Erro ao conectar ao banco de dados do usuário {user_id}")

        user_services[user_id] = user_service
        logger.info(f"✅ Serviço criado para usuário {user_id} com banco {db_config['database']}")

    return user_services[user_id]

@app.route('/', methods=['GET'])
def health_check():
    """Endpoint de verificação de saúde"""
    return jsonify({
        'status': 'ok',
        'message': 'Vanna.AI Flask API está funcionando',
        'connected': vanna_service.is_connected
    })

@app.route('/connect', methods=['POST'])
def connect_vanna():
    """Conecta ao Vanna.AI com validação robusta de credenciais"""
    try:
        data = request.get_json()

        if not data:
            return jsonify({
                'success': False,
                'connected': False,
                'error': '📋 Dados Obrigatórios',
                'message': 'Por favor, envie os dados no formato JSON com api_key e model_name.',
                'example': {
                    'api_key': 'vn-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                    'model_name': 'seu_modelo'
                }
            }), 400

        api_key = data.get('api_key')
        model_name = data.get('model_name')

        if not api_key:
            return jsonify({
                'success': False,
                'connected': False,
                'error': '🔑 API Key Obrigatória',
                'message': 'Por favor, forneça sua API Key do Vanna.AI.'
            }), 400

        if not model_name:
            return jsonify({
                'success': False,
                'connected': False,
                'error': '📋 Nome do Modelo Obrigatório',
                'message': 'Por favor, forneça o nome do seu modelo no Vanna.AI.'
            }), 400

        logger.info(f"🔄 Validando credenciais - Modelo: {model_name}")

        # Usa o método connect atualizado com validação robusta
        success, message = vanna_service.connect(api_key, model_name)

        if success:
            logger.info(f"✅ Conexão validada e estabelecida - Modelo: {model_name}")
            return jsonify({
                'success': True,
                'connected': True,
                'message': message,
                'model_name': model_name,
                'is_connected': vanna_service.is_connected,
                'validation_status': 'Credenciais validadas com sucesso'
            }), 200
        else:
            logger.warning(f"❌ Falha na validação - Modelo: {model_name}")
            return jsonify({
                'success': False,
                'connected': False,
                'error': 'Falha na Validação de Credenciais',
                'message': message,
                'validation_status': 'Credenciais inválidas'
            }), 401

    except Exception as e:
        logger.error(f"💥 Erro no endpoint connect: {str(e)}")
        logger.error(f"Traceback: {traceback.format_exc()}")

        return jsonify({
            'success': False,
            'connected': False,
            'error': '⚠️ Erro Interno do Servidor',
            'message': 'Ocorreu um erro inesperado durante a validação. Tente novamente.',
            'technical_details': str(e) if app.debug else None
        }), 500

@app.route('/connect-database', methods=['POST'])
def connect_database():
    """Conecta ao banco de dados"""
    try:
        data = request.get_json()

        if not data:
            return jsonify({'error': 'Configuração do banco é obrigatória'}), 400

        # Verifica se está conectado ao Vanna.AI primeiro
        if not vanna_service.is_connected:
            return \
                jsonify({'error': 'Você deve conectar ao Vanna.AI primeiro usando o endpoint /connect'}), 400

        # Aceita tanto data.database quanto data diretamente
        if 'database' in data and isinstance(data['database'], dict):
            db_config = data['database']
        else:
            db_config = data

        # Verifica se db_config é um dicionário
        if not isinstance(db_config, dict):
            return jsonify({'error': 'Configuração do banco deve ser um objeto JSON'}), 400

        # Verifica se tem os campos necessários
        if not db_config.get('db_type') and not db_config.get('type'):
            return jsonify({'error': 'Tipo de banco (db_type) é obrigatório'}), 400

        success = vanna_service.connect_to_database(db_config)

        if success:
            return jsonify({
                'message': 'Conectado ao banco de dados com sucesso',
                'db_type': db_config.get('db_type', db_config.get('type'))
            })
        else:
            return jsonify({'error': 'Falha ao conectar ao banco de dados'}), 500

    except Exception as e:
        logger.error(f"Erro no endpoint connect-database: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/train', methods=['POST'])
def train_model():
    """Treina o modelo Vanna.AI - aceita qualquer combinação de dados ou nenhum dado específico"""
    try:
        # Permite requisições sem dados JSON
        data = request.get_json() or {}

        if not vanna_service.is_connected:
            return jsonify({'error': 'Não conectado ao Vanna.AI'}), 400

        results = {}
        training_performed = False

        # Treinar com DDL statements (se fornecido)
        if 'ddl_statements' in data and data['ddl_statements']:
            ddl_success = vanna_service.train_on_ddl_robust(data['ddl_statements'])
            results['ddl_training'] = 'success' if ddl_success else 'failed'
            training_performed = True

        # Treinar com documentação (se fornecido)
        if 'documentation' in data and data['documentation']:
            doc_success = vanna_service.train_on_documentation(data['documentation'])
            results['documentation_training'] = 'success' if doc_success else 'failed'
            training_performed = True

        # Treinar com pares pergunta-SQL (se fornecido)
        if 'sql_data' in data and data['sql_data']:
            sql_success = vanna_service.train_on_sql(data['sql_data'])
            results['sql_training'] = 'success' if sql_success else 'failed'
            training_performed = True

        # Se nenhum treinamento específico foi fornecido, retorna sucesso mesmo assim
        if not training_performed:
            return jsonify({
                'message': 'Endpoint de treinamento acessado com sucesso',
                'note': 'Nenhum dado de treinamento específico foi fornecido',
                'available_formats': {
                    'ddl_statements': 'Lista de declarações DDL para treinar estrutura do banco',
                    'documentation': 'Lista de documentação para treinar contexto',
                    'sql_data': 'Lista de objetos com question e sql para treinar pares pergunta-resposta'
                }
            })

        return jsonify({
            'message': 'Treinamento concluído',
            'results': results
        })

    except Exception as e:
        logger.error(f"Erro no endpoint train: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/train-basic', methods=['POST', 'GET'])
def train_basic():
    """Endpoint de treinamento básico - funciona sem nenhum parâmetro"""
    try:
        if not vanna_service.is_connected:
            return jsonify({'error': 'Não conectado ao Vanna.AI'}), 400

        # Aceita tanto GET quanto POST
        data = request.get_json() if request.method == 'POST' else {}

        # Se dados foram fornecidos, usa o treinamento flexível
        if data:
            results = {}
            training_performed = False

            # Treinar com qualquer dado fornecido
            if 'ddl_statements' in data and data['ddl_statements']:
                ddl_success = vanna_service.train_on_ddl_robust(data['ddl_statements'])
                results['ddl_training'] = 'success' if ddl_success else 'failed'
                training_performed = True

            if 'documentation' in data and data['documentation']:
                doc_success = vanna_service.train_on_documentation(data['documentation'])
                results['documentation_training'] = 'success' if doc_success else 'failed'
                training_performed = True

            if 'sql_data' in data and data['sql_data']:
                sql_success = vanna_service.train_on_sql(data['sql_data'])
                results['sql_training'] = 'success' if sql_success else 'failed'
                training_performed = True

            if training_performed:
                return jsonify({
                    'message': 'Treinamento básico concluído',
                    'results': results
                })

        # Treinamento mínimo sem dados específicos
        return jsonify({
            'message': 'Treinamento básico executado com sucesso',
            'status': 'ready',
            'note': 'Modelo pronto para uso. Você pode fornecer dados de treinamento opcionalmente.',
            'connection_status': {
                'vanna_connected': vanna_service.is_connected,
                'ready_for_queries': True
            }
        })

    except Exception as e:
        logger.error(f"Erro no endpoint train-basic: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/generate-sql', methods=['POST'])
def generate_sql():
    """Gera SQL a partir de uma pergunta"""
    try:
        data = request.get_json()

        if not data or 'question' not in data:
            return jsonify({'error': 'Pergunta é obrigatória'}), 400

        if not vanna_service.is_connected:
            return jsonify({'error': 'Não conectado ao Vanna.AI'}), 400

        question = data['question']
        allow_llm_to_see_data = data.get('allow_llm_to_see_data', True)

        sql = vanna_service.generate_sql(question, allow_llm_to_see_data=allow_llm_to_see_data)

        if sql:
            return jsonify({
                'question': question,
                'sql': sql,
                'allow_llm_to_see_data': allow_llm_to_see_data
            })
        else:
            return jsonify({'error': 'Falha ao gerar SQL'}), 500

    except Exception as e:
        logger.error(f"Erro no endpoint generate-sql: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/ask', methods=['POST'])
def ask_question():
    """Faz uma pergunta completa (gera SQL e executa) com isolamento por usuário"""
    try:
        # Validar user_id e obter dados
        user_id, data = validate_user_id()

        if 'question' not in data:
            return jsonify({'error': 'Pergunta é obrigatória'}), 400

        question = data['question']
        allow_llm_to_see_data = data.get('allow_llm_to_see_data', True)

        logger.info(f"🔍 Processando pergunta do usuário {user_id}: {question}")

        # Obter instância específica do usuário (conecta ao banco correto)
        try:
            user_service = get_user_vanna_service(user_id)
        except ValueError as ve:
            return jsonify({
                'error': str(ve),
                'success': False,
                'user_id': user_id
            }), 400

        # Executar pergunta com isolamento por usuário
        result = user_service.ask_question(question, allow_llm_to_see_data)

        # Adicionar informações de debug
        result['user_id'] = user_id
        result['isolated'] = True

        logger.info(f"✅ Pergunta processada para usuário {user_id}")

        if result['success']:
            return jsonify(result)
        else:
            return jsonify(result), 500

    except ValueError as ve:
        return jsonify({'error': str(ve), 'success': False}), 400
    except Exception as e:
        logger.error(
            f"Erro no endpoint ask para usuário {user_id if 'user_id' in locals() else 'desconhecido'}: {str(e)}")
        return jsonify({
            'question': data.get('question', '') if 'data' in locals() else '',
            'error': str(e),
            'success': False
        }), 500

@app.route('/configure-llm-data-access', methods=['POST'])
def configure_llm_data_access():
    """Configura se o LLM pode ver os dados do banco"""
    try:
        data = request.get_json() or {}

        if not vanna_service.is_connected:
            return jsonify({'error': 'Não conectado ao Vanna.AI'}), 400

        allow = data.get('allow_llm_to_see_data', True)

        success = vanna_service.set_allow_llm_to_see_data(allow)

        if success:
            return jsonify({
                'message': f'Configuração atualizada: allow_llm_to_see_data = {allow}',
                'allow_llm_to_see_data': allow,
                'note': 'Esta configuração permite que o LLM veja dados do banco para melhor geração de SQL'
            })
        else:
            return jsonify({
                'message': 'Configuração não suportada nesta versão',
                'allow_llm_to_see_data': allow,
                'note': 'Use o parâmetro allow_llm_to_see_data nos endpoints generate-sql e ask'
            })

    except Exception as e:
        logger.error(f"Erro no endpoint configure-llm-data-access: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/conectar-e-treinar-automatico', methods=['POST'])
def conectar_e_treinar_automatico():
    """Conecta ao banco, extrai DDL automaticamente e treina o modelo"""
    try:
        data = request.get_json()

        if not data:
            return jsonify({'error': 'Dados JSON são obrigatórios'}), 400

        # Extrair dados da requisição
        api_key = data.get('api_key')
        model_name = data.get('model')

        # Limpar o host removendo qualquer '@' indevido
        host_raw = data.get('dominio', '')
        host_clean = host_raw.split('@')[-1] if '@' in host_raw else host_raw

        # Logs para debug
        logger.info(
            f"Dados recebidos - Host: '{data.get('dominio')}', User: '{data.get('usuario')}', Port: '{data.get('porta')}'")
        logger.info(f"Host limpo: '{host_clean}'")

        db_config = {
            'db_type': data.get('tipo_banco', 'mysql'),  # Agora usa o valor correto do frontend
            'host': host_clean,  # Usar o host limpo
            'port': int(data.get('porta', 3306)),  # Porta padrão MySQL (3306) em vez de PostgreSQL (5432)
            'user': data.get('usuario'),  # Mapeia corretamente o campo 'usuario'
            'password': data.get('senha'),  # Mapeia corretamente o campo 'senha'
            'database': data.get('nome_banco')  # Mapeia corretamente o campo 'nome_banco'
        }

        # Tipo de treinamento
        tipo_treinamento = \
            data.get('tipo_treinamento', 'automatico')  # 'automatico' ou 'personalizado'

        # 1. Conectar ao Vanna.AI
        logger.info("Conectando ao Vanna.AI...")
        success = vanna_service.connect(api_key, model_name)
        if not success:
            return jsonify({'error': 'Falha ao conectar ao Vanna.AI'}), 500

        # 2. Conectar ao banco de dados
        logger.info("Conectando ao banco de dados...")
        db_success = vanna_service.connect_to_database(db_config)
        if not db_success:
            return jsonify({'error': 'Falha ao conectar ao banco de dados'}), 500

        results = {}

        if tipo_treinamento == 'automatico':
            # 3. Extrair DDL automaticamente
            logger.info("Extraindo DDL automaticamente...")
            ddl_statements = extrair_ddl_automatico(db_config)

            if ddl_statements:
                # 4. Treinar com DDL extraído
                ddl_success = vanna_service.train_on_ddl_robust(ddl_statements)
                results['ddl_training'] = 'success' if ddl_success else 'failed'
                results['ddl_count'] = len(ddl_statements)

                # 5. Gerar e treinar com documentação inteligente
                logger.info("Gerando documentação inteligente...")
                documentacao_inteligente = gerar_documentacao_inteligente(ddl_statements, db_config)
                if documentacao_inteligente:
                    doc_success = vanna_service.train_on_documentation(documentacao_inteligente)
                    results['documentation_training'] = 'success' if doc_success else 'failed'
                    results['doc_count'] = len(documentacao_inteligente)

                # 6. Gerar e treinar com exemplos SQL contextuais
                logger.info("Gerando exemplos SQL contextuais...")
                sql_exemplos = gerar_sql_exemplos_contextuais(ddl_statements, db_config)
                if sql_exemplos:
                    sql_success = vanna_service.train_on_sql(sql_exemplos)
                    results['sql_training'] = 'success' if sql_success else 'failed'
                    results['sql_examples_count'] = len(sql_exemplos)
            else:
                results['ddl_training'] = 'no_tables_found'

        elif tipo_treinamento == 'personalizado':
            # Treinamento personalizado com dados fornecidos
            training_performed = False

            if 'ddl_statements' in data and data['ddl_statements']:
                ddl_success = vanna_service.train_on_ddl_robust(data['ddl_statements'])
                results['ddl_training'] = 'success' if ddl_success else 'failed'
                training_performed = True

            if 'documentation' in data and data['documentation']:
                doc_success = vanna_service.train_on_documentation(data['documentation'])
                results['documentation_training'] = 'success' if doc_success else 'failed'
                training_performed = True

            if 'sql_data' in data and data['sql_data']:
                sql_success = vanna_service.train_on_sql(data['sql_data'])
                results['sql_training'] = 'success' if sql_success else 'failed'
                training_performed = True

            if not training_performed:
                return jsonify({'error': 'Nenhum dado de treinamento personalizado fornecido'}), 400

        return jsonify({
            'message': 'Conexão e treinamento concluídos com sucesso',
            'tipo_treinamento': tipo_treinamento,
            'results': results,
            'status': 'ready_for_queries'
        })

    except Exception as e:
        logger.error(f"Erro no endpoint conectar-e-treinar-automatico: {str(e)}")
        return jsonify({'error': str(e)}), 500

# TODO: Considere quebrar esta função em funções menores
# Função atual tem 110 linhas
def extrair_ddl_automatico(db_config):
    """Extrai DDL statements automaticamente do banco de dados"""
    try:
        import sqlalchemy
        from sqlalchemy import create_engine, text
        import traceback
        import urllib.parse

        # Criar connection string
        if db_config['db_type'] == 'mysql':
            # Codificar a senha e usuário para evitar problemas com caracteres especiais
            encoded_password = urllib.parse.quote_plus(db_config['password'])
            encoded_user = urllib.parse.quote_plus(db_config['user'])

            connection_string = \
                f"mysql+pymysql://{encoded_user}:{encoded_password}@{db_config['host']}:{db_config['port']}/{db_config['database']}"
        elif db_config['db_type'] == 'postgresql':
            # Codificar a senha para evitar problemas com caracteres especiais
            encoded_password = urllib.parse.quote_plus(db_config['password'])
            encoded_user = urllib.parse.quote_plus(db_config['user'])

            connection_string = \
                f"postgresql://{encoded_user}:{encoded_password}@{db_config['host']}:{db_config['port']}/{db_config['database']}?client_encoding=utf8"
        else:
            logger.error(f"Tipo de banco não suportado: {db_config['db_type']}")
            return []

        logger.info(
            f"Tentando conectar ao banco: {db_config['db_type']} em {db_config['host']}:{db_config['port']}/{db_config['database']}")

        # Criar engine com configurações específicas para PostgreSQL
        if db_config['db_type'] == 'postgresql':
            engine = create_engine(
                connection_string,
                connect_args={
                    "client_encoding": "utf8",
                    "application_name": "vanna_ddl_extractor"
                },
                echo=False
            )
        else:
            engine = create_engine(connection_string)

        ddl_statements = []

        with engine.connect() as conn:
            logger.info("Conexão estabelecida com sucesso")

            if db_config['db_type'] == 'mysql':
                # Obter todas as tabelas
                result = conn.execute(text("SHOW TABLES"))
                tables = [row[0] for row in result]

                # Obter CREATE TABLE para cada tabela
                for table in tables:
                    create_result = conn.execute(text(f"SHOW CREATE TABLE `{table}`"))
                    create_statement = create_result.fetchone()[1]
                    ddl_statements.append(create_statement)

            elif db_config['db_type'] == 'postgresql':
                # Primeiro, vamos listar todos os schemas disponíveis
                schemas_query = """
                SELECT schema_name
                FROM information_schema.schemata
                WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
                ORDER BY schema_name
                """
                schemas_result = conn.execute(text(schemas_query))
                available_schemas = [row[0] for row in schemas_result]
                logger.info(f"Schemas disponíveis no banco: {available_schemas}")

                # Tentar primeiro com o nome do banco como schema
                schema_name = db_config['database']  # unirv456
                logger.info(f"Tentando buscar tabelas no schema: '{schema_name}'")

                # Buscar tabelas no schema específico
                query = """
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = :schema_name AND table_type = 'BASE TABLE'
                ORDER BY table_name
                """
                result = conn.execute(text(query), {'schema_name': schema_name})
                tables = [row[0] for row in result]

                logger.info(
                    f"Encontradas {len(tables)} tabelas no schema '{schema_name}': {tables}")

                # Se não encontrar no schema do banco, tentar buscar em todos os schemas
                if not tables:
                    logger.info(
                        "Nenhuma tabela encontrada no schema do banco, buscando em todos os schemas...")

                    # Buscar em todos os schemas não-sistema
                    for schema in available_schemas:
                        logger.info(f"Verificando schema: {schema}")
                        result_schema = conn.execute(text(query), {'schema_name': schema})
                        schema_tables = [row[0] for row in result_schema]

                        if schema_tables:
                            logger.info(
                                f"Encontradas {len(schema_tables)} tabelas no schema '{schema}': {schema_tables}")
                            # Adicionar tabelas com o schema correto
                            for table in schema_tables:
                                tables.append((schema, table))
                        else:
                            logger.info(f"Nenhuma tabela encontrada no schema '{schema}'")

                    # Se ainda não encontrou nada, tentar uma abordagem mais direta
                    if not tables:
                        logger.info("Tentando abordagem alternativa com pg_tables...")
                        query_all = """
                        SELECT schemaname, tablename
                        FROM pg_tables
                        WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
                        ORDER BY schemaname, tablename
                        """
                        result_all = conn.execute(text(query_all))
                        all_tables = [(row[0], row[1]) for row in result_all]
                        logger.info(f"pg_tables retornou {len(all_tables)} tabelas: {all_tables}")

                        if all_tables:
                            tables = all_tables
                        else:
                            logger.error("Nenhuma tabela encontrada em nenhum schema")
                            return []
                else:
                    # Converter para formato (schema, table)
                    tables = [(schema_name, table) for table in tables]

                logger.info(f"Processando {len(tables)} tabelas para gerar DDL")

                # Gerar DDL para cada tabela
                for schema, table in tables:
                    try:
                        full_table_name = f"{schema}.{table}"
                        logger.info(f"Gerando DDL para: {full_table_name}")

                        columns_query = """
                        SELECT column_name, data_type, is_nullable, column_default,
                               character_maximum_length, numeric_precision, numeric_scale
                        FROM information_schema.columns
                        WHERE table_schema = :schema AND table_name = :table_name
                        ORDER BY ordinal_position
                        """
                        columns_result = \
                            conn.execute(text(columns_query), {'schema': schema, 'table_name': table})
                        columns = columns_result.fetchall()

                        logger.info(f"Encontradas {len(columns)} colunas para {full_table_name}")

                        if columns:  # Só processar se encontrou colunas
                            # Construir CREATE TABLE
                            create_statement = f"CREATE TABLE {full_table_name} (\n"
                            column_definitions = []

                            for col in columns:
                                col_name, data_type, is_nullable, default_val, char_max_len, num_precision, num_scale = \
                                    col

                                # Construir tipo de dados completo
                                if data_type in ['character varying', 'varchar'] and char_max_len:
                                    col_type = f"VARCHAR({char_max_len})"
                                elif data_type in ['character', 'char'] and char_max_len:
                                    col_type = f"CHAR({char_max_len})"
                                elif data_type == 'numeric' and num_precision and num_scale:
                                    col_type = f"NUMERIC({num_precision},{num_scale})"
                                elif data_type == 'numeric' and num_precision:
                                    col_type = f"NUMERIC({num_precision})"
                                else:
                                    col_type = data_type.upper()

                                col_def = f"  {col_name} {col_type}"

                                if is_nullable == 'NO':
                                    col_def += " NOT NULL"
                                if default_val:
                                    col_def += f" DEFAULT {default_val}"

                                column_definitions.append(col_def)

                            create_statement += ",\n".join(column_definitions)
                            create_statement += "\n);"
                            ddl_statements.append(create_statement)

                            logger.info(f"DDL gerado com sucesso para {full_table_name}")
                        else:
                            logger.warning(f"Nenhuma coluna encontrada para {full_table_name}")

                    except Exception as table_error:
                        logger.error(
                            f"Erro ao processar tabela {schema}.{table}: {str(table_error)}")
                        continue

        logger.info(f"Total de {len(ddl_statements)} DDL statements extraídos com sucesso")
        return ddl_statements

    except Exception as e:
        logger.error(f"Erro ao extrair DDL: {str(e)}")
        logger.error(f"Traceback completo: {traceback.format_exc()}")
        return []

# TODO: Considere quebrar esta função em funções menores
# Função atual tem 202 linhas
def gerar_documentacao_basica(ddl_statements):
    """Gera documentação básica a partir dos DDL statements"""
    documentacao = []

    for ddl in ddl_statements:
        # Extrair nome da tabela
        if 'CREATE TABLE' in ddl.upper():
            lines = ddl.split('\n')
            first_line = lines[0]
            table_name = first_line.split('CREATE TABLE')[1].split('(')[0].strip().replace('`', '')

            doc = f"Tabela {table_name}: Armazena dados relacionados a {table_name.lower()}."
            documentacao.append(doc)

    return documentacao

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint não encontrado'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Erro interno do servidor'}), 500

def gerar_documentacao_inteligente(ddl_statements, db_config):
    """Versão simplificada sem conexão adicional"""
    documentacao = []

    try:
        for ddl in ddl_statements:
            if 'CREATE TABLE' in ddl.upper():
                # Análise apenas baseada no DDL, sem conexão
                table_info = analisar_tabela_ddl(ddl)
                table_name = table_info['name']
                columns = table_info['columns']

                # Documentação básica melhorada
                descricao = inferir_proposito_tabela(table_name, columns)
                colunas_importantes = identificar_colunas_importantes(columns)
                exemplos = gerar_exemplos_uso(table_name, columns)

                doc_parts = [
                    f"Tabela {table_name}: {descricao}",
                    f"Colunas principais: {', '.join(colunas_importantes)}" if colunas_importantes else "",
                    f"Exemplos: {exemplos}" if exemplos else ""
                ]

                documentacao.append(" | ".join([p for p in doc_parts if p]))

        return documentacao if documentacao else gerar_documentacao_basica(ddl_statements)

    except Exception as e:
        logger.error(f"Erro na documentação inteligente: {str(e)}")
        return gerar_documentacao_basica(ddl_statements)

def analisar_tabela_ddl(ddl):
    """Analisa um DDL e extrai informações estruturadas"""
    lines = ddl.split('\n')
    first_line = lines[0]
    table_name = first_line.split('CREATE TABLE')[1].split('(')[0].strip().replace('`', '')

    columns = []
    for line in lines[1:-1]:  # Pular primeira e última linha
        line = line.strip()
        if line and not line.startswith(')') and line != '':
            parts = line.split()
            if len(parts) >= 2:
                col_name = parts[0].strip(',').replace('`', '')
                col_type = parts[1] if len(parts) > 1 else 'UNKNOWN'
                columns.append({'name': col_name, 'type': col_type, 'definition': line})

    return {'name': table_name, 'columns': columns}

def inferir_proposito_tabela(table_name, columns):
    """Infere o propósito da tabela baseado no nome e colunas"""
    table_lower = table_name.lower()
    col_names = [col['name'].lower() for col in columns]

    # Padrões comuns
    if 'user' in table_lower or 'usuario' in table_lower:
        return "Armazena informações de usuários do sistema"
    elif 'product' in table_lower or 'produto' in table_lower:
        return "Contém dados de produtos/itens do catálogo"
    elif 'order' in table_lower or 'pedido' in table_lower or 'venda' in table_lower:
        return "Registra pedidos/vendas realizadas"
    elif 'customer' in table_lower or 'cliente' in table_lower:
        return "Mantém dados de clientes"
    elif 'employee' in table_lower or 'funcionario' in table_lower or 'vendedor' in table_lower:
        return "Informações de funcionários/vendedores"
    elif 'category' in table_lower or 'categoria' in table_lower:
        return "Categorização/classificação de itens"
    elif 'payment' in table_lower or 'pagamento' in table_lower:
        return "Dados de pagamentos e transações financeiras"
    elif any(word in col_names for word in ['email', 'phone', 'telefone']):
        return "Dados de contato e informações pessoais"
    elif any(word in col_names for word in ['price', 'preco', 'valor', 'amount']):
        return "Informações financeiras e valores monetários"
    else:
        return f"Dados relacionados a {table_name.lower()}"

def identificar_colunas_importantes(columns):
    """Identifica colunas que são importantes para consultas"""
    importantes = []

    for col in columns:
        col_name = col['name'].lower()
        col_type = col['type'].lower()

        # IDs e chaves
        if 'id' in col_name or 'key' in col_name:
            importantes.append(col['name'])
        # Nomes e descrições
        elif any(word in col_name for word in ['name', 'nome', 'title', 'titulo', 'description', 'descricao']):
            importantes.append(col['name'])
        # Valores monetários
        elif any(word in col_name for word in ['price', 'preco', 'valor', 'amount', 'total']):
            importantes.append(col['name'])
        # Datas
        elif any(word in col_name for word in ['date', 'data', 'created', 'updated', 'time']):
            importantes.append(col['name'])
        # Status
        elif any(word in col_name for word in ['status', 'state', 'active', 'ativo']):
            importantes.append(col['name'])

    return importantes[:5]  # Limitar a 5 colunas mais importantes

def detectar_relacionamentos(table_name, columns, conn, db_config):
    """Detecta relacionamentos com outras tabelas"""
    try:
        relacionamentos = []

        # Buscar foreign keys
        if db_config['type'] == 'postgresql':
            fk_query = """
            SELECT
                kcu.column_name,
                ccu.table_name AS foreign_table_name,
                ccu.column_name AS foreign_column_name
            FROM information_schema.table_constraints AS tc
            JOIN information_schema.key_column_usage AS kcu
                ON tc.constraint_name = kcu.constraint_name
                AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage AS ccu
                ON ccu.constraint_name = tc.constraint_name
                AND ccu.table_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY'
                AND tc.table_name = :table_name
                AND tc.table_schema = :schema_name
            """

            schema_name = db_config['database']
            clean_table_name = table_name.split('.')[-1] if '.' in table_name else table_name

            result = conn.execute(text(fk_query), {
                'table_name': clean_table_name,
                'schema_name': schema_name
            })

            for row in result:
                relacionamentos.append(f"{row[0]} -> {row[1]}.{row[2]}")

        return "; ".join(relacionamentos) if relacionamentos else None

    except Exception as e:
        logger.error(f"Erro ao detectar relacionamentos: {str(e)}")
        return None

def gerar_exemplos_uso(table_name, columns):
    """Gera exemplos de consultas SQL para a tabela"""
    exemplos = []
    col_names = [col['name'] for col in columns]

    # Exemplo básico de SELECT
    if len(col_names) > 0:
        principais = col_names[:3]  # Primeiras 3 colunas
        exemplos.append(f"SELECT {', '.join(principais)} FROM {table_name}")

    # Exemplo com WHERE se tiver ID
    id_cols = [col for col in col_names if 'id' in col.lower()]
    if id_cols:
        exemplos.append(f"SELECT * FROM {table_name} WHERE {id_cols[0]} = ?")

    # Exemplo com COUNT
    exemplos.append(f"SELECT COUNT(*) FROM {table_name}")

    return "; ".join(exemplos[:2])  # Limitar a 2 exemplos

def gerar_sql_exemplos_contextuais(ddl_statements, db_config):
    """Gera exemplos de SQL contextuais para treinamento"""
    sql_data = []

    try:
        for ddl in ddl_statements:
            if 'CREATE TABLE' in ddl.upper():
                table_info = analisar_tabela_ddl(ddl)
                table_name = table_info['name']
                columns = table_info['columns']

                # Gerar perguntas e SQLs baseados no contexto
                exemplos = gerar_perguntas_sql_contextuais(table_name, columns)
                sql_data.extend(exemplos)

        return sql_data

    except Exception as e:
        logger.error(f"Erro ao gerar exemplos SQL contextuais: {str(e)}")
        return []

def gerar_perguntas_sql_contextuais(table_name, columns):
    """Gera perguntas e SQLs específicos para uma tabela"""
    exemplos = []
    col_names = [col['name'] for col in columns]
    table_lower = table_name.lower()

    # Perguntas básicas de contagem
    if 'vendedor' in table_lower or 'employee' in table_lower or 'funcionario' in table_lower:
        exemplos.append({
            "question": f"Quantos vendedores temos cadastrados?",
            "sql": f"SELECT COUNT(*) FROM {table_name};"
        })

        # Se tem coluna de nome
        name_cols = \
            [col for col in col_names if any(word in col.lower() for word in ['name', 'nome'])]
        if name_cols:
            # NOVO: Exemplo para retornar TODOS os vendedores
            exemplos.append({
                "question": f"Mostre todos os vendedores",
                "sql": f"SELECT * FROM {table_name};"
            })

            exemplos.append({
                "question": f"Qual o nome de todos os vendedores?",
                "sql": f"SELECT {name_cols[0]} FROM {table_name};"
            })

            # NOVO: Exemplo específico para "todos os nomes"
            exemplos.append({
                "question": f"Liste o nome completo de todos os vendedores cadastrados",
                "sql": f"SELECT {name_cols[0]} FROM {table_name};"
            })

            exemplos.append({
                "question": f"Qual o vendedor que mais vendeu?",
                "sql": f"SELECT {name_cols[0]}, COUNT(*) as total_vendas FROM {table_name} v JOIN vendas vd ON v.id = \
                    vd.vendedor_id GROUP BY {name_cols[0]} ORDER BY total_vendas DESC LIMIT 1;"
            })

    # NOVO: Bloco específico para tabela de usuários
    elif 'usuario' in table_lower or 'user' in table_lower or 'cliente' in table_lower:
        exemplos.append({
            "question": f"Quantos usuários temos cadastrados?",
            "sql": f"SELECT COUNT(*) FROM {table_name};"
        })

        # Se tem coluna de nome
        name_cols = \
            [col for col in col_names if any(word in col.lower() for word in ['name', 'nome'])]
        if name_cols:
            # Exemplos para retornar TODOS os usuários
            exemplos.append({
                "question": f"Mostre todos os usuários",
                "sql": f"SELECT * FROM {table_name};"
            })

            exemplos.append({
                "question": f"Liste todos os usuários do banco",
                "sql": f"SELECT * FROM {table_name};"
            })

            exemplos.append({
                "question": f"Quero ver todos os usuários cadastrados",
                "sql": f"SELECT * FROM {table_name};"
            })

            exemplos.append({
                "question": f"Listar todos usuarios do banco",
                "sql": f"SELECT * FROM {table_name};"
            })

            exemplos.append({
                "question": f"Qual o nome de todos os usuários?",
                "sql": f"SELECT {name_cols[0]} FROM {table_name};"
            })

            exemplos.append({
                "question": f"Liste o nome completo de todos os usuários cadastrados",
                "sql": f"SELECT {name_cols[0]} FROM {table_name};"
            })

            exemplos.append({
                "question": f"Mostre os nomes de todos os 30 usuários",
                "sql": f"SELECT {name_cols[0]} FROM {table_name};"
            })

        # Se tem coluna de email
        email_cols = [col for col in col_names if 'email' in col.lower()]
        if email_cols:
            exemplos.append({
                "question": f"Liste todos os emails dos usuários",
                "sql": f"SELECT {email_cols[0]} FROM {table_name};"
            })

    elif 'venda' in table_lower or 'order' in table_lower or 'pedido' in table_lower:
        exemplos.append({
            "question": f"Quantas vendas foram realizadas?",
            "sql": f"SELECT COUNT(*) FROM {table_name};"
        })

        # NOVO: Exemplo para retornar TODAS as vendas
        exemplos.append({
            "question": f"Mostre todas as vendas",
            "sql": f"SELECT * FROM {table_name};"
        })

        # Se tem coluna de valor
        value_cols = \
            [col for col in col_names if any(word in col.lower() for word in ['valor', 'price', 'total', 'amount'])]
        if value_cols:
            exemplos.append({
                "question": f"Qual o total de vendas?",
                "sql": f"SELECT SUM({value_cols[0]}) FROM {table_name};"
            })

    elif 'produto' in table_lower or 'product' in table_lower:
        exemplos.append({
            "question": f"Quantos produtos temos?",
            "sql": f"SELECT COUNT(*) FROM {table_name};"
        })

        # NOVO: Exemplos para retornar TODOS os produtos
        exemplos.append({
            "question": f"Mostre todos os produtos",
            "sql": f"SELECT * FROM {table_name};"
        })

        exemplos.append({
            "question": f"Liste todos os produtos cadastrados",
            "sql": f"SELECT * FROM {table_name};"
        })

        # Se tem coluna de preço
        price_cols = \
            [col for col in col_names if any(word in col.lower() for word in ['preco', 'price', 'valor'])]
        if price_cols:
            # NOVO: Exemplo sem LIMIT para todos os produtos
            exemplos.append({
                "question": f"Quais são todos os produtos ordenados por preço?",
                "sql": f"SELECT * FROM {table_name} ORDER BY {price_cols[0]} DESC;"
            })

            # Manter o exemplo com LIMIT para casos específicos
            exemplos.append({
                "question": f"Quais são os 10 produtos mais caros?",
                "sql": f"SELECT * FROM {table_name} ORDER BY {price_cols[0]} DESC LIMIT 10;"
            })

    # NOVO: Exemplos genéricos para qualquer tabela
    exemplos.extend([
        {
            "question": f"Mostre todos os registros da tabela {table_name}",
            "sql": f"SELECT * FROM {table_name};"
        },
        {
            "question": f"Liste todos os dados de {table_name}",
            "sql": f"SELECT * FROM {table_name};"
        },
        {
            "question": f"Exiba completamente todos os registros de {table_name}",
            "sql": f"SELECT * FROM {table_name};"
        }
    ])

    return exemplos

# ... existing code ...

@app.route('/status', methods=['GET'])
def check_status():
    """Verifica o status das conexões"""
    try:
        connections_ok, error_msg = vanna_service._verify_connections()

        return jsonify({
            'vanna_connected': vanna_service.is_connected,
            'db_connected': vanna_service.db_connected,
            'vn_instance': vanna_service.vn is not None,
            'connections_ok': connections_ok,
            'error_msg': error_msg,
            'last_api_key_exists': vanna_service.last_api_key is not None,
            'last_model_name': vanna_service.last_model_name,
            'last_db_config_exists': vanna_service.last_db_config is not None
        })
    except Exception as e:
        logger.error(f"Erro ao verificar status: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/logout', methods=['POST'])
def logout_user():
    """Remove a instância VannaService específica do usuário"""
    try:
        user_id, _ = validate_user_id()

        if user_id in user_services:
            del user_services[user_id]
            return jsonify({'message': f'Usuário {user_id} desconectado com sucesso'})
        else:
            return jsonify({'message': f'Usuário {user_id} não estava conectado'})

    except ValueError as ve:
        return jsonify({'error': str(ve)}), 400
    except Exception as e:
        logger.error(f"Erro no logout: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)