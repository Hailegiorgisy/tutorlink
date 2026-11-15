require("dotenv").config();

const REQUIRED = [
  "DB_HOST",
  "DB_PORT",
  "DB_NAME",
  "DB_USER",
  "DB_PASSWORD",
  "JWT_SECRET",
  "CORS_ORIGIN",
];

const missing = REQUIRED.filter((key) => !process.env[key]);
if (missing.length > 0) {
  // Name the missing keys — NEVER print secret values
  throw new Error(`Missing required environment variables: ${missing.join(", ")}`);
}

if (process.env.JWT_SECRET.length < 32) {
  throw new Error("JWT_SECRET must be at least 32 characters long.");
}

const config = {
  port: Number(process.env.PORT) || 3000,
  nodeEnv: process.env.NODE_ENV || "development",
  db: {
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
  },
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || "15m",
    issuer: process.env.JWT_ISSUER || "tutorlink-api",
    audience: process.env.JWT_AUDIENCE || "tutorlink-client",
  },
  corsOrigin: process.env.CORS_ORIGIN,
};

module.exports = config;