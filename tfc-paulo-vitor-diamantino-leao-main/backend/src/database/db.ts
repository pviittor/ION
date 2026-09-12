import { Pool } from 'pg';
import fs from 'fs';
import dotenv from 'dotenv';

dotenv.config();

export const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: parseInt(process.env.DB_PORT || '5432'),
  ssl: {
    ca: fs.readFileSync('./rds-combined-ca-bundle.pem').toString()
  }
});