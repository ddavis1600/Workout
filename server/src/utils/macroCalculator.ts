export function calculateBMR(
  weight_kg: number,
  height_cm: number,
  age: number,
  gender: string
): number {
  // Mifflin-St Jeor Equation
  if (gender.toLowerCase() === 'male') {
    return 10 * weight_kg + 6.25 * height_cm - 5 * age + 5;
  } else {
    return 10 * weight_kg + 6.25 * height_cm - 5 * age - 161;
  }
}

const activityMultipliers: Record<string, number> = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  active: 1.725,
  very_active: 1.9,
};

export function calculateTDEE(bmr: number, activityLevel: string): number {
  const multiplier = activityMultipliers[activityLevel] ?? 1.2;
  return Math.round(bmr * multiplier);
}

export interface MacroTargets {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

export function calculateMacros(
  tdee: number,
  goal: string,
  weight_kg: number
): MacroTargets {
  let calories: number;

  switch (goal.toLowerCase()) {
    case 'cut':
      calories = tdee - 500;
      break;
    case 'bulk':
      calories = tdee + 300;
      break;
    case 'maintain':
    default:
      calories = tdee;
      break;
  }

  // Protein: ~2.2g per kg (~1g per lb)
  const protein = Math.round(2.2 * weight_kg);

  // Fat: 25% of total calories / 9 cal per gram
  const fat = Math.round((calories * 0.25) / 9);

  // Carbs: remainder / 4 cal per gram
  const proteinCalories = protein * 4;
  const fatCalories = fat * 9;
  const carbs = Math.round((calories - proteinCalories - fatCalories) / 4);

  return {
    calories: Math.round(calories),
    protein,
    carbs,
    fat,
  };
}
