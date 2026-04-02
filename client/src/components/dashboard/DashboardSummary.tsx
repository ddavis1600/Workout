import { format } from 'date-fns';
import Card from '../ui/Card';
import { Dumbbell } from 'lucide-react';

export default function DashboardSummary() {
  const today = format(new Date(), 'EEEE, MMMM d, yyyy');

  return (
    <Card>
      <div className="flex items-center gap-4">
        <div className="p-3 bg-emerald-500/10 rounded-xl">
          <Dumbbell size={28} className="text-emerald-500" />
        </div>
        <div>
          <h1 className="text-xl font-bold text-slate-100">Welcome to FitTrack</h1>
          <p className="text-sm text-slate-400">{today}</p>
        </div>
      </div>
    </Card>
  );
}
