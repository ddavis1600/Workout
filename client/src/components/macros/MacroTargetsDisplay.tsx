import Card from '../ui/Card';

interface MacroTargetsDisplayProps {
  protein: number;
  carbs: number;
  fat: number;
}

export default function MacroTargetsDisplay({ protein, carbs, fat }: MacroTargetsDisplayProps) {
  if (!protein && !carbs && !fat) return null;

  const macros = [
    { label: 'Protein', value: protein, color: 'text-blue-400', bg: 'bg-blue-500/10', border: 'border-blue-500/30', cal: protein * 4 },
    { label: 'Carbs', value: carbs, color: 'text-amber-400', bg: 'bg-amber-500/10', border: 'border-amber-500/30', cal: carbs * 4 },
    { label: 'Fat', value: fat, color: 'text-rose-400', bg: 'bg-rose-500/10', border: 'border-rose-500/30', cal: fat * 9 },
  ];

  const totalCal = macros.reduce((sum, m) => sum + m.cal, 0);

  return (
    <div>
      <h3 className="text-base font-semibold text-slate-100 mb-3">Macro Targets</h3>
      <div className="grid grid-cols-3 gap-3">
        {macros.map((m) => (
          <Card key={m.label} className={`text-center ${m.bg} !border ${m.border}`}>
            <p className="text-xs text-slate-400 mb-1">{m.label}</p>
            <p className={`text-2xl font-bold ${m.color}`}>{m.value}g</p>
            <p className="text-xs text-slate-500 mt-1">
              {m.cal} cal ({totalCal > 0 ? Math.round((m.cal / totalCal) * 100) : 0}%)
            </p>
          </Card>
        ))}
      </div>
    </div>
  );
}
