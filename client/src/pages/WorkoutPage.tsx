import { Link } from 'react-router-dom';
import WorkoutForm from '../components/workout/WorkoutForm';
import { History } from 'lucide-react';

export default function WorkoutPage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-slate-100">Log Workout</h1>
        <Link
          to="/workouts/history"
          className="flex items-center gap-2 text-sm text-emerald-400 hover:text-emerald-300"
        >
          <History size={16} /> History
        </Link>
      </div>
      <WorkoutForm />
    </div>
  );
}
