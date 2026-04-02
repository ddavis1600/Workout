import Input from '../ui/Input';
import Select from '../ui/Select';
import { ACTIVITY_LEVELS } from '../../utils/constants';
import type { UserProfile } from '../../types';

interface BodyStatsFormProps {
  profile: Partial<UserProfile>;
  onChange: (updated: Partial<UserProfile>) => void;
}

export default function BodyStatsForm({ profile, onChange }: BodyStatsFormProps) {
  const isImperial = profile.unit_system !== 'metric';

  function handleChange(field: keyof UserProfile, value: string | number) {
    onChange({ ...profile, [field]: value });
  }

  function toggleUnit() {
    const newSystem = isImperial ? 'metric' : 'imperial';
    onChange({ ...profile, unit_system: newSystem });
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between mb-2">
        <h3 className="text-base font-semibold text-slate-100">Body Stats</h3>
        <button
          type="button"
          onClick={toggleUnit}
          className="text-sm text-emerald-400 hover:text-emerald-300 cursor-pointer"
        >
          Switch to {isImperial ? 'Metric' : 'Imperial'}
        </button>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Input
          label={`Weight (${isImperial ? 'lbs' : 'kg'})`}
          type="number"
          value={profile.weight || ''}
          onChange={(e) => handleChange('weight', Number(e.target.value))}
          placeholder={isImperial ? '180' : '82'}
        />
        <Input
          label={`Height (${isImperial ? 'inches' : 'cm'})`}
          type="number"
          value={profile.height || ''}
          onChange={(e) => handleChange('height', Number(e.target.value))}
          placeholder={isImperial ? '70' : '178'}
        />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Input
          label="Age"
          type="number"
          value={profile.age || ''}
          onChange={(e) => handleChange('age', Number(e.target.value))}
          placeholder="25"
        />
        <Select
          label="Gender"
          value={profile.gender || ''}
          onChange={(e) => handleChange('gender', e.target.value)}
          options={[
            { value: 'male', label: 'Male' },
            { value: 'female', label: 'Female' },
          ]}
        />
      </div>

      <Select
        label="Activity Level"
        value={profile.activity_level || ''}
        onChange={(e) => handleChange('activity_level', e.target.value)}
        options={ACTIVITY_LEVELS.map((a) => ({ value: a.value, label: a.label }))}
      />
    </div>
  );
}
