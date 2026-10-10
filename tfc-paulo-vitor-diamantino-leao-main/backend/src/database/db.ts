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
  // DB_SSL=false para banco local (sem SSL); padrão continua sendo o RDS com SSL
  ssl: process.env.DB_SSL === 'false'
    ? false
    : { ca: fs.readFileSync('./rds-combined-ca-bundle.pem').toString() }
});