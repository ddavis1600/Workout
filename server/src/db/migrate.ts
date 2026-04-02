import db from './connection';
import fs from 'fs';
import path from 'path';

export function runMigrations(): void {
  const migrationsDir = path.resolve(__dirname, 'migrations');
  const files = fs.readdirSync(migrationsDir)
    .filter(f => f.endsWith('.sql'))
    .sort();

  for (const file of files) {
    const filePath = path.join(migrationsDir, file);
    const sql = fs.readFileSync(filePath, 'utf-8');
    db.exec(sql);
    console.log(`Migration applied: ${file}`);
  }
}
