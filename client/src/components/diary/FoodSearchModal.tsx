import { useState, useEffect, useRef } from 'react';
import Modal from '../ui/Modal';
import Button from '../ui/Button';
import { searchFoods } from '../../api/foods';
import type { Food } from '../../types';
import { formatNumber } from '../../utils/formatters';
import { Search } from 'lucide-react';

interface FoodSearchModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAdd: (food: Food, servings: number) => void;
}

export default function FoodSearchModal({ isOpen, onClose, onAdd }: FoodSearchModalProps) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Food[]>([]);
  const [loading, setLoading] = useState(false);
  const [servings, setServings] = useState<Record<number, number>>({});
  const debounceRef = useRef<ReturnType<typeof setTimeout>>();

  useEffect(() => {
    if (!query.trim()) {
      setResults([]);
      return;
    }

    if (debounceRef.current) clearTimeout(debounceRef.current);

    debounceRef.current = setTimeout(async () => {
      setLoading(true);
      try {
        const data = await searchFoods(query);
        setResults(data);
      } catch {
        setResults([]);
      } finally {
        setLoading(false);
      }
    }, 300);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query]);

  useEffect(() => {
    if (!isOpen) {
      setQuery('');
      setResults([]);
      setServings({});
    }
  }, [isOpen]);

  function handleAdd(food: Food) {
    const amount = servings[food.id] || 1;
    onAdd(food, amount);
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Add Food">
      <div className="relative mb-4">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search foods..."
          autoFocus
          className="w-full bg-slate-700 border border-slate-600 rounded-lg pl-9 pr-3 py-2 text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-emerald-500"
        />
      </div>

      {loading && <p className="text-sm text-slate-400 text-center py-4">Searching...</p>}

      {!loading && query && results.length === 0 && (
        <p className="text-sm text-slate-400 text-center py-4">No foods found for "{query}"</p>
      )}

      <div className="space-y-2 max-h-80 overflow-y-auto">
        {results.map((food) => (
          <div
            key={food.id}
            className="flex items-center gap-3 p-3 bg-slate-700/50 rounded-lg"
          >
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-slate-200 truncate">{food.name}</p>
              <p className="text-xs text-slate-400">
                {food.serving_size}{food.serving_unit} &middot; {formatNumber(food.calories, 0)} cal &middot;
                P: {formatNumber(food.protein, 0)}g C: {formatNumber(food.carbs, 0)}g F: {formatNumber(food.fat, 0)}g
              </p>
            </div>
            <input
              type="number"
              value={servings[food.id] ?? 1}
              onChange={(e) =>
                setServings((prev) => ({ ...prev, [food.id]: Math.max(0.25, Number(e.target.value)) }))
              }
              min="0.25"
              step="0.25"
              className="w-16 bg-slate-600 border border-slate-500 rounded px-2 py-1 text-sm text-slate-100 text-center focus:outline-none focus:ring-1 focus:ring-emerald-500"
            />
            <Button size="sm" onClick={() => handleAdd(food)}>
              Add
            </Button>
          </div>
        ))}
      </div>
    </Modal>
  );
}
