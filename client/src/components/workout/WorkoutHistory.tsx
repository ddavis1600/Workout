import { useWorkouts } from '../../hooks/useWorkouts';
import WorkoutCard from './WorkoutCard';
import { Dumbbell } from 'lucide-react';

export default function WorkoutHistory() {
  const { data: workouts = [], isLoading } = useWorkouts();

  if (isLoading) {
    return (
      <div className="text-center py-12 text-slate-400">Loading workouts...</div>
    );
  }

  if (workouts.length === 0) {
    return (
      <div className="text-center py-16">
        <Dumbbell size={48} className="mx-auto text-slate-600 mb-4" />
        <h3 className="text-lg font-medium text-slate-300 mb-1">No workouts yet</h3>
        <p className="text-slate-400 text-sm">Start logging your first workout to see it here.</p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {workouts.map((workout) => (
        <WorkoutCard key={workout.id} workout={workout} />
      ))}
    </div>
  );
}
