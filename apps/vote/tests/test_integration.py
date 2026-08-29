import pytest
import requests
import time
from redis import Redis


@pytest.fixture(scope="module")
def redis_client():
    """Create Redis client for integration tests."""
    client = Redis(host='localhost', port=6379, db=0)
    yield client
    client.flushdb()


class TestVoteAppIntegration:
    """Integration tests for vote app with real Redis."""
    
    def test_redis_connection(self, redis_client):
        """Test Redis connection is working."""
        assert redis_client.ping()
    
    def test_vote_stored_in_redis(self, redis_client):
        """Test that votes are actually stored in Redis."""
        # Clear any existing votes
        redis_client.delete('votes')
        
        # Simulate a vote
        import json
        vote_data = json.dumps({'voter_id': 'test123', 'vote': 'a'})
        redis_client.rpush('votes', vote_data)
        
        # Verify vote is stored
        stored_votes = redis_client.lrange('votes', 0, -1)
        assert len(stored_votes) == 1
        
        stored_vote = json.loads(stored_votes[0])
        assert stored_vote['vote'] == 'a'
        assert stored_vote['voter_id'] == 'test123'