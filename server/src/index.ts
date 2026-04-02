import express from 'express';
import cors from 'cors';
import { runMigrations } from './db/migrate.js';
import { seedExercises } from './seed/exercises.js';
import { seedFoods } from './seed/foods.js';
import exercisesRouter from './routes/exercises.js';
import workoutsRouter from './routes/workouts.js';
import foodsRouter from './routes/foods.js';
import diaryRouter from './routes/diary.js';
import macrosRouter from './routes/macros.js';

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// Run migrations and seeds on startup
try {
  runMigrations();
  seedExercises();
  seedFoods();
  console.log('Database initialized successfully.');
} catch (err) {
  console.error('Failed to initialize database:', err);
  process.exit(1);
}

// Mount routes
app.use('/api/exercises', exercisesRouter);
app.use('/api/workouts', workoutsRouter);
app.use('/api/foods', foodsRouter);
app.use('/api/diary', diaryRouter);
app.use('/api/profile', macrosRouter);
app.use('/api/progress', workoutsRouter);

// Health check
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Error handling middleware
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('Unhandled error:', err.stack);
  res.status(500).json({ error: 'Internal server error', message: err.message });
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});

export default app;
