import Foundation
import SwiftData

struct SeedData {

    // MARK: - Exercises

    static func seedExercises(context: ModelContext) {
        // Chest
        context.insert(Exercise(name: "Bench Press", muscleGroup: "Chest", equipment: "barbell"))
        context.insert(Exercise(name: "Incline Bench Press", muscleGroup: "Chest", equipment: "barbell"))
        context.insert(Exercise(name: "Dumbbell Flyes", muscleGroup: "Chest", equipment: "dumbbell"))
        context.insert(Exercise(name: "Cable Crossover", muscleGroup: "Chest", equipment: "cable"))
        context.insert(Exercise(name: "Push-ups", muscleGroup: "Chest", equipment: "bodyweight"))
        context.insert(Exercise(name: "Decline Bench Press", muscleGroup: "Chest", equipment: "barbell"))

        // Back
        context.insert(Exercise(name: "Deadlift", muscleGroup: "Back", equipment: "barbell"))
        context.insert(Exercise(name: "Barbell Row", muscleGroup: "Back", equipment: "barbell"))
        context.insert(Exercise(name: "Pull-ups", muscleGroup: "Back", equipment: "bodyweight"))
        context.insert(Exercise(name: "Lat Pulldown", muscleGroup: "Back", equipment: "machine"))
        context.insert(Exercise(name: "Seated Cable Row", muscleGroup: "Back", equipment: "cable"))
        context.insert(Exercise(name: "T-Bar Row", muscleGroup: "Back", equipment: "barbell"))
        context.insert(Exercise(name: "Face Pulls", muscleGroup: "Back", equipment: "cable"))

        // Shoulders
        context.insert(Exercise(name: "Overhead Press", muscleGroup: "Shoulders", equipment: "barbell"))
        context.insert(Exercise(name: "Lateral Raise", muscleGroup: "Shoulders", equipment: "dumbbell"))
        context.insert(Exercise(name: "Front Raise", muscleGroup: "Shoulders", equipment: "dumbbell"))
        context.insert(Exercise(name: "Rear Delt Fly", muscleGroup: "Shoulders", equipment: "dumbbell"))
        context.insert(Exercise(name: "Arnold Press", muscleGroup: "Shoulders", equipment: "dumbbell"))
        context.insert(Exercise(name: "Shrugs", muscleGroup: "Shoulders", equipment: "dumbbell"))

        // Arms
        context.insert(Exercise(name: "Bicep Curl", muscleGroup: "Arms", equipment: "dumbbell"))
        context.insert(Exercise(name: "Hammer Curl", muscleGroup: "Arms", equipment: "dumbbell"))
        context.insert(Exercise(name: "Tricep Pushdown", muscleGroup: "Arms", equipment: "cable"))
        context.insert(Exercise(name: "Skull Crushers", muscleGroup: "Arms", equipment: "barbell"))
        context.insert(Exercise(name: "Preacher Curl", muscleGroup: "Arms", equipment: "machine"))
        context.insert(Exercise(name: "Concentration Curl", muscleGroup: "Arms", equipment: "dumbbell"))
        context.insert(Exercise(name: "Overhead Tricep Extension", muscleGroup: "Arms", equipment: "dumbbell"))
        context.insert(Exercise(name: "Dips", muscleGroup: "Arms", equipment: "bodyweight"))

        // Legs
        context.insert(Exercise(name: "Squat", muscleGroup: "Legs", equipment: "barbell"))
        context.insert(Exercise(name: "Leg Press", muscleGroup: "Legs", equipment: "machine"))
        context.insert(Exercise(name: "Lunges", muscleGroup: "Legs", equipment: "dumbbell"))
        context.insert(Exercise(name: "Leg Extension", muscleGroup: "Legs", equipment: "machine"))
        context.insert(Exercise(name: "Leg Curl", muscleGroup: "Legs", equipment: "machine"))
        context.insert(Exercise(name: "Calf Raises", muscleGroup: "Legs", equipment: "machine"))
        context.insert(Exercise(name: "Romanian Deadlift", muscleGroup: "Legs", equipment: "barbell"))
        context.insert(Exercise(name: "Hip Thrust", muscleGroup: "Legs", equipment: "barbell"))
        context.insert(Exercise(name: "Bulgarian Split Squat", muscleGroup: "Legs", equipment: "dumbbell"))
        context.insert(Exercise(name: "Goblet Squat", muscleGroup: "Legs", equipment: "dumbbell"))

        // Core
        context.insert(Exercise(name: "Plank", muscleGroup: "Core", equipment: "bodyweight"))
        context.insert(Exercise(name: "Crunches", muscleGroup: "Core", equipment: "bodyweight"))
        context.insert(Exercise(name: "Russian Twist", muscleGroup: "Core", equipment: "bodyweight"))
        context.insert(Exercise(name: "Hanging Leg Raise", muscleGroup: "Core", equipment: "bodyweight"))
        context.insert(Exercise(name: "Ab Wheel Rollout", muscleGroup: "Core", equipment: "bodyweight"))
        context.insert(Exercise(name: "Cable Woodchop", muscleGroup: "Core", equipment: "cable"))

        // Cardio
        context.insert(Exercise(name: "Running", muscleGroup: "Cardio", equipment: "cardio"))
        context.insert(Exercise(name: "Cycling", muscleGroup: "Cardio", equipment: "cardio"))
        context.insert(Exercise(name: "Rowing Machine", muscleGroup: "Cardio", equipment: "cardio"))
        context.insert(Exercise(name: "Jump Rope", muscleGroup: "Cardio", equipment: "cardio"))
        context.insert(Exercise(name: "Stair Climber", muscleGroup: "Cardio", equipment: "cardio"))
        context.insert(Exercise(name: "Elliptical", muscleGroup: "Cardio", equipment: "cardio"))

        context.saveOrLog("SeedData.seedExercises")
    }

