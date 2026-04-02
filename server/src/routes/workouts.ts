import { Router, Request, Response } from 'express';
import db from '../db/connection.js';

const router = Router();

// GET /api/workouts — list workouts with optional date range, include set count
router.get('/', (req: Request, res: Response) => {
  try {
    const { from, to } = req.query;

    let sql = `
      SELECT w.*, COUNT(ws.id) as set_count
      FROM workouts w
      LEFT JOIN workout_sets ws ON ws.workout_id = w.id
    `;
    const params: string[] = [];
    const conditions: string[] = [];

    if (from) {
      conditions.push('w.date >= ?');
      params.push(from as string);
    }
    if (to) {
      conditions.push('w.date <= ?');
      params.push(to as string);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' GROUP BY w.id ORDER BY w.date DESC, w.id DESC';

    const workouts = db.prepare(sql).all(...params);
    res.json(workouts);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// GET /api/workouts/:id — single workout with all sets joined with exercise names
router.get('/:id', (req: Request, res: Response) => {
  try {
    const workout = db.prepare('SELECT * FROM workouts WHERE id = ?').get(req.params.id);
    if (!workout) {
      return res.status(404).json({ error: 'Workout not found' });
    }

    const sets = db.prepare(`
      SELECT ws.*, e.name as exercise_name, e.muscle_group, e.equipment
      FROM workout_sets ws
      JOIN exercises e ON e.id = ws.exercise_id
      WHERE ws.workout_id = ?
      ORDER BY ws.set_number
    `).all(req.params.id);

    res.json({ ...(workout as object), sets });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// POST /api/workouts — create workout with nested sets array
router.post('/', (req: Request, res: Response) => {
  try {
    const { name, date, notes, duration_minutes, sets } = req.body;

    if (!date) {
      return res.status(400).json({ error: 'date is required' });
    }

    const createWorkout = db.transaction(() => {
      const result = db.prepare(
        'INSERT INTO workouts (name, date, notes, duration_minutes) VALUES (?, ?, ?, ?)'
      ).run(name || null, date, notes || null, duration_minutes || null);

      const workoutId = result.lastInsertRowid;

      if (sets && Array.isArray(sets)) {
        const insertSet = db.prepare(`
          INSERT INTO workout_sets (workout_id, exercise_id, set_number, reps, weight, rpe, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        `);

        for (const set of sets) {
          insertSet.run(
            workoutId,
            set.exercise_id,
            set.set_number,
            set.reps ?? null,
            set.weight ?? null,
            set.rpe ?? null,
            set.notes ?? null
          );
        }
      }

      return workoutId;
    });

    const workoutId = createWorkout();

    const workout = db.prepare('SELECT * FROM workouts WHERE id = ?').get(workoutId);
    const workoutSets = db.prepare(`
      SELECT ws.*, e.name as exercise_name, e.muscle_group, e.equipment
      FROM workout_sets ws
      JOIN exercises e ON e.id = ws.exercise_id
      WHERE ws.workout_id = ?
      ORDER BY ws.set_number
    `).all(workoutId);

    res.status(201).json({ ...(workout as object), sets: workoutSets });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// PUT /api/workouts/:id — update workout, replace sets
router.put('/:id', (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { name, date, notes, duration_minutes, sets } = req.body;

    const existing = db.prepare('SELECT * FROM workouts WHERE id = ?').get(id);
    if (!existing) {
      return res.status(404).json({ error: 'Workout not found' });
    }

    const updateWorkout = db.transaction(() => {
      db.prepare(
        'UPDATE workouts SET name = ?, date = ?, notes = ?, duration_minutes = ? WHERE id = ?'
      ).run(
        name ?? (existing as any).name,
        date ?? (existing as any).date,
        notes ?? (existing as any).notes,
        duration_minutes ?? (existing as any).duration_minutes,
        id
      );

      // Delete existing sets and re-insert
      db.prepare('DELETE FROM workout_sets WHERE workout_id = ?').run(id);

      if (sets && Array.isArray(sets)) {
        const insertSet = db.prepare(`
          INSERT INTO workout_sets (workout_id, exercise_id, set_number, reps, weight, rpe, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        `);

        for (const set of sets) {
          insertSet.run(
            id,
            set.exercise_id,
            set.set_number,
            set.reps ?? null,
            set.weight ?? null,
            set.rpe ?? null,
            set.notes ?? null
          );
        }
      }
    });

    updateWorkout();

    const workout = db.prepare('SELECT * FROM workouts WHERE id = ?').get(id);
    const workoutSets = db.prepare(`
      SELECT ws.*, e.name as exercise_name, e.muscle_group, e.equipment
      FROM workout_sets ws
      JOIN exercises e ON e.id = ws.exercise_id
      WHERE ws.workout_id = ?
      ORDER BY ws.set_number
    `).all(id);

    res.json({ ...(workout as object), sets: workoutSets });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// DELETE /api/workouts/:id — delete workout (cascade deletes sets)
router.delete('/:id', (req: Request, res: Response) => {
  try {
    const existing = db.prepare('SELECT * FROM workouts WHERE id = ?').get(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Workout not found' });
    }

    db.prepare('DELETE FROM workouts WHERE id = ?').run(req.params.id);
    res.json({ message: 'Workout deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// GET /api/progress/exercise/:exerciseId — progress data for charting
router.get('/exercise/:exerciseId', (req: Request, res: Response) => {
  try {
    const { exerciseId } = req.params;

    const exercise = db.prepare('SELECT * FROM exercises WHERE id = ?').get(exerciseId);
    if (!exercise) {
      return res.status(404).json({ error: 'Exercise not found' });
    }

    const progress = db.prepare(`
      SELECT
        w.date,
        MAX(ws.weight) as max_weight,
        MAX(ws.reps) as max_reps,
        SUM(COALESCE(ws.weight, 0) * COALESCE(ws.reps, 0)) as volume
      FROM workout_sets ws
      JOIN workouts w ON w.id = ws.workout_id
      WHERE ws.exercise_id = ?
      GROUP BY w.date
      ORDER BY w.date ASC
    `).all(exerciseId);

    res.json(progress);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

export default router;
