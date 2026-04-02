import { Router, Request, Response } from 'express';
import db from '../db/connection.js';

const router = Router();

// GET /api/foods — search foods with ?q= using LIKE on name
router.get('/', (req: Request, res: Response) => {
  try {
    const { q } = req.query;

    if (q && typeof q === 'string' && q.trim().length > 0) {
      const foods = db.prepare(
        'SELECT * FROM foods WHERE name LIKE ? ORDER BY is_custom DESC, name'
      ).all(`%${q.trim()}%`);
      return res.json(foods);
    }

    const foods = db.prepare('SELECT * FROM foods ORDER BY is_custom DESC, name').all();
    res.json(foods);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// GET /api/foods/:id — single food
router.get('/:id', (req: Request, res: Response) => {
  try {
    const food = db.prepare('SELECT * FROM foods WHERE id = ?').get(req.params.id);
    if (!food) {
      return res.status(404).json({ error: 'Food not found' });
    }
    res.json(food);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// POST /api/foods — create custom food (is_custom=1)
router.post('/', (req: Request, res: Response) => {
  try {
    const { name, brand, serving_size, serving_unit, calories, protein, carbs, fat } = req.body;

    if (!name || serving_size == null || !serving_unit || calories == null || protein == null || carbs == null || fat == null) {
      return res.status(400).json({
        error: 'name, serving_size, serving_unit, calories, protein, carbs, and fat are required',
      });
    }

    const result = db.prepare(`
      INSERT INTO foods (name, brand, serving_size, serving_unit, calories, protein, carbs, fat, is_custom)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)
    `).run(name, brand || null, serving_size, serving_unit, calories, protein, carbs, fat);

    const food = db.prepare('SELECT * FROM foods WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json(food);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

export default router;
