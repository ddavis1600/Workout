import db from './connection.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export function runMigrations(): void {
  const migrationsDir = path.resolve(__dirname, 'migrations');

  // In production (compiled), migrations dir is at dist/db/migrations
  // but the SQL files aren't copied by tsc. Inline the migration instead.
  if (!fs.existsSync(migrationsDir)) {
    // Fallback: look relative to project root
    const fallback = path.resolve(__dirname, '..', '..', 'src', 'db', 'migrations');
    if (fs.existsSync(fallback)) {
      runFromDir(fallback);
      return;
    }
    console.warn('No migrations directory found, skipping.');
    return;
  }

  runFromDir(migrationsDir);
}

function runFromDir(dir: string): void {
  const files = fs.readdirSync(dir)
    .filter(f => f.endsWith('.sql'))
    .sort();

  for (const file of files) {
    const filePath = path.join(dir, file);
    const sql = fs.readFileSync(filePath, 'utf-8');
    db.exec(sql);
    console.log(`Migration applied: ${file}`);
  }
}
