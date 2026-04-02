import { formatNumber } from '../../utils/formatters';

interface ProgressBarProps {
  label: string;
  value: number;
  max: number;
  unit?: string;
}

export default function ProgressBar({ label, value, max, unit = 'g' }: ProgressBarProps) {
  const percentage = max > 0 ? (value / max) * 100 : 0;
  const capped = Math.min(percentage, 100);

  let barColor = 'bg-emerald-500';
  if (percentage >= 100) {
    barColor = 'bg-red-500';
  } else if (percentage >= 80) {
    barColor = 'bg-amber-500';
  }

  return (
    <div className="space-y-1">
      <div className="flex justify-between text-sm">
        <span className="text-slate-400">{label}</span>
        <span className="text-slate-300">
          {formatNumber(value, 0)}{unit} / {formatNumber(max, 0)}{unit}
        </span>
      </div>
      <div className="h-2.5 bg-slate-700 rounded-full overflow-hidden">
        <div
          className={`h-full rounded-full transition-all duration-300 ${barColor}`}
          style={{ width: `${capped}%` }}
        />
      </div>
    </div>
  );
}
