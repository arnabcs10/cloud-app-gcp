import pytest
from unittest.mock import Mock, patch, MagicMock
import json
from app import app, get_redis


@pytest.fixture
def client():
    """Create a test client for the Flask app."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


@pytest.fixture
def mock_redis():
    """Mock Redis connection."""
    with patch('app.Redis') as mock:
        redis_instance = MagicMock()
        mock.return_value = redis_instance
        yield redis_instance


class TestVoteApp:
    """Test suite for the voting application."""
    
    def test_home_page_get(self, client):
        """Test GET request to home page returns 200."""
        response = client.get('/')
        assert response.status_code == 200
        assert b'vs' in response.data
    
    def test_vote_submission(self, client, mock_redis):
        """Test POST request stores vote in Redis."""
        with patch('app.get_redis', return_value=mock_redis):
            response = client.post('/', data={'vote': 'a'})
            
            assert response.status_code == 200
            assert mock_redis.rpush.called
            
            call_args = mock_redis.rpush.call_args
            vote_data = json.loads(call_args[0][1])
            assert vote_data['vote'] == 'a'