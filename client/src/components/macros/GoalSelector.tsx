import Card from '../ui/Card';

interface GoalSelectorProps {
  selected: string;
  onSelect: (goal: string) => void;
}

const goals = [
  { value: 'cut', label: 'Cut', description: 'Lose fat', adjustment: '-500 cal' },
  { value: 'maintain', label: 'Maintain', description: 'Stay the same', adjustment: '+0 cal' },
  { value: 'bulk', label: 'Bulk', description: 'Build muscle', adjustment: '+300 cal' },
];

export default function GoalSelector({ selected, onSelect }: GoalSelectorProps) {
  return (
    <div>
      <h3 className="text-base font-semibold text-slate-100 mb-3">Goal</h3>
      <div className="grid grid-cols-3 gap-3">
        {goals.map((goal) => {
          const isActive = selected === goal.value;
          return (
            <Card
              key={goal.value}
              className={`cursor-pointer text-center transition-all ${
                isActive
                  ? '!border-emerald-500 bg-emerald-500/5'
                  : 'hover:border-slate-600'
              }`}
            >
              <div onClick={() => onSelect(goal.value)}>
                <p className={`font-semibold text-lg ${isActive ? 'text-emerald-400' : 'text-slate-200'}`}>
                  {goal.label}
                </p>
                <p className="text-xs text-slate-400 mt-1">{goal.description}</p>
                <p className={`text-sm mt-2 font-medium ${isActive ? 'text-emerald-400' : 'text-slate-500'}`}>
                  {goal.adjustment}
                </p>
              </div>
            </Card>
          );
        })}
      </div>
    </div>
  );
}
