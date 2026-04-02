import { useState } from 'react';
import ExercisePicker from '../components/workout/ExercisePicker';
import ExerciseChart from '../components/workout/ExerciseChart';
import Card from '../components/ui/Card';
import type { Exercise } from '../types';

export default function ExerciseProgressPage() {
  const [selected, setSelected] = useState<Exercise | null>(null);

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-slate-100">Exercise Progress</h1>

      <Card>
        <p className="text-sm text-slate-400 mb-3">Select an exercise to view progress</p>
        <ExercisePicker
          onSelect={(exercise) => setSelected(exercise)}
          placeholder="Search for an exercise..."
        />
        {selected && (
          <p className="mt-2 text-sm text-emerald-400">Selected: {selected.name}</p>
        )}
      </Card>

      {selected && (
        <ExerciseChart exerciseId={selected.id} exerciseName={selected.name} />
      )}
    </div>
  );
}
