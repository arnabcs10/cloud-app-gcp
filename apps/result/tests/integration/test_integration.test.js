const { expect } = require('chai');
const { Client } = require('pg');

describe('Result App Integration Tests', function () {
  let client;

  before(async function () {
    this.timeout(10000);

    client = new Client({
      connectionString:
        process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/postgres',
    });

    await client.connect();

    // Create votes table
    await client.query(`
      CREATE TABLE IF NOT EXISTS votes (
        id SERIAL PRIMARY KEY,
        vote VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
  });

  after(async function () {
    // Clean up
    await client.query('DROP TABLE IF EXISTS votes');
    await client.end();
  });

  beforeEach(async function () {
    // Clear votes before each test
    await client.query('DELETE FROM votes');
  });

  describe('Database Operations', function () {
    it('should insert votes into database', async function () {
      await client.query("INSERT INTO votes (vote) VALUES ('a')");
      await client.query("INSERT INTO votes (vote) VALUES ('b')");
      await client.query("INSERT INTO votes (vote) VALUES ('a')");

      const result = await client.query('SELECT vote, COUNT(id) AS count FROM votes GROUP BY vote');

      expect(result.rows).to.have.lengthOf(2);

      const voteCounts = {};
      result.rows.forEach((row) => {
        voteCounts[row.vote] = parseInt(row.count);
      });

      expect(voteCounts).to.deep.equal({ a: 2, b: 1 });
    });

    it('should handle empty votes table', async function () {
      const result = await client.query('SELECT vote, COUNT(id) AS count FROM votes GROUP BY vote');

      expect(result.rows).to.have.lengthOf(0);
    });

    it('should aggregate votes correctly', async function () {
      // Insert multiple votes
      for (let i = 0; i < 10; i++) {
        await client.query("INSERT INTO votes (vote) VALUES ('a')");
      }
      for (let i = 0; i < 5; i++) {
        await client.query("INSERT INTO votes (vote) VALUES ('b')");
      }

      const result = await client.query('SELECT vote, COUNT(id) AS count FROM votes GROUP BY vote');

      const voteCounts = {};
      result.rows.forEach((row) => {
        voteCounts[row.vote] = parseInt(row.count);
      });

      expect(voteCounts.a).to.equal(10);
      expect(voteCounts.b).to.equal(5);
    });
  });
});