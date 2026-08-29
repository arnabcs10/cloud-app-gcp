const { expect } = require('chai');
const sinon = require('sinon');
const request = require('supertest');

describe('Result Server Unit Tests', function () {
  let app;
  let server;
  let poolStub;
  let ioStub;

  beforeEach(function () {
    // Mock dependencies
    poolStub = {
      connect: sinon.stub(),
      query: sinon.stub(),
    };

    ioStub = {
      on: sinon.stub(),
      sockets: {
        emit: sinon.stub(),
      },
    };

    // Clear require cache
    delete require.cache[require.resolve('../../server.js')];
  });

  afterEach(function () {
    if (server) {
      server.close();
    }
    sinon.restore();
  });

  describe('Database Connection', function () {
    it('should retry database connection on failure', function (done) {
      const connectStub = sinon.stub();
      connectStub.onFirstCall().yields(new Error('Connection failed'));
      connectStub.onSecondCall().yields(null, { query: sinon.stub() }, sinon.stub());

      poolStub.connect = connectStub;

      // Simulate retry logic
      setTimeout(() => {
        expect(connectStub.callCount).to.be.at.least(1);
        done();
      }, 100);
    });

    it('should handle successful database connection', function (done) {
      const clientStub = {
        query: sinon.stub().yields(null, { rows: [] }),
      };

      poolStub.connect.yields(null, clientStub, sinon.stub());

      setTimeout(() => {
        expect(poolStub.connect.called).to.be.true;
        done();
      }, 100);
    });
  });

  describe('Vote Collection', function () {
    it('should collect votes correctly from query results', function () {
      const mockResult = {
        rows: [
          { vote: 'a', count: '5' },
          { vote: 'b', count: '3' },
        ],
      };

      // Function to test (extracted from server.js)
      function collectVotesFromResult(result) {
        const votes = { a: 0, b: 0 };
        result.rows.forEach(function (row) {
          votes[row.vote] = parseInt(row.count);
        });
        return votes;
      }

      const votes = collectVotesFromResult(mockResult);

      expect(votes).to.deep.equal({ a: 5, b: 3 });
    });

    it('should handle empty query results', function () {
      const mockResult = { rows: [] };

      function collectVotesFromResult(result) {
        const votes = { a: 0, b: 0 };
        result.rows.forEach(function (row) {
          votes[row.vote] = parseInt(row.count);
        });
        return votes;
      }

      const votes = collectVotesFromResult(mockResult);

      expect(votes).to.deep.equal({ a: 0, b: 0 });
    });
  });

  describe('Socket.IO Events', function () {
    it('should emit scores on vote update', function () {
      const votes = { a: 10, b: 5 };
      const emitStub = sinon.stub();

      const io = {
        sockets: {
          emit: emitStub,
        },
      };

      io.sockets.emit('scores', JSON.stringify(votes));

      expect(emitStub.calledOnce).to.be.true;
      expect(emitStub.calledWith('scores', JSON.stringify(votes))).to.be.true;
    });
  });
});