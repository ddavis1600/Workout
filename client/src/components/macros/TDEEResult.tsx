import Card from '../ui/Card';

interface TDEEResultProps {
  tdee: number;
  adjustedCalories: number;
  goal: string;
}

export default function TDEEResult({ tdee, adjustedCalories, goal }: TDEEResultProps) {
  if (!tdee) return null;

  const goalLabel = goal === 'cut' ? 'Cutting' : goal === 'bulk' ? 'Bulking' : 'Maintenance';

  return (
    <Card>
      <h3 className="text-base font-semibold text-slate-100 mb-4">Daily Calories</h3>
      <div className="grid grid-cols-2 gap-6">
        <div className="text-center">
          <p className="text-sm text-slate-400 mb-1">Maintenance TDEE</p>
          <p className="text-3xl font-bold text-slate-200">{tdee}</p>
          <p className="text-xs text-slate-500 mt-1">calories/day</p>
        </div>
        <div className="text-center">
          <p className="text-sm text-slate-400 mb-1">{goalLabel} Target</p>
          <p className="text-3xl font-bold text-emerald-400">{adjustedCalories}</p>
          <p className="text-xs text-slate-500 mt-1">calories/day</p>
        </div>
      </div>
    </Card>
  );
}