    // MARK: - Foods

    static func seedFoods(context: ModelContext) {
        // Proteins
        context.insert(Food(name: "Chicken Breast", servingSize: 4, servingUnit: "oz", calories: 120, protein: 26, carbs: 0, fat: 1.5))
        context.insert(Food(name: "Ground Beef 90/10", servingSize: 4, servingUnit: "oz", calories: 200, protein: 22, carbs: 0, fat: 11))
        context.insert(Food(name: "Salmon", servingSize: 4, servingUnit: "oz", calories: 200, protein: 22, carbs: 0, fat: 12))
        context.insert(Food(name: "Eggs", servingSize: 1, servingUnit: "large", calories: 70, protein: 6, carbs: 0.5, fat: 5))
        context.insert(Food(name: "Turkey Breast", servingSize: 4, servingUnit: "oz", calories: 120, protein: 26, carbs: 0, fat: 1))
        context.insert(Food(name: "Shrimp", servingSize: 4, servingUnit: "oz", calories: 100, protein: 24, carbs: 0, fat: 0.5))
        context.insert(Food(name: "Greek Yogurt", servingSize: 1, servingUnit: "cup", calories: 130, protein: 22, carbs: 8, fat: 0.7))
        context.insert(Food(name: "Cottage Cheese", servingSize: 1, servingUnit: "cup", calories: 220, protein: 25, carbs: 8, fat: 9))
        context.insert(Food(name: "Whey Protein", servingSize: 1, servingUnit: "scoop", calories: 120, protein: 24, carbs: 3, fat: 1))
        context.insert(Food(name: "Tofu", servingSize: 0.5, servingUnit: "cup", calories: 90, protein: 10, carbs: 2, fat: 5))
        context.insert(Food(name: "Tuna Canned", servingSize: 1, servingUnit: "can", calories: 190, protein: 42, carbs: 0, fat: 1))
        context.insert(Food(name: "Egg Whites", servingSize: 0.5, servingUnit: "cup", calories: 60, protein: 13, carbs: 0.5, fat: 0))

        // Grains
        context.insert(Food(name: "White Rice Cooked", servingSize: 1, servingUnit: "cup", calories: 205, protein: 4, carbs: 45, fat: 0.5))
        context.insert(Food(name: "Brown Rice Cooked", servingSize: 1, servingUnit: "cup", calories: 215, protein: 5, carbs: 45, fat: 1.8))
        context.insert(Food(name: "Oats Dry", servingSize: 0.5, servingUnit: "cup", calories: 150, protein: 5, carbs: 27, fat: 3))
        context.insert(Food(name: "Pasta Dry", servingSize: 2, servingUnit: "oz", calories: 200, protein: 7, carbs: 42, fat: 1))
        context.insert(Food(name: "Whole Wheat Bread", servingSize: 1, servingUnit: "slice", calories: 80, protein: 4, carbs: 14, fat: 1))
        context.insert(Food(name: "Sweet Potato", servingSize: 1, servingUnit: "medium", calories: 110, protein: 2, carbs: 26, fat: 0))
        context.insert(Food(name: "Potato", servingSize: 1, servingUnit: "medium", calories: 160, protein: 4, carbs: 37, fat: 0))
        context.insert(Food(name: "Quinoa Cooked", servingSize: 1, servingUnit: "cup", calories: 220, protein: 8, carbs: 39, fat: 3.5))

        // Fruits
        context.insert(Food(name: "Banana", servingSize: 1, servingUnit: "medium", calories: 105, protein: 1.3, carbs: 27, fat: 0.4))
        context.insert(Food(name: "Apple", servingSize: 1, servingUnit: "medium", calories: 95, protein: 0.5, carbs: 25, fat: 0.3))
        context.insert(Food(name: "Blueberries", servingSize: 1, servingUnit: "cup", calories: 85, protein: 1.1, carbs: 21, fat: 0.5))
        context.insert(Food(name: "Strawberries", servingSize: 1, servingUnit: "cup", calories: 50, protein: 1, carbs: 12, fat: 0.5))
        context.insert(Food(name: "Orange", servingSize: 1, servingUnit: "medium", calories: 65, protein: 1.3, carbs: 16, fat: 0.3))
        context.insert(Food(name: "Grapes", servingSize: 1, servingUnit: "cup", calories: 62, protein: 0.6, carbs: 16, fat: 0.3))

        // Vegetables
        context.insert(Food(name: "Broccoli", servingSize: 1, servingUnit: "cup", calories: 55, protein: 3.7, carbs: 11, fat: 0.6))
        context.insert(Food(name: "Spinach Raw", servingSize: 1, servingUnit: "cup", calories: 7, protein: 0.9, carbs: 1.1, fat: 0.1))
        context.insert(Food(name: "Asparagus", servingSize: 1, servingUnit: "cup", calories: 27, protein: 3, carbs: 5, fat: 0.2))
        context.insert(Food(name: "Green Beans", servingSize: 1, servingUnit: "cup", calories: 35, protein: 2, carbs: 8, fat: 0.1))
        context.insert(Food(name: "Bell Pepper", servingSize: 1, servingUnit: "medium", calories: 30, protein: 1, carbs: 7, fat: 0.3))
        context.insert(Food(name: "Avocado", servingSize: 0.5, servingUnit: "whole", calories: 120, protein: 1.5, carbs: 6, fat: 11))
        context.insert(Food(name: "Mixed Salad", servingSize: 2, servingUnit: "cups", calories: 20, protein: 1.5, carbs: 4, fat: 0.2))

        // Dairy
        context.insert(Food(name: "Whole Milk", servingSize: 1, servingUnit: "cup", calories: 150, protein: 8, carbs: 12, fat: 8))
        context.insert(Food(name: "Skim Milk", servingSize: 1, servingUnit: "cup", calories: 90, protein: 8, carbs: 13, fat: 0))
        context.insert(Food(name: "Cheddar Cheese", servingSize: 1, servingUnit: "oz", calories: 115, protein: 7, carbs: 0.4, fat: 9.5))
        context.insert(Food(name: "Mozzarella", servingSize: 1, servingUnit: "oz", calories: 85, protein: 6, carbs: 0.7, fat: 6))
        context.insert(Food(name: "Butter", servingSize: 1, servingUnit: "tbsp", calories: 100, protein: 0.1, carbs: 0, fat: 11.5))
        context.insert(Food(name: "Cream Cheese", servingSize: 1, servingUnit: "oz", calories: 100, protein: 2, carbs: 1, fat: 10))

        // Fats
        context.insert(Food(name: "Olive Oil", servingSize: 1, servingUnit: "tbsp", calories: 120, protein: 0, carbs: 0, fat: 14))
        context.insert(Food(name: "Peanut Butter", servingSize: 2, servingUnit: "tbsp", calories: 190, protein: 7, carbs: 7, fat: 16))
        context.insert(Food(name: "Almonds", servingSize: 1, servingUnit: "oz", calories: 164, protein: 6, carbs: 6, fat: 14))
        context.insert(Food(name: "Walnuts", servingSize: 1, servingUnit: "oz", calories: 185, protein: 4.3, carbs: 3.9, fat: 18.5))
        context.insert(Food(name: "Coconut Oil", servingSize: 1, servingUnit: "tbsp", calories: 120, protein: 0, carbs: 0, fat: 14))
        context.insert(Food(name: "Chia Seeds", servingSize: 1, servingUnit: "oz", calories: 140, protein: 5, carbs: 12, fat: 9))

        // Snacks
        context.insert(Food(name: "Protein Bar", servingSize: 1, servingUnit: "bar", calories: 210, protein: 20, carbs: 25, fat: 7))
        context.insert(Food(name: "Granola", servingSize: 0.5, servingUnit: "cup", calories: 200, protein: 5, carbs: 30, fat: 8))
        context.insert(Food(name: "Dark Chocolate", servingSize: 1, servingUnit: "oz", calories: 170, protein: 2.2, carbs: 13, fat: 12))
        context.insert(Food(name: "Honey", servingSize: 1, servingUnit: "tbsp", calories: 64, protein: 0.1, carbs: 17, fat: 0))
        context.insert(Food(name: "Hummus", servingSize: 2, servingUnit: "tbsp", calories: 70, protein: 2, carbs: 6, fat: 5))
        context.insert(Food(name: "Rice Cakes", servingSize: 2, servingUnit: "cakes", calories: 70, protein: 1.4, carbs: 15, fat: 0.5))

        context.saveOrLog("SeedData.seedFoods")
    }
}
