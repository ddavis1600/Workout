import { Router, Request, Response } from 'express';
import db from '../db/connection.js';
import { calculateBMR, calculateTDEE, calculateMacros } from '../utils/macroCalculator.js';

const router = Router();

// GET /api/profile — get current profile
router.get('/', (req: Request, res: Response) => {
  try {
    const profile = db.prepare('SELECT * FROM user_profile WHERE id = 1').get();
    res.json(profile);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// PUT /api/profile — update body stats and recalculate TDEE + targets, save to DB
router.put('/', (req: Request, res: Response) => {
  try {
    const { weight, height, age, gender, activity_level, goal, unit_system } = req.body;

    // Get current profile to fill in missing fields
    const current = db.prepare('SELECT * FROM user_profile WHERE id = 1').get() as any;

    const updatedWeight = weight ?? current.weight;
    const updatedHeight = height ?? current.height;
    const updatedAge = age ?? current.age;
    const updatedGender = gender ?? current.gender;
    const updatedActivityLevel = activity_level ?? current.activity_level;
    const updatedGoal = goal ?? current.goal;
    const updatedUnitSystem = unit_system ?? current.unit_system;

    let tdee: number | null = null;
    let proteinTarget: number | null = null;
    let carbTarget: number | null = null;
    let fatTarget: number | null = null;
    let calorieTarget: number | null = null;

    // Calculate if we have all required fields
    if (updatedWeight && updatedHeight && updatedAge && updatedGender && updatedActivityLevel) {
      // Convert to metric if imperial
      let weight_kg: number;
      let height_cm: number;

      if (updatedUnitSystem === 'imperial') {
        weight_kg = updatedWeight * 0.453592; // lbs to kg
        height_cm = updatedHeight * 2.54; // inches to cm
      } else {
        weight_kg = updatedWeight;
        height_cm = updatedHeight;
      }

      const bmr = calculateBMR(weight_kg, height_cm, updatedAge, updatedGender);
      tdee = calculateTDEE(bmr, updatedActivityLevel);

      if (updatedGoal) {
        const macros = calculateMacros(tdee, updatedGoal, weight_kg);
        calorieTarget = macros.calories;
        proteinTarget = macros.protein;
        carbTarget = macros.carbs;
        fatTarget = macros.fat;
      }
    }

    db.prepare(`
      UPDATE user_profile SET
        weight = ?,
        height = ?,
        age = ?,
        gender = ?,
        activity_level = ?,
        goal = ?,
        tdee = ?,
        protein_target = ?,
        carb_target = ?,
        fat_target = ?,
        calorie_target = ?,
        unit_system = ?,
        updated_at = datetime('now')
      WHERE id = 1
    `).run(
      updatedWeight,
      updatedHeight,
      updatedAge,
      updatedGender,
      updatedActivityLevel,
      updatedGoal,
      tdee,
      proteinTarget,
      carbTarget,
      fatTarget,
      calorieTarget,
      updatedUnitSystem
    );

    const profile = db.prepare('SELECT * FROM user_profile WHERE id = 1').get();
    res.json(profile);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// POST /api/profile/calculate — stateless calculation, returns values without saving
router.post('/calculate', (req: Request, res: Response) => {
  try {
    const { weight, height, age, gender, activity_level, goal, unit_system } = req.body;

    if (!weight || !height || !age || !gender || !activity_level) {
      return res.status(400).json({
        error: 'weight, height, age, gender, and activity_level are required',
      });
    }

    // Convert to metric if imperial
    let weight_kg: number;
    let height_cm: number;

    if (unit_system === 'imperial') {
      weight_kg = weight * 0.453592;
      height_cm = height * 2.54;
    } else {
      weight_kg = weight;
      height_cm = height;
    }

    const bmr = calculateBMR(weight_kg, height_cm, age, gender);
    const tdee = calculateTDEE(bmr, activity_level);
    const macros = calculateMacros(tdee, goal || 'maintain', weight_kg);

    res.json({
      bmr: Math.round(bmr),
      tdee,
      ...macros,
    });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

export default router;
