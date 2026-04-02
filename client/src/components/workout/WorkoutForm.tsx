import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { format } from 'date-fns';
import { Plus, Save } from 'lucide-react';
import ExercisePicker from './ExercisePicker';
import SetRow from './SetRow';
import Button from '../ui/Button';
import Input from '../ui/Input';
import Card from '../ui/Card';
import { useCreateWorkout } from '../../hooks/useWorkouts';
import type { Exercise, WorkoutSet } from '../../types';

interface ExerciseGroup {
  exercise: Exercise;
  sets: WorkoutSet[];
}

export default function WorkoutForm() {
  const navigate = useNavigate();
  const createWorkout = useCreateWorkout();
  const [name, setName] = useState('');
  const [date, setDate] = useState(format(new Date(), 'yyyy-MM-dd'));
  const [notes, setNotes] = useState('');
  const [exerciseGroups, setExerciseGroups] = useState<ExerciseGroup[]>([]);

  function addExercise(exercise: Exercise) {
    const exists = exerciseGroups.some((g) => g.exercise.id === exercise.id);
    if (exists) return;
    setExerciseGroups((prev) => [
      ...prev,
      {
        exercise,
        sets: [
          {
            exercise_id: exercise.id,
            exercise_name: exercise.name,
            set_number: 1,
            reps: 0,
            weight: 0,
          },
        ],
      },
    ]);
  }

  function addSet(groupIndex: number) {
    setExerciseGroups((prev) =>
      prev.map((g, i) => {
        if (i !== groupIndex) return g;
        return {
          ...g,
          sets: [
            ...g.sets,
            {
              exercise_id: g.exercise.id,
              exercise_name: g.exercise.name,
              set_number: g.sets.length + 1,
              reps: 0,
              weight: 0,
            },
          ],
        };
      })
    );
  }

  function updateSet(groupIndex: number, setIndex: number, updated: WorkoutSet) {
    setExerciseGroups((prev) =>
      prev.map((g, i) => {
        if (i !== groupIndex) return g;
        return {
          ...g,
          sets: g.sets.map((s, j) => (j === setIndex ? updated : s)),
        };
      })
    );
  }

  function deleteSet(groupIndex: number, setIndex: number) {
    setExerciseGroups((prev) =>
      prev.map((g, i) => {
        if (i !== groupIndex) return g;
        const newSets = g.sets
          .filter((_, j) => j !== setIndex)
          .map((s, idx) => ({ ...s, set_number: idx + 1 }));
        return { ...g, sets: newSets };
      }).filter((g) => g.sets.length > 0)
    );
  }

  function removeExercise(groupIndex: number) {
    setExerciseGroups((prev) => prev.filter((_, i) => i !== groupIndex));
  }

  async function handleSave() {
    const allSets = exerciseGroups.flatMap((g) => g.sets);
    if (allSets.length === 0) return;

    await createWorkout.mutateAsync({
      name: name || `Workout ${format(new Date(date), 'MMM d')}`,
      date,
      notes,
      duration_minutes: 0,
      sets: allSets,
    });
    navigate('/workouts/history');
  }

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <Input
          label="Workout Name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="e.g., Push Day"
        />
        <Input
          label="Date"
          type="date"
          value={date}
          onChange={(e) => setDate(e.target.value)}
        />
      </div>
      <Input
        label="Notes"
        value={notes}
        onChange={(e) => setNotes(e.target.value)}
        placeholder="Optional notes..."
      />

      {exerciseGroups.map((group, gi) => (
        <Card key={`${group.exercise.id}-${gi}`}>
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-base font-semibold text-slate-100">
              {group.exercise.name}
              <span className="ml-2 text-xs text-slate-400 font-normal">
                {group.exercise.muscle_group}
              </span>
            </h3>
            <button
              type="button"
              onClick={() => removeExercise(gi)}
              className="text-xs text-red-400 hover:text-red-300 cursor-pointer"
            >
              Remove
            </button>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-xs text-slate-400 uppercase">
                  <th className="pb-2 px-2 text-center w-12">Set</th>
                  <th className="pb-2 px-2 text-center">Reps</th>
                  <th className="pb-2 px-2 text-center">Weight</th>
                  <th className="pb-2 px-2 text-center">RPE</th>
                  <th className="pb-2 px-1 w-10" />
                </tr>
              </thead>
              <tbody>
                {group.sets.map((set, si) => (
                  <SetRow
                    key={si}
                    set={set}
                    onChange={(updated) => updateSet(gi, si, updated)}
                    onDelete={() => deleteSet(gi, si)}
                  />
                ))}
              </tbody>
            </table>
          </div>
          <button
            type="button"
            onClick={() => addSet(gi)}
            className="mt-2 text-sm text-emerald-400 hover:text-emerald-300 flex items-center gap-1 cursor-pointer"
          >
            <Plus size={14} /> Add Set
          </button>
        </Card>
      ))}

      <Card className="border-dashed !border-slate-600">
        <p className="text-sm text-slate-400 mb-3">Add an exercise to your workout</p>
        <ExercisePicker onSelect={addExercise} />
      </Card>

      <div className="flex justify-end">
        <Button
          onClick={handleSave}
          disabled={exerciseGroups.length === 0 || createWorkout.isPending}
        >
          <span className="flex items-center gap-2">
            <Save size={16} />
            {createWorkout.isPending ? 'Saving...' : 'Save Workout'}
          </span>
        </Button>
      </div>
    </div>
  );
}
