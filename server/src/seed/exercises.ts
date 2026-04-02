import db from '../db/connection';

interface ExerciseSeed {
  name: string;
  muscle_group: string;
  equipment: string;
}

const exercises: ExerciseSeed[] = [
  // Chest
  { name: 'Bench Press', muscle_group: 'Chest', equipment: 'barbell' },
  { name: 'Incline Bench Press', muscle_group: 'Chest', equipment: 'barbell' },
  { name: 'Dumbbell Flyes', muscle_group: 'Chest', equipment: 'dumbbell' },
  { name: 'Cable Crossover', muscle_group: 'Chest', equipment: 'cable' },
  { name: 'Push-ups', muscle_group: 'Chest', equipment: 'bodyweight' },
  { name: 'Decline Bench Press', muscle_group: 'Chest', equipment: 'barbell' },

  // Back
  { name: 'Deadlift', muscle_group: 'Back', equipment: 'barbell' },
  { name: 'Barbell Row', muscle_group: 'Back', equipment: 'barbell' },
  { name: 'Pull-ups', muscle_group: 'Back', equipment: 'bodyweight' },
  { name: 'Lat Pulldown', muscle_group: 'Back', equipment: 'machine' },
  { name: 'Seated Cable Row', muscle_group: 'Back', equipment: 'cable' },
  { name: 'T-Bar Row', muscle_group: 'Back', equipment: 'barbell' },
  { name: 'Face Pulls', muscle_group: 'Back', equipment: 'cable' },

  // Shoulders
  { name: 'Overhead Press', muscle_group: 'Shoulders', equipment: 'barbell' },
  { name: 'Lateral Raise', muscle_group: 'Shoulders', equipment: 'dumbbell' },
  { name: 'Front Raise', muscle_group: 'Shoulders', equipment: 'dumbbell' },
  { name: 'Rear Delt Fly', muscle_group: 'Shoulders', equipment: 'dumbbell' },
  { name: 'Arnold Press', muscle_group: 'Shoulders', equipment: 'dumbbell' },
  { name: 'Shrugs', muscle_group: 'Shoulders', equipment: 'dumbbell' },

  // Arms
  { name: 'Bicep Curl', muscle_group: 'Arms', equipment: 'dumbbell' },
  { name: 'Hammer Curl', muscle_group: 'Arms', equipment: 'dumbbell' },
  { name: 'Tricep Pushdown', muscle_group: 'Arms', equipment: 'cable' },
  { name: 'Skull Crushers', muscle_group: 'Arms', equipment: 'barbell' },
  { name: 'Preacher Curl', muscle_group: 'Arms', equipment: 'barbell' },
  { name: 'Concentration Curl', muscle_group: 'Arms', equipment: 'dumbbell' },
  { name: 'Overhead Tricep Extension', muscle_group: 'Arms', equipment: 'dumbbell' },
  { name: 'Dips', muscle_group: 'Arms', equipment: 'bodyweight' },

  // Legs
  { name: 'Squat', muscle_group: 'Legs', equipment: 'barbell' },
  { name: 'Leg Press', muscle_group: 'Legs', equipment: 'machine' },
  { name: 'Lunges', muscle_group: 'Legs', equipment: 'dumbbell' },
  { name: 'Leg Extension', muscle_group: 'Legs', equipment: 'machine' },
  { name: 'Leg Curl', muscle_group: 'Legs', equipment: 'machine' },
  { name: 'Calf Raises', muscle_group: 'Legs', equipment: 'machine' },
  { name: 'Romanian Deadlift', muscle_group: 'Legs', equipment: 'barbell' },
  { name: 'Hip Thrust', muscle_group: 'Legs', equipment: 'barbell' },
  { name: 'Bulgarian Split Squat', muscle_group: 'Legs', equipment: 'dumbbell' },
  { name: 'Goblet Squat', muscle_group: 'Legs', equipment: 'dumbbell' },

  // Core
  { name: 'Plank', muscle_group: 'Core', equipment: 'bodyweight' },
  { name: 'Crunches', muscle_group: 'Core', equipment: 'bodyweight' },
  { name: 'Russian Twist', muscle_group: 'Core', equipment: 'bodyweight' },
  { name: 'Hanging Leg Raise', muscle_group: 'Core', equipment: 'bodyweight' },
  { name: 'Ab Wheel Rollout', muscle_group: 'Core', equipment: 'bodyweight' },
  { name: 'Cable Woodchop', muscle_group: 'Core', equipment: 'cable' },

  // Cardio
  { name: 'Running', muscle_group: 'Cardio', equipment: 'cardio' },
  { name: 'Cycling', muscle_group: 'Cardio', equipment: 'cardio' },
  { name: 'Rowing Machine', muscle_group: 'Cardio', equipment: 'cardio' },
  { name: 'Jump Rope', muscle_group: 'Cardio', equipment: 'cardio' },
  { name: 'Stair Climber', muscle_group: 'Cardio', equipment: 'cardio' },
  { name: 'Elliptical', muscle_group: 'Cardio', equipment: 'cardio' },
];

export function seedExercises(): void {
  const count = db.prepare('SELECT COUNT(*) as count FROM exercises').get() as { count: number };
  if (count.count > 0) {
    console.log('Exercises table already seeded, skipping.');
    return;
  }

  const insert = db.prepare(
    'INSERT INTO exercises (name, muscle_group, equipment) VALUES (?, ?, ?)'
  );

  const insertMany = db.transaction((items: ExerciseSeed[]) => {
    for (const item of items) {
      insert.run(item.name, item.muscle_group, item.equipment);
    }
  });

  insertMany(exercises);
  console.log(`Seeded ${exercises.length} exercises.`);
}
