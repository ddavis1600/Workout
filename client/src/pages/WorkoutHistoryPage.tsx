import { Link } from 'react-router-dom';
import WorkoutHistory from '../components/workout/WorkoutHistory';
import { Plus } from 'lucide-react';
import Button from '../components/ui/Button';

export default function WorkoutHistoryPage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-slate-100">Workout History</h1>
        <Link to="/workouts">
          <Button size="sm">
            <span className="flex items-center gap-1">
              <Plus size={16} /> New Workout
            </span>
          </Button>
        </Link>
      </div>
      <WorkoutHistory />
    </div>
  );
}
