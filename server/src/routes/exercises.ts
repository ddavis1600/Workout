import { Router, Request, Response } from 'express';
import db from '../db/connection';

const router = Router();

// GET /api/exercises — list all, optional ?muscle_group= filter
router.get('/', (req: Request, res: Response) => {
  try {
    const { muscle_group } = req.query;

    if (muscle_group) {
      const exercises = db
        .prepare('SELECT * FROM exercises WHERE muscle_group = ? ORDER BY name')
        .all(muscle_group as string);
      return res.json(exercises);
    }

    const exercises = db.prepare('SELECT * FROM exercises ORDER BY muscle_group, name').all();
    res.json(exercises);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// GET /api/exercises/:id — single exercise
router.get('/:id', (req: Request, res: Response) => {
  try {
    const exercise = db.prepare('SELECT * FROM exercises WHERE id = ?').get(req.params.id);
    if (!exercise) {
      return res.status(404).json({ error: 'Exercise not found' });
    }
    res.json(exercise);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// POST /api/exercises — create custom exercise
router.post('/', (req: Request, res: Response) => {
  try {
    const { name, muscle_group, equipment } = req.body;

    if (!name || !muscle_group) {
      return res.status(400).json({ error: 'name and muscle_group are required' });
    }

    const result = db
      .prepare('INSERT INTO exercises (name, muscle_group, equipment) VALUES (?, ?, ?)')
      .run(name, muscle_group, equipment || null);

    const exercise = db.prepare('SELECT * FROM exercises WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json(exercise);
  } catch (err) {
    if ((err as Error).message.includes('UNIQUE constraint')) {
      return res.status(409).json({ error: 'Exercise with this name already exists' });
    }
    res.status(500).json({ error: (err as Error).message });
  }
});

export default router;
