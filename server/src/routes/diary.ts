import { Router, Request, Response } from 'express';
import db from '../db/connection.js';

const router = Router();

// GET /api/diary?date= — all entries for a date, joined with food data, grouped by meal_type
router.get('/', (req: Request, res: Response) => {
  try {
    const { date } = req.query;

    if (!date) {
      return res.status(400).json({ error: 'date query parameter is required' });
    }

    const entries = db.prepare(`
      SELECT
        de.id,
        de.date,
        de.meal_type,
        de.food_id,
        de.servings,
        de.created_at,
        f.name as food_name,
        f.brand,
        f.serving_size,
        f.serving_unit,
        f.calories as food_calories,
        f.protein as food_protein,
        f.carbs as food_carbs,
        f.fat as food_fat,
        ROUND(f.calories * de.servings, 1) as total_calories,
        ROUND(f.protein * de.servings, 1) as total_protein,
        ROUND(f.carbs * de.servings, 1) as total_carbs,
        ROUND(f.fat * de.servings, 1) as total_fat
      FROM diary_entries de
      JOIN foods f ON f.id = de.food_id
      WHERE de.date = ?
      ORDER BY de.meal_type, de.created_at
    `).all(date as string);

    // Group by meal_type
    const grouped: Record<string, any[]> = {};
    for (const entry of entries as any[]) {
      if (!grouped[entry.meal_type]) {
        grouped[entry.meal_type] = [];
      }
      grouped[entry.meal_type].push(entry);
    }

    res.json({ date, meals: grouped, entries });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// GET /api/diary/summary?date= — aggregated totals for the day
router.get('/summary', (req: Request, res: Response) => {
  try {
    const { date } = req.query;

    if (!date) {
      return res.status(400).json({ error: 'date query parameter is required' });
    }

    const summary = db.prepare(`
      SELECT
        COALESCE(ROUND(SUM(f.calories * de.servings), 1), 0) as total_calories,
        COALESCE(ROUND(SUM(f.protein * de.servings), 1), 0) as total_protein,
        COALESCE(ROUND(SUM(f.carbs * de.servings), 1), 0) as total_carbs,
        COALESCE(ROUND(SUM(f.fat * de.servings), 1), 0) as total_fat
      FROM diary_entries de
      JOIN foods f ON f.id = de.food_id
      WHERE de.date = ?
    `).get(date as string);

    const mealBreakdown = db.prepare(`
      SELECT
        de.meal_type,
        COALESCE(ROUND(SUM(f.calories * de.servings), 1), 0) as calories,
        COALESCE(ROUND(SUM(f.protein * de.servings), 1), 0) as protein,
        COALESCE(ROUND(SUM(f.carbs * de.servings), 1), 0) as carbs,
        COALESCE(ROUND(SUM(f.fat * de.servings), 1), 0) as fat
      FROM diary_entries de
      JOIN foods f ON f.id = de.food_id
      WHERE de.date = ?
      GROUP BY de.meal_type
    `).all(date as string);

    res.json({ date, ...summary as object, meals: mealBreakdown });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// POST /api/diary — add diary entry
router.post('/', (req: Request, res: Response) => {
  try {
    const { date, meal_type, food_id, servings } = req.body;

    if (!date || !meal_type || !food_id) {
      return res.status(400).json({ error: 'date, meal_type, and food_id are required' });
    }

    // Verify food exists
    const food = db.prepare('SELECT * FROM foods WHERE id = ?').get(food_id);
    if (!food) {
      return res.status(404).json({ error: 'Food not found' });
    }

    const result = db.prepare(
      'INSERT INTO diary_entries (date, meal_type, food_id, servings) VALUES (?, ?, ?, ?)'
    ).run(date, meal_type, food_id, servings ?? 1.0);

    const entry = db.prepare(`
      SELECT
        de.*,
        f.name as food_name,
        f.brand,
        f.serving_size,
        f.serving_unit,
        f.calories as food_calories,
        f.protein as food_protein,
        f.carbs as food_carbs,
        f.fat as food_fat,
        ROUND(f.calories * de.servings, 1) as total_calories,
        ROUND(f.protein * de.servings, 1) as total_protein,
        ROUND(f.carbs * de.servings, 1) as total_carbs,
        ROUND(f.fat * de.servings, 1) as total_fat
      FROM diary_entries de
      JOIN foods f ON f.id = de.food_id
      WHERE de.id = ?
    `).get(result.lastInsertRowid);

    res.status(201).json(entry);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// PUT /api/diary/:id — update servings
router.put('/:id', (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { servings } = req.body;

    if (servings == null) {
      return res.status(400).json({ error: 'servings is required' });
    }

    const existing = db.prepare('SELECT * FROM diary_entries WHERE id = ?').get(id);
    if (!existing) {
      return res.status(404).json({ error: 'Diary entry not found' });
    }

    db.prepare('UPDATE diary_entries SET servings = ? WHERE id = ?').run(servings, id);

    const entry = db.prepare(`
      SELECT
        de.*,
        f.name as food_name,
        f.brand,
        f.serving_size,
        f.serving_unit,
        f.calories as food_calories,
        f.protein as food_protein,
        f.carbs as food_carbs,
        f.fat as food_fat,
        ROUND(f.calories * de.servings, 1) as total_calories,
        ROUND(f.protein * de.servings, 1) as total_protein,
        ROUND(f.carbs * de.servings, 1) as total_carbs,
        ROUND(f.fat * de.servings, 1) as total_fat
      FROM diary_entries de
      JOIN foods f ON f.id = de.food_id
      WHERE de.id = ?
    `).get(id);

    res.json(entry);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// DELETE /api/diary/:id — delete entry
router.delete('/:id', (req: Request, res: Response) => {
  try {
    const existing = db.prepare('SELECT * FROM diary_entries WHERE id = ?').get(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Diary entry not found' });
    }

    db.prepare('DELETE FROM diary_entries WHERE id = ?').run(req.params.id);
    res.json({ message: 'Diary entry deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

export default router;
