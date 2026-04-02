const ACTIVITY_MULTIPLIERS: Record<string, number> = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  active: 1.725,
  very_active: 1.9,
};

const GOAL_ADJUSTMENTS: Record<string, number> = {
  cut: -500,
  maintain: 0,
  bulk: 300,
};

export function calculateBMR(
  weight: number,
  height: number,
  age: number,
  gender: string,
  unitSystem: string = 'imperial'
): number {
  let weightKg = weight;
  let heightCm = height;

  if (unitSystem === 'imperial') {
    weightKg = weight * 0.453592;
    heightCm = height * 2.54;
  }

  if (gender === 'male') {
    return 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
  }
  return 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
}

export function calculateTDEE(bmr: number, activityLevel: string): number {
  const multiplier = ACTIVITY_MULTIPLIERS[activityLevel] || 1.2;
  return Math.round(bmr * multiplier);
}

export function calculateAdjustedCalories(tdee: number, goal: string): number {
  const adjustment = GOAL_ADJUSTMENTS[goal] || 0;
  return Math.round(tdee + adjustment);
}

export function calculateMacros(calories: number, weight: number, unitSystem: string = 'imperial') {
  let weightKg = weight;
  if (unitSystem === 'imperial') {
    weightKg = weight * 0.453592;
  }

  const proteinGrams = Math.round(weightKg * 2.0);
  const fatGrams = Math.round((calories * 0.25) / 9);
  const proteinCalories = proteinGrams * 4;
  const fatCalories = fatGrams * 9;
  const carbCalories = calories - proteinCalories - fatCalories;
  const carbGrams = Math.round(carbCalories / 4);

  return {
    protein: proteinGrams,
    carbs: Math.max(carbGrams, 0),
    fat: fatGrams,
  };
}

export function calculateAll(
  weight: number,
  height: number,
  age: number,
  gender: string,
  activityLevel: string,
  goal: string,
  unitSystem: string = 'imperial'
) {
  const bmr = calculateBMR(weight, height, age, gender, unitSystem);
  const tdee = calculateTDEE(bmr, activityLevel);
  const adjustedCalories = calculateAdjustedCalories(tdee, goal);
  const macros = calculateMacros(adjustedCalories, weight, unitSystem);

  return {
    tdee,
    calorie_target: adjustedCalories,
    protein_target: macros.protein,
    carb_target: macros.carbs,
    fat_target: macros.fat,
  };
}
