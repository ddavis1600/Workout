import { X } from 'lucide-react';
import type { WorkoutSet } from '../../types';

interface SetRowProps {
  set: WorkoutSet;
  onChange: (updated: WorkoutSet) => void;
  onDelete: () => void;
}

export default function SetRow({ set, onChange, onDelete }: SetRowProps) {
  function handleChange(field: keyof WorkoutSet, value: string) {
    const num = value === '' ? 0 : Number(value);
    onChange({ ...set, [field]: num });
  }

  return (
    <tr className="border-b border-slate-700/50">
      <td className="py-2 px-2 text-center text-slate-400 text-sm w-12">
        {set.set_number}
      </td>
      <td className="py-2 px-2">
        <input
          type="number"
          value={set.reps || ''}
          onChange={(e) => handleChange('reps', e.target.value)}
          placeholder="0"
          className="w-full bg-slate-700 border border-slate-600 rounded px-2 py-1 text-sm text-slate-100 text-center focus:outline-none focus:ring-1 focus:ring-emerald-500"
        />
      </td>
      <td className="py-2 px-2">
        <input
          type="number"
          value={set.weight || ''}
          onChange={(e) => handleChange('weight', e.target.value)}
          placeholder="0"
          step="2.5"
          className="w-full bg-slate-700 border border-slate-600 rounded px-2 py-1 text-sm text-slate-100 text-center focus:outline-none focus:ring-1 focus:ring-emerald-500"
        />
      </td>
      <td className="py-2 px-2">
        <input
          type="number"
          value={set.rpe || ''}
          onChange={(e) => handleChange('rpe', e.target.value)}
          placeholder="-"
          min="1"
          max="10"
          className="w-full bg-slate-700 border border-slate-600 rounded px-2 py-1 text-sm text-slate-100 text-center focus:outline-none focus:ring-1 focus:ring-emerald-500"
        />
      </td>
      <td className="py-2 px-1 text-center w-10">
        <button
          type="button"
          onClick={onDelete}
          className="text-slate-500 hover:text-red-400 cursor-pointer"
        >
          <X size={16} />
        </button>
      </td>
    </tr>
  );
}
