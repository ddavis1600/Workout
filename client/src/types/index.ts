export interface Exercise {
  id: number;
  name: string;
  muscle_group: string;
  equipment: string;
}

export interface WorkoutSet {
  id?: number;
  workout_id?: number;
  exercise_id: number;
  exercise_name?: string;
  set_number: number;
  reps: number;
  weight: number;
  rpe?: number;
  notes?: string;
}

export interface Workout {
  id: number;
  name: string;
  date: string;
  notes: string;
  duration_minutes: number;
  sets: WorkoutSet[];
  set_count?: number;
}

export interface UserProfile {
  id: number;
  weight: number;
  height: number;
  age: number;
  gender: string;
  activity_level: string;
  goal: string;
  tdee: number;
  protein_target: number;
  carb_target: number;
  fat_target: number;
  calorie_target: number;
  unit_system: string;
}

export interface Food {
  id: number;
  name: string;
  brand?: string;
  serving_size: number;
  serving_unit: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  is_custom?: boolean;
}

export interface DiaryEntry {
  id: number;
  date: string;
  meal_type: string;
  food_id: number;
  food?: Food;
  servings: number;
  total_calories?: number;
  total_protein?: number;
  total_carbs?: number;
  total_fat?: number;
}

export interface MacroSummary {
  total_calories: number;
  total_protein: number;
  total_carbs: number;
  total_fat: number;
}

export interface ProgressPoint {
  date: string;
  max_weight: number;
  max_reps: number;
  volume: number;
}
