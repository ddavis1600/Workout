import { useState, useRef, useEffect } from 'react';
import { useExercises } from '../../hooks/useExercises';
import type { Exercise } from '../../types';
import { Search } from 'lucide-react';

interface ExercisePickerProps {
  onSelect: (exercise: Exercise) => void;
  muscleGroup?: string;
  placeholder?: string;
}

export default function ExercisePicker({ onSelect, muscleGroup, placeholder = 'Search exercises...' }: ExercisePickerProps) {
  const [query, setQuery] = useState('');
  const [isOpen, setIsOpen] = useState(false);
  const wrapperRef = useRef<HTMLDivElement>(null);
  const { data: exercises = [] } = useExercises(muscleGroup);

  const filtered = exercises.filter((ex) =>
    ex.name.toLowerCase().includes(query.toLowerCase())
  );

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (wrapperRef.current && !wrapperRef.current.contains(e.target as Node)) {
        setIsOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  function handleSelect(exercise: Exercise) {
    onSelect(exercise);
    setQuery('');
    setIsOpen(false);
  }

  return (
    <div ref={wrapperRef} className="relative">
      <div className="relative">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
        <input
          type="text"
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setIsOpen(true);
          }}
          onFocus={() => setIsOpen(true)}
          placeholder={placeholder}
          className="w-full bg-slate-700 border border-slate-600 rounded-lg pl-9 pr-3 py-2 text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
        />
      </div>
      {isOpen && filtered.length > 0 && (
        <ul className="absolute z-20 mt-1 w-full max-h-60 overflow-y-auto bg-slate-700 border border-slate-600 rounded-lg shadow-lg">
          {filtered.map((ex) => (
            <li
              key={ex.id}
              onClick={() => handleSelect(ex)}
              className="px-3 py-2 hover:bg-slate-600 cursor-pointer text-sm text-slate-200 flex justify-between"
            >
              <span>{ex.name}</span>
              <span className="text-slate-400 text-xs">{ex.muscle_group}</span>
            </li>
          ))}
        </ul>
      )}
      {isOpen && query && filtered.length === 0 && (
        <div className="absolute z-20 mt-1 w-full bg-slate-700 border border-slate-600 rounded-lg p-3 text-sm text-slate-400">
          No exercises found
        </div>
      )}
    </div>
  );
}
