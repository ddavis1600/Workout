import DashboardSummary from '../components/dashboard/DashboardSummary';
import TodaysMacros from '../components/dashboard/TodaysMacros';
import RecentWorkouts from '../components/dashboard/RecentWorkouts';

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <DashboardSummary />
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <TodaysMacros />
        <RecentWorkouts />
      </div>
    </div>
  );
}
