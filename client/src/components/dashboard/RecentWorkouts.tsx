import { Link } from 'react-router-dom';
import { useWorkouts } from '../../hooks/useWorkouts';
import Card from '../ui/Card';
import { formatDate } from '../../utils/formatters';
import { Dumbbell, ArrowRight } from 'lucide-react';

export default function RecentWorkouts() {
  const { data: workouts = [], isLoading } = useWorkouts();
  const recent = workouts.slice(0, 5);

  return (
    <Card>
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-base font-semibold text-slate-100">Recent Workouts</h3>
        <Link to="/workouts/history" className="text-sm text-emerald-400 hover:text-emerald-300 flex items-center gap-1">
          View All <ArrowRight size={14} />
        </Link>
      </div>

      {isLoading ? (
        <p className="text-sm text-slate-400">Loading...</p>
      ) : recent.length === 0 ? (
        <div className="text-center py-6">
          <Dumbbell size={32} className="mx-auto text-slate-600 mb-2" />
          <p className="text-sm text-slate-400">No workouts yet</p>
          <Link to="/workouts" className="text-sm text-emerald-400 hover:text-emerald-300 mt-1 inline-block">
            Log your first workout
          </Link>
        </div>
      ) : (
        <div className="space-y-2">
          {recent.map((w) => {
            const exerciseNames = [...new Set(w.sets?.map((s) => s.exercise_name) ?? [])];
            const setCount = w.set_count ?? w.sets?.length ?? 0;
            return (
              <div key={w.id} className="flex items-center justify-between py-2 border-b border-slate-700/50 last:border-0">
                <div>
                  <p className="text-sm font-medium text-slate-200">{w.name || 'Workout'}</p>
                  <p className="text-xs text-slate-500">
                    {exerciseNames.length} exercise{exerciseNames.length !== 1 ? 's' : ''} &middot; {setCount} set{setCount !== 1 ? 's' : ''}
                  </p>
                </div>
                <span className="text-xs text-slate-400">{formatDate(w.date)}</span>
              </div>
            );
          })}
        </div>
      )}
    </Card>
  );
}
