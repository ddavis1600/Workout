import { useState } from 'react';
import { ChevronDown, ChevronUp, Trash2 } from 'lucide-react';
import Card from '../ui/Card';
import { formatDate } from '../../utils/formatters';
import { useDeleteWorkout } from '../../hooks/useWorkouts';
import type { Workout } from '../../types';

interface WorkoutCardProps {
  workout: Workout;
}

export default function WorkoutCard({ workout }: WorkoutCardProps) {
  const [expanded, setExpanded] = useState(false);
  const deleteWorkout = useDeleteWorkout();

  const exerciseNames = [...new Set(workout.sets?.map((s) => s.exercise_name) ?? [])];
  const setCount = workout.set_count ?? workout.sets?.length ?? 0;

  function handleDelete(e: React.MouseEvent) {
    e.stopPropagation();
    if (confirm('Delete this workout?')) {
      deleteWorkout.mutate(workout.id);
    }
  }

  // Group sets by exercise
  const grouped = (workout.sets ?? []).reduce<Record<string, typeof workout.sets>>((acc, set) => {
    const name = set.exercise_name || `Exercise ${set.exercise_id}`;
    if (!acc[name]) acc[name] = [];
    acc[name].push(set);
    return acc;
  }, {});

  return (
    <Card className="cursor-pointer transition-colors hover:border-slate-600" onClick={() => setExpanded(!expanded)}>
      <div className="flex items-center justify-between">
        <div>
          <h3 className="font-semibold text-slate-100">{workout.name || 'Workout'}</h3>
          <p className="text-sm text-slate-400 mt-0.5">
            {formatDate(workout.date)} &middot; {exerciseNames.length} exercise{exerciseNames.length !== 1 ? 's' : ''} &middot; {setCount} set{setCount !== 1 ? 's' : ''}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={handleDelete}
            className="text-slate-500 hover:text-red-400 p-1 cursor-pointer"
          >
            <Trash2 size={16} />
          </button>
          {expanded ? <ChevronUp size={20} className="text-slate-400" /> : <ChevronDown size={20} className="text-slate-400" />}
        </div>
      </div>

      {expanded && workout.sets && workout.sets.length > 0 && (
        <div className="mt-4 space-y-4" onClick={(e) => e.stopPropagation()}>
          {Object.entries(grouped).map(([exerciseName, sets]) => (
            <div key={exerciseName}>
              <h4 className="text-sm font-medium text-emerald-400 mb-2">{exerciseName}</h4>
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-xs text-slate-500 uppercase">
                    <th className="text-left pb-1">Set</th>
                    <th className="text-center pb-1">Reps</th>
                    <th className="text-center pb-1">Weight</th>
                    <th className="text-center pb-1">RPE</th>
                  </tr>
                </thead>
                <tbody>
                  {sets.map((set, i) => (
                    <tr key={i} className="text-slate-300">
                      <td className="py-0.5">{set.set_number}</td>
                      <td className="text-center py-0.5">{set.reps}</td>
                      <td className="text-center py-0.5">{set.weight} lbs</td>
                      <td className="text-center py-0.5">{set.rpe || '-'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ))}
          {workout.notes && (
            <p className="text-xs text-slate-400 italic mt-2">Notes: {workout.notes}</p>
          )}
        </div>
      )}
    </Card>
  );
}
