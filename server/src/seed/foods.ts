import db from '../db/connection';

interface FoodSeed {
  name: string;
  brand: string | null;
  serving_size: number;
  serving_unit: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

const foods: FoodSeed[] = [
  // Proteins
  { name: 'Chicken Breast', brand: null, serving_size: 4, serving_unit: 'oz', calories: 130, protein: 26, carbs: 0, fat: 3 },
  { name: 'Ground Beef 90/10', brand: null, serving_size: 4, serving_unit: 'oz', calories: 200, protein: 22, carbs: 0, fat: 11 },
  { name: 'Salmon', brand: null, serving_size: 4, serving_unit: 'oz', calories: 208, protein: 23, carbs: 0, fat: 12 },
  { name: 'Tuna Canned in Water', brand: null, serving_size: 142, serving_unit: 'g', calories: 150, protein: 33, carbs: 0, fat: 1.5 },
  { name: 'Egg', brand: null, serving_size: 1, serving_unit: 'large', calories: 72, protein: 6, carbs: 0.4, fat: 5 },
  { name: 'Egg Whites', brand: null, serving_size: 0.5, serving_unit: 'cup', calories: 63, protein: 13, carbs: 0.5, fat: 0 },
  { name: 'Turkey Breast', brand: null, serving_size: 4, serving_unit: 'oz', calories: 120, protein: 26, carbs: 0, fat: 1 },
  { name: 'Shrimp', brand: null, serving_size: 4, serving_unit: 'oz', calories: 120, protein: 23, carbs: 1, fat: 2 },
  { name: 'Greek Yogurt (Plain, Nonfat)', brand: null, serving_size: 1, serving_unit: 'cup', calories: 130, protein: 22, carbs: 9, fat: 0.7 },
  { name: 'Cottage Cheese (2%)', brand: null, serving_size: 1, serving_unit: 'cup', calories: 183, protein: 24, carbs: 9.5, fat: 5 },
  { name: 'Whey Protein Powder', brand: null, serving_size: 30, serving_unit: 'g', calories: 120, protein: 24, carbs: 3, fat: 1.5 },
  { name: 'Tofu (Firm)', brand: null, serving_size: 0.5, serving_unit: 'cup', calories: 88, protein: 10, carbs: 2, fat: 5 },

  // Grains/Carbs
  { name: 'White Rice (Cooked)', brand: null, serving_size: 1, serving_unit: 'cup', calories: 206, protein: 4.3, carbs: 45, fat: 0.4 },
  { name: 'Brown Rice (Cooked)', brand: null, serving_size: 1, serving_unit: 'cup', calories: 216, protein: 5, carbs: 45, fat: 1.8 },
  { name: 'Oats (Dry)', brand: null, serving_size: 0.5, serving_unit: 'cup', calories: 150, protein: 5, carbs: 27, fat: 3 },
  { name: 'Pasta (Dry)', brand: null, serving_size: 2, serving_unit: 'oz', calories: 200, protein: 7, carbs: 42, fat: 1 },
  { name: 'Whole Wheat Bread', brand: null, serving_size: 1, serving_unit: 'slice', calories: 81, protein: 4, carbs: 14, fat: 1 },
  { name: 'Sweet Potato', brand: null, serving_size: 1, serving_unit: 'medium', calories: 103, protein: 2, carbs: 24, fat: 0.1 },
  { name: 'Potato', brand: null, serving_size: 1, serving_unit: 'medium', calories: 161, protein: 4.3, carbs: 37, fat: 0.2 },
  { name: 'Quinoa (Cooked)', brand: null, serving_size: 1, serving_unit: 'cup', calories: 222, protein: 8, carbs: 39, fat: 3.5 },

  // Fruits
  { name: 'Banana', brand: null, serving_size: 1, serving_unit: 'medium', calories: 105, protein: 1.3, carbs: 27, fat: 0.4 },
  { name: 'Apple', brand: null, serving_size: 1, serving_unit: 'medium', calories: 95, protein: 0.5, carbs: 25, fat: 0.3 },
  { name: 'Blueberries', brand: null, serving_size: 1, serving_unit: 'cup', calories: 84, protein: 1.1, carbs: 21, fat: 0.5 },
  { name: 'Strawberries', brand: null, serving_size: 1, serving_unit: 'cup', calories: 49, protein: 1, carbs: 12, fat: 0.5 },
  { name: 'Orange', brand: null, serving_size: 1, serving_unit: 'medium', calories: 62, protein: 1.2, carbs: 15, fat: 0.2 },
  { name: 'Grapes', brand: null, serving_size: 1, serving_unit: 'cup', calories: 104, protein: 1.1, carbs: 27, fat: 0.2 },

  // Vegetables
  { name: 'Broccoli', brand: null, serving_size: 1, serving_unit: 'cup', calories: 55, protein: 3.7, carbs: 11, fat: 0.6 },
  { name: 'Spinach (Raw)', brand: null, serving_size: 1, serving_unit: 'cup', calories: 7, protein: 0.9, carbs: 1.1, fat: 0.1 },
  { name: 'Asparagus', brand: null, serving_size: 1, serving_unit: 'cup', calories: 27, protein: 3, carbs: 5, fat: 0.2 },
  { name: 'Green Beans', brand: null, serving_size: 1, serving_unit: 'cup', calories: 31, protein: 1.8, carbs: 7, fat: 0.1 },
  { name: 'Bell Pepper', brand: null, serving_size: 1, serving_unit: 'medium', calories: 31, protein: 1, carbs: 7, fat: 0.3 },
  { name: 'Avocado', brand: null, serving_size: 0.5, serving_unit: 'medium', calories: 120, protein: 1.5, carbs: 6, fat: 11 },
  { name: 'Mixed Salad Greens', brand: null, serving_size: 2, serving_unit: 'cups', calories: 15, protein: 1.5, carbs: 2, fat: 0.2 },

  // Dairy
  { name: 'Whole Milk', brand: null, serving_size: 1, serving_unit: 'cup', calories: 149, protein: 8, carbs: 12, fat: 8 },
  { name: 'Skim Milk', brand: null, serving_size: 1, serving_unit: 'cup', calories: 83, protein: 8, carbs: 12, fat: 0.2 },
  { name: 'Cheddar Cheese', brand: null, serving_size: 1, serving_unit: 'oz', calories: 113, protein: 7, carbs: 0.4, fat: 9 },
  { name: 'Mozzarella Cheese', brand: null, serving_size: 1, serving_unit: 'oz', calories: 85, protein: 6, carbs: 0.7, fat: 6 },
  { name: 'Butter', brand: null, serving_size: 1, serving_unit: 'tbsp', calories: 102, protein: 0.1, carbs: 0, fat: 12 },
  { name: 'Cream Cheese', brand: null, serving_size: 1, serving_unit: 'oz', calories: 99, protein: 1.7, carbs: 1.6, fat: 10 },

  // Fats/Nuts
  { name: 'Olive Oil', brand: null, serving_size: 1, serving_unit: 'tbsp', calories: 119, protein: 0, carbs: 0, fat: 14 },
  { name: 'Peanut Butter', brand: null, serving_size: 2, serving_unit: 'tbsp', calories: 188, protein: 8, carbs: 6, fat: 16 },
  { name: 'Almonds', brand: null, serving_size: 1, serving_unit: 'oz', calories: 164, protein: 6, carbs: 6, fat: 14 },
  { name: 'Walnuts', brand: null, serving_size: 1, serving_unit: 'oz', calories: 185, protein: 4.3, carbs: 3.9, fat: 18 },
  { name: 'Coconut Oil', brand: null, serving_size: 1, serving_unit: 'tbsp', calories: 121, protein: 0, carbs: 0, fat: 14 },
  { name: 'Chia Seeds', brand: null, serving_size: 1, serving_unit: 'oz', calories: 138, protein: 4.7, carbs: 12, fat: 8.7 },

  // Snacks/Other
  { name: 'Protein Bar', brand: null, serving_size: 1, serving_unit: 'bar', calories: 210, protein: 20, carbs: 22, fat: 7 },
  { name: 'Granola', brand: null, serving_size: 0.5, serving_unit: 'cup', calories: 200, protein: 5, carbs: 29, fat: 8 },
  { name: 'Dark Chocolate (70%)', brand: null, serving_size: 1, serving_unit: 'oz', calories: 170, protein: 2.2, carbs: 13, fat: 12 },
  { name: 'Honey', brand: null, serving_size: 1, serving_unit: 'tbsp', calories: 64, protein: 0.1, carbs: 17, fat: 0 },
  { name: 'Hummus', brand: null, serving_size: 2, serving_unit: 'tbsp', calories: 70, protein: 2, carbs: 6, fat: 5 },
  { name: 'Rice Cakes', brand: null, serving_size: 2, serving_unit: 'cakes', calories: 70, protein: 1.4, carbs: 15, fat: 0.5 },

  // Additional proteins
  { name: 'Pork Chop', brand: null, serving_size: 4, serving_unit: 'oz', calories: 187, protein: 23, carbs: 0, fat: 10 },
  { name: 'Tilapia', brand: null, serving_size: 4, serving_unit: 'oz', calories: 110, protein: 23, carbs: 0, fat: 2 },
  { name: 'Cod', brand: null, serving_size: 4, serving_unit: 'oz', calories: 93, protein: 20, carbs: 0, fat: 0.8 },
  { name: 'Beef Steak (Sirloin)', brand: null, serving_size: 4, serving_unit: 'oz', calories: 207, protein: 24, carbs: 0, fat: 12 },
  { name: 'Ham (Deli)', brand: null, serving_size: 2, serving_unit: 'oz', calories: 60, protein: 10, carbs: 1, fat: 2 },
  { name: 'Turkey Deli Meat', brand: null, serving_size: 2, serving_unit: 'oz', calories: 50, protein: 10, carbs: 1, fat: 0.5 },

  // Additional carbs
  { name: 'Bagel', brand: null, serving_size: 1, serving_unit: 'medium', calories: 270, protein: 10, carbs: 53, fat: 1.5 },
  { name: 'Tortilla (Flour)', brand: null, serving_size: 1, serving_unit: 'large', calories: 220, protein: 6, carbs: 36, fat: 6 },
  { name: 'English Muffin', brand: null, serving_size: 1, serving_unit: 'muffin', calories: 132, protein: 5, carbs: 26, fat: 1 },

  // Additional vegetables
  { name: 'Carrots', brand: null, serving_size: 1, serving_unit: 'cup', calories: 52, protein: 1.2, carbs: 12, fat: 0.3 },
  { name: 'Cucumber', brand: null, serving_size: 1, serving_unit: 'cup', calories: 16, protein: 0.7, carbs: 3.1, fat: 0.2 },
  { name: 'Tomato', brand: null, serving_size: 1, serving_unit: 'medium', calories: 22, protein: 1.1, carbs: 4.8, fat: 0.2 },
  { name: 'Mushrooms', brand: null, serving_size: 1, serving_unit: 'cup', calories: 15, protein: 2.2, carbs: 2.3, fat: 0.2 },
  { name: 'Corn', brand: null, serving_size: 1, serving_unit: 'cup', calories: 132, protein: 5, carbs: 29, fat: 1.8 },
  { name: 'Cauliflower', brand: null, serving_size: 1, serving_unit: 'cup', calories: 27, protein: 2, carbs: 5, fat: 0.3 },

  // Additional dairy/other
  { name: 'String Cheese', brand: null, serving_size: 1, serving_unit: 'stick', calories: 80, protein: 7, carbs: 0.5, fat: 6 },
  { name: 'Sour Cream', brand: null, serving_size: 2, serving_unit: 'tbsp', calories: 57, protein: 0.7, carbs: 1.1, fat: 5.6 },
  { name: 'Mayonnaise', brand: null, serving_size: 1, serving_unit: 'tbsp', calories: 94, protein: 0.1, carbs: 0, fat: 10 },
  { name: 'Ketchup', brand: null, serving_size: 1, serving_unit: 'tbsp', calories: 20, protein: 0.2, carbs: 5, fat: 0 },
];

export function seedFoods(): void {
  const count = db.prepare('SELECT COUNT(*) as count FROM foods').get() as { count: number };
  if (count.count > 0) {
    console.log('Foods table already seeded, skipping.');
    return;
  }

  const insert = db.prepare(
    'INSERT INTO foods (name, brand, serving_size, serving_unit, calories, protein, carbs, fat, is_custom) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)'
  );

  const insertMany = db.transaction((items: FoodSeed[]) => {
    for (const item of items) {
      insert.run(
        item.name,
        item.brand,
        item.serving_size,
        item.serving_unit,
        item.calories,
        item.protein,
        item.carbs,
        item.fat
      );
    }
  });

  insertMany(foods);
  console.log(`Seeded ${foods.length} foods.`);
}
