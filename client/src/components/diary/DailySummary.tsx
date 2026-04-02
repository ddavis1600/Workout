import Card from '../ui/Card';
import { formatNumber } from '../../utils/formatters';
import type { MacroSummary } from '../../types';

interface DailySummaryProps {
  summary: MacroSummary;
}

export default function DailySummary({ summary }: DailySummaryProps) {
  const stats = [
    { label: 'Calories', value: summary.total_calories, unit: 'cal', color: 'text-emerald-400' },
    { label: 'Protein', value: summary.total_protein, unit: 'g', color: 'text-blue-400' },
    { label: 'Carbs', value: summary.total_carbs, unit: 'g', color: 'text-amber-400' },
    { label: 'Fat', value: summary.total_fat, unit: 'g', color: 'text-rose-400' },
  ];

  return (
    <Card>
      <h3 className="text-base font-semibold text-slate-100 mb-3">Daily Total</h3>
      <div className="grid grid-cols-4 gap-4">
        {stats.map((s) => (
          <div key={s.label} className="text-center">
            <p className="text-xs text-slate-400">{s.label}</p>
            <p className={`text-xl font-bold ${s.color}`}>
              {formatNumber(s.value, 0)}
            </p>
            <p className="text-xs text-slate-500">{s.unit}</p>
          </div>
        ))}
      </div>
    </Card>
  );
}
