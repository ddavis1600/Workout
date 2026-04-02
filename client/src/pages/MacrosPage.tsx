import { useState, useEffect } from 'react';
import BodyStatsForm from '../components/macros/BodyStatsForm';
import GoalSelector from '../components/macros/GoalSelector';
import TDEEResult from '../components/macros/TDEEResult';
import MacroTargetsDisplay from '../components/macros/MacroTargetsDisplay';
import Card from '../components/ui/Card';
import Button from '../components/ui/Button';
import { useProfile, useUpdateProfile } from '../hooks/useMacros';
import { calculateAll } from '../utils/macroCalculator';
import type { UserProfile } from '../types';
import { Save } from 'lucide-react';

export default function MacrosPage() {
  const { data: serverProfile, isLoading } = useProfile();
  const updateProfile = useUpdateProfile();
  const [profile, setProfile] = useState<Partial<UserProfile>>({
    weight: 0,
    height: 0,
    age: 0,
    gender: 'male',
    activity_level: 'moderate',
    goal: 'maintain',
    unit_system: 'imperial',
  });
  const [results, setResults] = useState({
    tdee: 0,
    calorie_target: 0,
    protein_target: 0,
    carb_target: 0,
    fat_target: 0,
  });

  useEffect(() => {
    if (serverProfile) {
      setProfile(serverProfile);
      setResults({
        tdee: serverProfile.tdee || 0,
        calorie_target: serverProfile.calorie_target || 0,
        protein_target: serverProfile.protein_target || 0,
        carb_target: serverProfile.carb_target || 0,
        fat_target: serverProfile.fat_target || 0,
      });
    }
  }, [serverProfile]);

  useEffect(() => {
    if (profile.weight && profile.height && profile.age && profile.gender && profile.activity_level && profile.goal) {
      const calc = calculateAll(
        profile.weight,
        profile.height,
        profile.age,
        profile.gender,
        profile.activity_level,
        profile.goal,
        profile.unit_system || 'imperial'
      );
      setResults(calc);
    }
  }, [profile]);

  function handleSave() {
    updateProfile.mutate({
      ...profile,
      tdee: results.tdee,
      calorie_target: results.calorie_target,
      protein_target: results.protein_target,
      carb_target: results.carb_target,
      fat_target: results.fat_target,
    });
  }

  if (isLoading) {
    return <div className="text-slate-400 text-center py-12">Loading profile...</div>;
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-slate-100">Macro Calculator</h1>

      <Card>
        <BodyStatsForm profile={profile} onChange={setProfile} />
      </Card>

      <GoalSelector
        selected={profile.goal || 'maintain'}
        onSelect={(goal) => setProfile((p) => ({ ...p, goal }))}
      />

      <TDEEResult
        tdee={results.tdee}
        adjustedCalories={results.calorie_target}
        goal={profile.goal || 'maintain'}
      />

      <MacroTargetsDisplay
        protein={results.protein_target}
        carbs={results.carb_target}
        fat={results.fat_target}
      />

      <div className="flex justify-end">
        <Button onClick={handleSave} disabled={updateProfile.isPending || !results.tdee}>
          <span className="flex items-center gap-2">
            <Save size={16} />
            {updateProfile.isPending ? 'Saving...' : 'Save Profile'}
          </span>
        </Button>
      </div>
    </div>
  );
}
