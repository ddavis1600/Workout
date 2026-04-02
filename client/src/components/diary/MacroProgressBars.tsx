import ProgressBar from '../ui/ProgressBar';
import Card from '../ui/Card';
import type { MacroSummary, UserProfile } from '../../types';

interface MacroProgressBarsProps {
  consumed: MacroSummary;
  targets: Pick<UserProfile, 'calorie_target' | 'protein_target' | 'carb_target' | 'fat_target'>;
}

export default function MacroProgressBars({ consumed, targets }: MacroProgressBarsProps) {
  return (
    <Card>
      <h3 className="text-base font-semibold text-slate-100 mb-4">Macro Progress</h3>
      <div className="space-y-3">
        <ProgressBar
          label="Calories"
          value={consumed.total_calories}
          max={targets.calorie_target}
          unit=" cal"
        />
        <ProgressBar
          label="Protein"
          value={consumed.total_protein}
          max={targets.protein_target}
        />
        <ProgressBar
          label="Carbs"
          value={consumed.total_carbs}
          max={targets.carb_target}
        />
        <ProgressBar
          label="Fat"
          value={consumed.total_fat}
          max={targets.fat_target}
        />
      </div>
    </Card>
  );
}
