import Foundation
import SwiftData

enum SeedData {

    // MARK: - Exercises

    static func seedExercises(context: ModelContext) {
        let exercises: [(name: String, group: String, equipment: String?)] = [
            // Chest
            ("Flat Barbell Bench Press",   "chest",     "barbell"),
            ("Incline Barbell Bench Press", "chest",    "barbell"),
            ("Flat Dumbbell Bench Press",  "chest",     "dumbbell"),
            ("Incline Dumbbell Bench Press","chest",     "dumbbell"),
            ("Cable Fly",                  "chest",     "cable"),
            ("Machine Chest Press",        "chest",     "machine"),
            ("Push-Up",                    "chest",     "bodyweight"),
            ("Dip",                        "chest",     "bodyweight"),

            // Back
            ("Barbell Row",               "back",      "barbell"),
            ("Dumbbell Row",              "back",      "dumbbell"),
            ("Pull-Up",                   "back",      "bodyweight"),
            ("Chin-Up",                   "back",      "bodyweight"),
            ("Lat Pulldown",              "back",      "cable"),
            ("Seated Cable Row",          "back",      "cable"),
            ("Deadlift",                  "back",      "barbell"),
            ("T-Bar Row",                 "back",      "barbell"),

            // Shoulders
            ("Overhead Press",            "shoulders", "barbell"),
            ("Dumbbell Shoulder Press",   "shoulders", "dumbbell"),
            ("Lateral Raise",             "shoulders", "dumbbell"),
            ("Front Raise",              "shoulders", "dumbbell"),
            ("Face Pull",                "shoulders", "cable"),
            ("Reverse Fly",              "shoulders", "dumbbell"),

            // Arms
            ("Barbell Curl",             "arms",      "barbell"),
            ("Dumbbell Curl",            "arms",      "dumbbell"),
            ("Hammer Curl",              "arms",      "dumbbell"),
            ("Tricep Pushdown",          "arms",      "cable"),
            ("Skull Crusher",            "arms",      "barbell"),
            ("Overhead Tricep Extension", "arms",      "dumbbell"),
            ("Preacher Curl",            "arms",      "machine"),

            // Legs
            ("Barbell Squat",            "legs",      "barbell"),
            ("Front Squat",              "legs",      "barbell"),
            ("Leg Press",                "legs",      "machine"),
            ("Romanian Deadlift",        "legs",      "barbell"),
            ("Leg Curl",                 "legs",      "machine"),
            ("Leg Extension",            "legs",      "machine"),
            ("Bulgarian Split Squat",    "legs",      "dumbbell"),
            ("Calf Raise",              "legs",      "machine"),
            ("Hip Thrust",              "legs",      "barbell"),
            ("Goblet Squat",            "legs",      "dumbbell"),

            // Core
            ("Plank",                    "core",      "bodyweight"),
            ("Hanging Leg Raise",        "core",      "bodyweight"),
            ("Cable Crunch",             "core",      "cable"),
            ("Ab Wheel Rollout",         "core",      "bodyweight"),
            ("Russian Twist",            "core",      "bodyweight"),

            // Cardio
            ("Treadmill Run",            "cardio",    "cardio"),
            ("Stationary Bike",          "cardio",    "cardio"),
            ("Rowing Machine",           "cardio",    "cardio"),
            ("Elliptical",               "cardio",    "cardio"),
            ("Jump Rope",                "cardio",    "bodyweight"),
        ]

        for entry in exercises {
            let exercise = Exercise(name: entry.name, muscleGroup: entry.group, equipment: entry.equipment)
            context.insert(exercise)
        }
    }

    // MARK: - Foods

    static func seedFoods(context: ModelContext) {
        let foods: [(name: String, serving: Double, unit: String, cal: Double, p: Double, c: Double, f: Double, brand: String?)] = [
            // Proteins
            ("Chicken Breast",        4,   "oz",  120, 26, 0,  1.5, nil),
            ("Ground Beef 90/10",     4,   "oz",  200, 22, 0,  11,  nil),
            ("Salmon Fillet",         4,   "oz",  180, 25, 0,  8,   nil),
            ("Eggs",                  1,   "large",78,  6,  0.6,5,  nil),
            ("Egg Whites",            3,   "tbsp", 25,  5,  0.4,0,  nil),
            ("Greek Yogurt 0%",       170, "g",   100, 17, 6,  0.7, "Fage"),
            ("Whey Protein",          1,   "scoop",120, 24, 3,  1,   nil),
            ("Turkey Breast Deli",    2,   "oz",   60, 12, 1,  0.5, nil),
            ("Tofu Firm",             100, "g",    80,  9,  2,  4,   nil),
            ("Shrimp",                4,   "oz",   90, 20, 1,  0.5, nil),
            ("Canned Tuna",           1,   "can", 100, 22, 0,  1,   nil),
            ("Cottage Cheese 2%",     113, "g",    90, 12, 5,  2.5, nil),

            // Carbs
            ("White Rice",            1,  "cup",  200, 4,  45, 0.4, nil),
            ("Brown Rice",            1,  "cup",  215, 5,  45, 1.8, nil),
            ("Oats",                  0.5,"cup",  150, 5,  27, 3,   nil),
            ("Sweet Potato",          1,  "medium",103,2,  24, 0,   nil),
            ("Banana",                1,  "medium",105,1.3,27, 0.4, nil),
            ("White Bread",           1,  "slice", 75, 2,  14, 1,   nil),
            ("Whole Wheat Bread",     1,  "slice", 80, 4,  14, 1,   nil),
            ("Pasta",                 2,  "oz",   200, 7,  42, 1,   nil),
            ("Quinoa",                1,  "cup",  222, 8,  39, 3.5, nil),
            ("Apple",                 1,  "medium",95, 0.5,25, 0.3, nil),
            ("Blueberries",           1,  "cup",   85, 1,  21, 0.5, nil),

            // Fats
            ("Olive Oil",             1,  "tbsp",  120,0,  0,  14,  nil),
            ("Peanut Butter",         2,  "tbsp",  190,7,  7,  16,  nil),
            ("Almond Butter",         2,  "tbsp",  196,7,  6,  18,  nil),
            ("Almonds",               1,  "oz",    164,6,  6,  14,  nil),
            ("Avocado",               0.5,"medium",120,1.5,6,  11,  nil),
            ("Cheese Cheddar",        1,  "oz",    113,7,  0.4,9,   nil),
            ("Whole Milk",            1,  "cup",   150,8,  12, 8,   nil),
            ("Skim Milk",             1,  "cup",    90,8,  12, 0,   nil),
            ("Butter",                1,  "tbsp",  100,0,  0,  11,  nil),

            // Misc / Snacks
            ("Protein Bar",           1,  "bar",   210,20, 22, 7,   nil),
            ("Rice Cake",             1,  "cake",   35,1,  7,  0.3, nil),
        ]

        for entry in foods {
            let food = Food(
                name: entry.name,
                servingSize: entry.serving,
                servingUnit: entry.unit,
                calories: entry.cal,
                protein: entry.p,
                carbs: entry.c,
                fat: entry.f,
                brand: entry.brand
            )
            context.insert(food)
        }
    }
}
