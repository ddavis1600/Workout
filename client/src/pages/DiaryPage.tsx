import { useState } from 'react';
import { format } from 'date-fns';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import MealSection from '../components/diary/MealSection';
import FoodSearchModal from '../components/diary/FoodSearchModal';
import MacroProgressBars from '../components/diary/MacroProgressBars';
import { useDiaryEntries, useAddDiaryEntry, useUpdateDiaryEntry, useDeleteDiaryEntry, useDiarySummary } from '../hooks/useDiary';
import { useProfile } from '../hooks/useMacros';
import { MEAL_TYPES } from '../utils/constants';
import type { Food } from '../types';

export default function DiaryPage() {
  const [date, setDate] = useState(format(new Date(), 'yyyy-MM-dd'));
  const [modalOpen, setModalOpen] = useState(false);
  const [activeMeal, setActiveMeal] = useState('breakfast');

  const { data: entries = [] } = useDiaryEntries(date);
  const { data: summary } = useDiarySummary(date);
  const { data: profile } = useProfile();
  const addEntry = useAddDiaryEntry();
  const updateEntry = useUpdateDiaryEntry();
  const deleteEntry = useDeleteDiaryEntry();

  const consumed = summary || { total_calories: 0, total_protein: 0, total_carbs: 0, total_fat: 0 };
  const targets = {
    calorie_target: profile?.calorie_target || 2000,
    protein_target: profile?.protein_target || 150,
    carb_target: profile?.carb_target || 200,
    fat_target: profile?.fat_target || 65,
  };

  function openFoodModal(mealType: string) {
    setActiveMeal(mealType);
    setModalOpen(true);
  }

  function handleAddFood(food: Food, servings: number) {
    addEntry.mutate({
      date,
      meal_type: activeMeal,
      food_id: food.id,
      servings,
    });
    setModalOpen(false);
  }

  function handleUpdateServings(id: number, servings: number) {
    updateEntry.mutate({ id, entry: { servings } });
  }

  function handleDelete(id: number) {
    deleteEntry.mutate(id);
  }

  function shiftDate(days: number) {
    const d = new Date(date + 'T00:00:00');
    d.setDate(d.getDate() + days);
    setDate(format(d, 'yyyy-MM-dd'));
  }

  const displayDate = format(new Date(date + 'T00:00:00'), 'EEEE, MMM d, yyyy');

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-slate-100">Food Diary</h1>

      <div className="flex items-center justify-center gap-4">
        <button onClick={() => shiftDate(-1)} className="text-slate-400 hover:text-slate-200 cursor-pointer p-1">
          <ChevronLeft size={20} />
        </button>
        <div className="text-center">
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="bg-transparent border-none text-slate-100 text-center font-medium cursor-pointer focus:outline-none"
          />
          <p className="text-xs text-slate-400">{displayDate}</p>
        </div>
        <button onClick={() => shiftDate(1)} className="text-slate-400 hover:text-slate-200 cursor-pointer p-1">
          <ChevronRight size={20} />
        </button>
      </div>

      <MacroProgressBars consumed={consumed} targets={targets} />

      {MEAL_TYPES.map((meal) => {
        const mealEntries = entries.filter((e) => e.meal_type === meal);
        return (
          <MealSection
            key={meal}
            mealType={meal}
            entries={mealEntries}
            onAddFood={openFoodModal}
            onUpdateServings={handleUpdateServings}
            onDelete={handleDelete}
          />
        );
      })}

      <FoodSearchModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        onAdd={handleAddFood}
      />
    </div>
  );
}
