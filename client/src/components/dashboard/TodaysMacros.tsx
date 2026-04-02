import { format } from 'date-fns';
import { useDiarySummary } from '../../hooks/useDiary';
import { useProfile } from '../../hooks/useMacros';
import MacroProgressBars from '../diary/MacroProgressBars';

export default function TodaysMacros() {
  const today = format(new Date(), 'yyyy-MM-dd');
  const { data: summary } = useDiarySummary(today);
  const { data: profile } = useProfile();

  const consumed = summary || { total_calories: 0, total_protein: 0, total_carbs: 0, total_fat: 0 };
  const targets = {
    calorie_target: profile?.calorie_target || 2000,
    protein_target: profile?.protein_target || 150,
    carb_target: profile?.carb_target || 200,
    fat_target: profile?.fat_target || 65,
  };

  return <MacroProgressBars consumed={consumed} targets={targets} />;
}
