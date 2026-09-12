import pytest
import responses
from unittest.mock import Mock, patch
from app import app, VannaService

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

@pytest.fixture
def mock_vanna_service():
    with patch('app.vanna_service') as mock:
        mock.is_connected = False
        mock.db_connected = False
        mock.vn = None
        yield mock

@pytest.fixture
def mock_requests():
    with responses.RequestsMock() as rsps:
        yield rsps