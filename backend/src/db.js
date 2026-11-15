const { Pool } = require("pg");
const config = require("./config");
const logger = require("./utils/logger");

const pool = new Pool({
  host: config.db.host,
  port: config.db.port,
  database: config.db.database,
  user: config.db.user,
  password: config.db.password,
});

pool.on("error", (err) => {
  logger.error({ event: "db_pool_error", message: err.message });
});

module.exports = pool;