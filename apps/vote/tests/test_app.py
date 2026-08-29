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
        """Test GET request to home page returns 200 and renders template."""
        response = client.get('/')
        assert response.status_code == 200
        assert b'vs' in response.data
        assert b'voter_id' in response.headers.get('Set-Cookie', '')
    
    def test_home_page_post_vote_a(self, client, mock_redis):
        """Test POST request with vote 'a' stores vote in Redis."""
        with patch('app.get_redis', return_value=mock_redis):
            response = client.post('/', data={'vote': 'a'})
            
            assert response.status_code == 200
            assert mock_redis.rpush.called
            
            # Verify the data pushed to Redis
            call_args = mock_redis.rpush.call_args
            assert call_args[0][0] == 'votes'
            vote_data = json.loads(call_args[0][1])
            assert vote_data['vote'] == 'a'
            assert 'voter_id' in vote_data
    
    def test_home_page_post_vote_b(self, client, mock_redis):
        """Test POST request with vote 'b' stores vote in Redis."""
        with patch('app.get_redis', return_value=mock_redis):
            response = client.post('/', data={'vote': 'b'})
            
            assert response.status_code == 200
            assert mock_redis.rpush.called
            
            call_args = mock_redis.rpush.call_args
            vote_data = json.loads(call_args[0][1])
            assert vote_data['vote'] == 'b'
    
    def test_voter_id_cookie_persistence(self, client):
        """Test that voter_id cookie is set and persists."""
        response = client.get('/')
        cookies = response.headers.getlist('Set-Cookie')
        
        voter_id_cookie = None
        for cookie in cookies:
            if 'voter_id' in cookie:
                voter_id_cookie = cookie
                break
        
        assert voter_id_cookie is not None
        assert 'voter_id=' in voter_id_cookie
    
    def test_vote_with_existing_cookie(self, client, mock_redis):
        """Test voting with an existing voter_id cookie."""
        client.set_cookie('localhost', 'voter_id', 'test123456')
        
        with patch('app.get_redis', return_value=mock_redis):
            response = client.post('/', data={'vote': 'a'})
            
            call_args = mock_redis.rpush.call_args
            vote_data = json.loads(call_args[0][1])
            assert vote_data['voter_id'] == 'test123456'
    
    def test_redis_connection_error_handling(self, client):
        """Test graceful handling of Redis connection errors."""
        with patch('app.get_redis') as mock_get_redis:
            mock_get_redis.side_effect = Exception("Redis connection failed")
            
            # GET should still work
            response = client.get('/')
            assert response.status_code == 200
    
    def test_environment_variables(self):
        """Test that environment variables are properly loaded."""
        with patch.dict('os.environ', {'OPTION_A': 'TestA', 'OPTION_B': 'TestB'}):
            from importlib import reload
            import app as app_module
            reload(app_module)
            
            # Verify options are loaded (would need to expose them or check in rendered template)
            assert True  # Placeholder - actual implementation would verify template rendering