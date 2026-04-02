import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { useExerciseProgress } from '../../hooks/useWorkouts';
import Card from '../ui/Card';
import { formatDate } from '../../utils/formatters';

interface ExerciseChartProps {
  exerciseId: number;
  exerciseName: string;
}

export default function ExerciseChart({ exerciseId, exerciseName }: ExerciseChartProps) {
  const { data: progress = [], isLoading } = useExerciseProgress(exerciseId);

  if (isLoading) {
    return <Card><div className="text-slate-400 text-center py-8">Loading progress...</div></Card>;
  }

  if (progress.length === 0) {
    return (
      <Card>
        <div className="text-slate-400 text-center py-8">
          No data yet for {exerciseName}. Log some workouts to see progress.
        </div>
      </Card>
    );
  }

  const chartData = progress.map((p) => ({
    ...p,
    dateLabel: formatDate(p.date, 'MMM d'),
  }));

  return (
    <Card>
      <h3 className="text-base font-semibold text-slate-100 mb-4">{exerciseName} Progress</h3>
      <div className="h-72">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
            <XAxis
              dataKey="dateLabel"
              stroke="#94a3b8"
              tick={{ fontSize: 12 }}
            />
            <YAxis
              stroke="#94a3b8"
              tick={{ fontSize: 12 }}
              label={{ value: 'Weight (lbs)', angle: -90, position: 'insideLeft', style: { fill: '#94a3b8', fontSize: 12 } }}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: '#1e293b',
                border: '1px solid #334155',
                borderRadius: '8px',
                color: '#e2e8f0',
              }}
              labelStyle={{ color: '#94a3b8' }}
              formatter={(value) => [`${value} lbs`, 'Max Weight']}
            />
            <Line
              type="monotone"
              dataKey="max_weight"
              stroke="#10b981"
              strokeWidth={2}
              dot={{ fill: '#10b981', r: 4 }}
              activeDot={{ r: 6 }}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </Card>
  );
}
