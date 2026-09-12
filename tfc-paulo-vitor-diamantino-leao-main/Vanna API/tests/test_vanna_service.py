import pytest
from unittest.mock import Mock, patch, MagicMock
from app import VannaService
import pandas as pd
import logging

# Configure logging for test output
logging.basicConfig(
    level=logging.INFO, 
    format='%(message)s',
    force=True,
    handlers=[
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

class TestVannaService:
    
    def test_init(self):
        """Testa inicialização do VannaService"""
        service = VannaService()
        assert service.vn is None
        assert service.is_connected == False
        assert service.db_connected == False
        assert service.last_db_config is None
        assert service.last_api_key is None
        assert service.last_model_name is None
    
    @patch('app.VannaDefault')
    def test_connect_success(self, mock_vanna_default):
        """Testa conexão bem-sucedida"""
        service = VannaService()
        mock_instance = Mock()
        mock_vanna_default.return_value = mock_instance
        
        # Mock do teste de conectividade
        with patch.object(service, '_test_vanna_connectivity') as mock_test:
            mock_test.return_value = (True, "Conectado com sucesso")
            
            success, message = service.connect("test_key", "test_model")
            
            assert success == True
            assert service.is_connected == True
            assert service.vn == mock_instance
            assert service.last_api_key == "test_key"
            assert service.last_model_name == "test_model"
            assert "Conectado com sucesso" in message
    
    def test_connect_invalid_credentials(self):
        """Testa conexão com credenciais inválidas"""
        service = VannaService()
        
        with patch.object(service, '_test_vanna_connectivity') as mock_test:
            error_dict = {
                'title': 'API Key Inválida',
                'message': 'A API Key fornecida não é válida',
                'details': 'Não foi possível autenticar',
                'suggestions': ['Verifique se copiou a API Key completa']
            }
            mock_test.return_value = (False, error_dict)
            
            success, message = service.connect("invalid_key", "test_model")
            
            assert success == False
            assert service.is_connected == False
            assert service.vn is None
            assert "API Key Inválida" in message
    
    def test_connect_missing_parameters(self):
        """Testa conexão com parâmetros faltando"""
        service = VannaService()
        
        # Teste sem API key
        success, message = service.connect(None, "test_model")
        assert success == False
        assert "dados obrigatórios" in message.lower()
        
        # Teste sem model name
        success, message = service.connect("test_key", None)
        assert success == False
        assert "dados obrigatórios" in message.lower()
        
        # Teste com strings vazias
        success, message = service.connect("", "")
        assert success == False
        assert "dados obrigatórios" in message.lower()
    
    @patch('app.VannaDefault')
    def test_connect_exception_handling(self, mock_vanna_default):
        """Testa tratamento de exceções durante conexão"""
        service = VannaService()
        
        # Mock que levanta exceção
        with patch.object(service, '_test_vanna_connectivity') as mock_test:
            mock_test.side_effect = Exception("Erro de rede")
            
            success, message = service.connect("test_key", "test_model")
            
            assert success == False
            assert service.is_connected == False
            assert service.vn is None
    
    def test_classify_error_api_key_invalid(self):
        """Testa classificação de erro de API key inválida"""
        service = VannaService()
        error = Exception("unauthorized")
        
        result = service._classify_error(error, "api_key_invalid")
        
        assert result['title'] == 'API Key Inválida'
        assert 'API Key fornecida não é válida' in result['message']
        assert 'suggestions' in result
        assert len(result['suggestions']) > 0
    
    def test_classify_error_model_not_found(self):
        """Testa classificação de erro de modelo não encontrado"""
        service = VannaService()
        error = Exception("model not found")
        
        result = service._classify_error(error, "model_not_found")
        
        assert result['title'] == 'Modelo Não Encontrado'
        assert 'modelo especificado não existe' in result['message']
        assert 'suggestions' in result
    
    def test_classify_error_connection(self):
        """Testa classificação de erro de conectividade"""
        service = VannaService()
        error = Exception("connection timeout")
        
        result = service._classify_error(error, "connection")
        
        assert result['title'] == 'Problema de Conectividade'
        assert 'conexão com o serviço' in result['message']
        assert 'suggestions' in result
    
    @patch('app.VannaDefault')
    def test_test_vanna_connectivity_success(self, mock_vanna_default):
        """Testa validação de conectividade bem-sucedida"""
        service = VannaService()
        mock_instance = Mock()
        mock_vanna_default.return_value = mock_instance
        
        # Mock dos métodos do Vanna - configurar para não lançar exceções
        mock_instance.get_training_data.return_value = []
        mock_instance.generate_sql.return_value = "SELECT 1"
        mock_instance.train.return_value = True
        mock_instance.remove_training_data.return_value = True
        
        # Mock do método get_model_info se existir
        mock_instance.get_model_info.return_value = {"model": "test_model"}
        
        is_valid, result = service._test_vanna_connectivity("valid_api_key_123", "valid_model")
        
        assert is_valid == True
        assert "Credenciais validadas" in result
    
    def test_test_vanna_connectivity_invalid_format(self):
        """Testa validação com formato inválido"""
        service = VannaService()
        
        # API key muito curta
        is_valid, result = service._test_vanna_connectivity("short", "model")
        assert is_valid == False
        assert isinstance(result, dict)
        assert "API Key" in result['title']
        
        # Model name vazio
        is_valid, result = service._test_vanna_connectivity("valid_api_key", "")
        assert is_valid == False
        assert isinstance(result, dict)
    
    def test_connect_to_database_not_connected_to_vanna(self):
        """Testa conexão ao banco sem estar conectado ao Vanna"""
        logger.info("TESTE DE BANCO: Verificando erro quando não conectado ao Vanna")
        service = VannaService()
        db_config = {
            'db_type': 'mysql',
            'host': 'localhost',
            'database': 'test_db',
            'user': 'test_user',
            'password': 'test_pass'
        }
        
        result = service.connect_to_database(db_config)
        assert result == False
        logger.info("Erro de pré-requisito (Vanna não conectado) detectado corretamente")
    
    def test_connect_to_database_mysql_success(self):
        """Testa conexão bem-sucedida ao MySQL"""
        logger.info("TESTE DE BANCO: Verificando conexão bem-sucedida com MySQL")
        service = VannaService()
        service.is_connected = True
        service.vn = Mock()
        
        db_config = {
            'db_type': 'mysql',
            'host': 'localhost',
            'database': 'test_db',
            'user': 'test_user',
            'password': 'test_pass',
            'port': 3306
        }
        
        service.vn.connect_to_mysql = Mock(return_value=True)
        
        result = service.connect_to_database(db_config)
        
        assert result == True
        assert service.db_connected == True
        assert service.last_db_config == db_config
        service.vn.connect_to_mysql.assert_called_once()
        logger.info("Conexão MySQL estabelecida com sucesso")
    
    def test_connect_to_database_postgresql_success(self):
        """Testa conexão bem-sucedida ao PostgreSQL"""
        logger.info("TESTE DE BANCO: Verificando conexão bem-sucedida com PostgreSQL")
        service = VannaService()
        service.is_connected = True
        service.vn = Mock()
        
        db_config = {
            'db_type': 'postgresql',
            'host': 'localhost',
            'database': 'test_db',
            'user': 'test_user',
            'password': 'test_pass',
            'port': 5432
        }
        
        service.vn.connect_to_postgres = Mock(return_value=True)
        
        result = service.connect_to_database(db_config)
        
        assert result == True
        assert service.db_connected == True
        service.vn.connect_to_postgres.assert_called_once()
        logger.info("Conexão PostgreSQL estabelecida com sucesso")
    
    def test_connect_to_database_sqlite_success(self):
        """Testa conexão bem-sucedida ao SQLite"""
        logger.info("TESTE DE BANCO: Verificando conexão bem-sucedida com SQLite")
        service = VannaService()
        service.is_connected = True
        service.vn = Mock()
        
        db_config = {
            'db_type': 'sqlite',
            'database': '/path/to/test.db'
        }
        
        service.vn.connect_to_sqlite = Mock(return_value=True)
        
        result = service.connect_to_database(db_config)
        
        assert result == True
        assert service.db_connected == True
        service.vn.connect_to_sqlite.assert_called_once_with('/path/to/test.db')
        logger.info("Conexão SQLite estabelecida com sucesso")
    
    def test_connect_to_database_unsupported_type(self):
        """Testa conexão com tipo de banco não suportado"""
        logger.info("TESTE DE BANCO: Verificando tratamento de tipos de banco não suportados")
        service = VannaService()
        service.is_connected = True
        service.vn = Mock()
        
        db_config = {
            'db_type': 'oracle',
            'host': 'localhost'
        }
        
        result = service.connect_to_database(db_config)
        assert result == False
        assert service.db_connected == False
        logger.info("Tipo de banco não suportado detectado e tratado corretamente")
    
    def test_verify_connections_all_connected(self):
        """Testa verificação quando todas as conexões estão ativas"""
        service = VannaService()
        service.is_connected = True
        service.db_connected = True
        service.vn = Mock()
        
        # Mock dos métodos de teste
        service.vn.get_training_data.return_value = []
        service.vn.run_sql.return_value = pd.DataFrame({'test_connection': [1]})
        
        is_ok, message = service._verify_connections()
        
        assert is_ok == True
        assert "Todas as conexões estão ativas" in message
    
    def test_verify_connections_vanna_not_connected(self):
        """Testa verificação quando Vanna não está conectado"""
        service = VannaService()
        service.is_connected = False
        service.db_connected = True
        
        is_ok, message = service._verify_connections()
        
        assert is_ok == False
        assert "Não conectado ao Vanna.AI" in message
    
    def test_verify_connections_db_not_connected(self):
        """Testa verificação quando banco não está conectado"""
        service = VannaService()
        service.is_connected = True
        service.db_connected = False
        service.vn = Mock()
        service.vn.get_training_data.return_value = []
        
        is_ok, message = service._verify_connections()
        
        assert is_ok == False
        assert "Não conectado ao banco de dados" in message
    
    def test_verify_connections_vanna_connection_lost(self):
        """Testa verificação quando conexão com Vanna é perdida"""
        service = VannaService()
        service.is_connected = True
        service.db_connected = True
        service.vn = Mock()
        
        # Mock que simula perda de conexão
        service.vn.get_training_data.side_effect = Exception("Connection lost")
        
        is_ok, message = service._verify_connections()
        
        assert is_ok == False
        assert service.is_connected == False
        assert "Conexão com Vanna.AI perdida" in message
    
    def test_verify_connections_db_connection_lost(self):
        """Testa verificação quando conexão com banco é perdida"""
        service = VannaService()
        service.is_connected = True
        service.db_connected = True
        service.vn = Mock()
        
        # Vanna OK, mas banco com problema
        service.vn.get_training_data.return_value = []
        service.vn.run_sql.side_effect = Exception("Database connection lost")
        
        is_ok, message = service._verify_connections()
        
        assert is_ok == False
        assert service.db_connected == False
        assert "Conexão com banco de dados perdida" in message
    
    def test_attempt_reconnection_success(self):
        """Testa tentativa de reconexão bem-sucedida"""
        service = VannaService()
        service.is_connected = False
        service.db_connected = False
        service.last_api_key = "test_key"
        service.last_model_name = "test_model"
        service.last_db_config = {'db_type': 'mysql'}
        
        with patch.object(service, 'connect') as mock_connect, \
             patch.object(service, 'connect_to_database') as mock_connect_db:
            
            mock_connect.return_value = True
            mock_connect_db.return_value = True
            
            result = service._attempt_reconnection()
            
            assert result == True
            mock_connect.assert_called_once_with("test_key", "test_model")
            mock_connect_db.assert_called_once_with({'db_type': 'mysql'})
    
    def test_attempt_reconnection_no_saved_credentials(self):
        """Testa tentativa de reconexão sem credenciais salvas"""
        service = VannaService()
        service.is_connected = False
        service.db_connected = False
        # Sem credenciais salvas
        
        result = service._attempt_reconnection()
        
        assert result == False
    
    def test_attempt_reconnection_exception(self):
        """Testa tratamento de exceção durante reconexão"""
        service = VannaService()
        service.is_connected = False
        service.last_api_key = "test_key"
        service.last_model_name = "test_model"
        
        with patch.object(service, 'connect') as mock_connect:
            mock_connect.side_effect = Exception("Reconnection failed")
            
            result = service._attempt_reconnection()
            
            assert result == False