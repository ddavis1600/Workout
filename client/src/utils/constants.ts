export const MUSCLE_GROUPS = [
  'Chest',
  'Back',
  'Shoulders',
  'Biceps',
  'Triceps',
  'Legs',
  'Glutes',
  'Core',
  'Forearms',
  'Calves',
  'Full Body',
  'Cardio',
] as const;

export const MEAL_TYPES = ['breakfast', 'lunch', 'dinner', 'snack'] as const;

export const ACTIVITY_LEVELS = [
  { value: 'sedentary', label: 'Sedentary (little or no exercise)' },
  { value: 'light', label: 'Lightly Active (1-3 days/week)' },
  { value: 'moderate', label: 'Moderately Active (3-5 days/week)' },
  { value: 'active', label: 'Very Active (6-7 days/week)' },
  { value: 'very_active', label: 'Extra Active (physical job + exercise)' },
] as const;

export const GOALS = [
  { value: 'cut', label: 'Cut (Lose Fat)', adjustment: -500 },
  { value: 'maintain', label: 'Maintain', adjustment: 0 },
  { value: 'bulk', label: 'Bulk (Build Muscle)', adjustment: 300 },
] as const;
