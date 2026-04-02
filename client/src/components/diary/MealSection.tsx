import { Plus } from 'lucide-react';
import Card from '../ui/Card';
import FoodEntryRow from './FoodEntryRow';
import type { DiaryEntry } from '../../types';
import { formatNumber } from '../../utils/formatters';

interface MealSectionProps {
  mealType: string;
  entries: DiaryEntry[];
  onAddFood: (mealType: string) => void;
  onUpdateServings: (id: number, servings: number) => void;
  onDelete: (id: number) => void;
}

const mealLabels: Record<string, string> = {
  breakfast: 'Breakfast',
  lunch: 'Lunch',
  dinner: 'Dinner',
  snack: 'Snacks',
};

export default function MealSection({ mealType, entries, onAddFood, onUpdateServings, onDelete }: MealSectionProps) {
  const totalCalories = entries.reduce((sum, e) => {
    const cal = e.total_calories ?? (e.food ? e.food.calories * e.servings : 0);
    return sum + cal;
  }, 0);

  return (
    <Card>
      <div className="flex items-center justify-between mb-3">
        <div>
          <h3 className="font-semibold text-slate-100">{mealLabels[mealType] || mealType}</h3>
          <p className="text-xs text-slate-400">{formatNumber(totalCalories, 0)} calories</p>
        </div>
        <button
          onClick={() => onAddFood(mealType)}
          className="flex items-center gap-1 text-sm text-emerald-400 hover:text-emerald-300 cursor-pointer"
        >
          <Plus size={16} /> Add Food
        </button>
      </div>

      {entries.length === 0 ? (
        <p className="text-sm text-slate-500 py-2">No foods logged</p>
      ) : (
        <div>
          {entries.map((entry) => (
            <FoodEntryRow
              key={entry.id}
              entry={entry}
              onUpdateServings={onUpdateServings}
              onDelete={onDelete}
            />
          ))}
        </div>
      )}
    </Card>
  );
}
