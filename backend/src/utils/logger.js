const pino = require("pino");
const config = require("../config");

const logger = pino({
  level: config.nodeEnv === "production" ? "info" : "debug",
  base: { service: "tutorlink-api" },
  timestamp: () => `,"timestamp":"${new Date().toISOString()}"`,
  formatters: {
    level: (label) => ({ level: label }),
  },
  redact: {
    paths: [
      "password",
      "*.password",
      "password_hash",
      "*.password_hash",
      "token",
      "*.token",
      "authorization",
      "*.authorization",
      "req.headers.authorization",
    ],
    censor: "[REDACTED]",
  },
});

module.exports = logger;