// Kiểu dữ liệu theo docs/05 §13 và docs/31 §3.

export interface Page<T> {
  items: T[];
  page: number;
  size: number;
  totalItems: number;
  totalPages: number;
  hasNext: boolean;
}

export interface Option {
  code: string;
  name: string;
}

export type DataQuality = 'SOURCED' | 'ESTIMATED' | 'DEMO';

export const DATA_QUALITY_LABELS: Record<DataQuality, string> = {
  SOURCED: 'Có nguồn',
  ESTIMATED: 'Ước tính',
  DEMO: 'Minh họa',
};

export interface AdminFoodItem {
  id: string;
  code: string;
  name: string;
  category: Option;
  servingDescription: string;
  kcalPerServing: number;
  dataQuality: DataQuality;
  active: boolean;
  revision: number;
}

export interface AdminFoodDetail {
  id: string;
  code: string;
  name: string;
  nameEn: string | null;
  category: Option;
  region: Option | null;
  servingDescription: string;
  servingSize: number | null;
  servingUnit: string | null;
  kcalPerServing: number;
  proteinPerServing: number;
  carbsPerServing: number;
  fatPerServing: number;
  dataQuality: DataQuality;
  source: string;
  sourceUrl: string | null;
  imageUrl: string | null;
  reviewNote: string | null;
  active: boolean;
  revision: number;
}

export interface FoodOptions {
  categories: Option[];
  regions: Option[];
  dataQualities: DataQuality[];
  servingUnits: string[];
}

export interface FoodRequest {
  name: string;
  nameEn: string | null;
  categoryCode: string;
  region: string | null;
  servingDescription: string;
  servingSize: number | null;
  servingUnit: string | null;
  kcalPerServing: number | null;
  proteinPerServing: number | null;
  carbsPerServing: number | null;
  fatPerServing: number | null;
  dataQuality: DataQuality;
  source: string;
  sourceUrl: string | null;
  imageUrl: string | null;
  reviewNote: string | null;
  active: boolean;
  revision?: number;
}

export type MuscleGroup =
  | 'CHEST' | 'BACK' | 'SHOULDERS' | 'ARMS' | 'LEGS' | 'GLUTES' | 'CORE' | 'FULL_BODY' | 'CARDIO';
export type Equipment = 'NONE' | 'DUMBBELL' | 'BARBELL' | 'MACHINE' | 'CABLE' | 'BAND' | 'OTHER';
export type Difficulty = 'BEGINNER' | 'INTERMEDIATE' | 'ADVANCED';
export type MediaType = 'IMAGE' | 'GIF' | 'VIDEO';

export interface ExerciseFilters {
  muscleGroups: Option[];
  equipment: Option[];
  difficulties: Option[];
}

export interface AdminExerciseItem {
  id: string;
  code: string;
  name: string;
  muscleGroup: MuscleGroup;
  equipment: Equipment;
  difficulty: Difficulty;
  thumbnailPreviewUrl: string | null;
  active: boolean;
  revision: number;
}

export interface AdminExerciseDetail {
  id: string;
  code: string;
  name: string;
  muscleGroup: MuscleGroup;
  equipment: Equipment;
  difficulty: Difficulty;
  instructions: string;
  commonMistakes: string;
  thumbnailUrl: string | null;
  thumbnailPreviewUrl: string | null;
  mediaType: MediaType | null;
  mediaUrl: string | null;
  mediaPreviewUrl: string | null;
  contentSource: string | null;
  mediaLicense: string | null;
  active: boolean;
  revision: number;
}

export interface ExerciseRequest {
  name: string;
  muscleGroup: MuscleGroup | '';
  equipment: Equipment | '';
  difficulty: Difficulty | '';
  instructions: string;
  commonMistakes: string;
  thumbnailUrl: string | null;
  mediaType: MediaType | null;
  mediaUrl: string | null;
  contentSource: string | null;
  mediaLicense: string | null;
  active: boolean;
  revision?: number;
}

export type UserStatus = 'ACTIVE' | 'LOCKED';

export interface AdminUserItem {
  id: string;
  email: string;
  fullName: string;
  role: 'USER' | 'ADMIN';
  status: UserStatus;
  createdAt: string;
}
