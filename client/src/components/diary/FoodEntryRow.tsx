import { Trash2 } from 'lucide-react';
import type { DiaryEntry } from '../../types';
import { formatNumber } from '../../utils/formatters';

interface FoodEntryRowProps {
  entry: DiaryEntry;
  onUpdateServings: (id: number, servings: number) => void;
  onDelete: (id: number) => void;
}

export default function FoodEntryRow({ entry, onUpdateServings, onDelete }: FoodEntryRowProps) {
  const food = entry.food;
  const servings = entry.servings;
  const calories = entry.total_calories ?? (food ? food.calories * servings : 0);
  const protein = entry.total_protein ?? (food ? food.protein * servings : 0);
  const carbs = entry.total_carbs ?? (food ? food.carbs * servings : 0);
  const fat = entry.total_fat ?? (food ? food.fat * servings : 0);

  return (
    <div className="flex items-center gap-3 py-2 border-b border-slate-700/50 last:border-0">
      <div className="flex-1 min-w-0">
        <p className="text-sm text-slate-200 truncate">{food?.name || 'Unknown Food'}</p>
        <p className="text-xs text-slate-500">
          P: {formatNumber(protein, 0)}g &middot; C: {formatNumber(carbs, 0)}g &middot; F: {formatNumber(fat, 0)}g
        </p>
      </div>
      <div className="flex items-center gap-2 shrink-0">
        <input
          type="number"
          value={servings}
          onChange={(e) => onUpdateServings(entry.id, Math.max(0.25, Number(e.target.value)))}
          min="0.25"
          step="0.25"
          className="w-16 bg-slate-700 border border-slate-600 rounded px-2 py-1 text-sm text-slate-100 text-center focus:outline-none focus:ring-1 focus:ring-emerald-500"
        />
        <span className="text-sm text-slate-300 w-16 text-right">{formatNumber(calories, 0)} cal</span>
        <button
          onClick={() => onDelete(entry.id)}
          className="text-slate-500 hover:text-red-400 cursor-pointer p-1"
        >
          <Trash2 size={14} />
        </button>
      </div>
    </div>
  );
}
