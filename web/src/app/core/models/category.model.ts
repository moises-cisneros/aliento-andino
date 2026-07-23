/// Modelo de categoría de lección.
export interface Category {
  id: string;
  name: string;
  description: string | null;
  icon: string | null;
  order: number;
  is_active: boolean;
  created_at: string;
  updated_at: string | null;
}

export interface CategoryWithCount {
  id: string;
  name: string;
  description: string | null;
  icon: string | null;
  order: number;
  is_active: boolean;
  lessons_count: number;
}

export interface CategoryCreate {
  name: string;
  description?: string;
  icon?: string;
  order?: number;
}

export interface CategoryUpdate {
  name?: string;
  description?: string;
  icon?: string;
  order?: number;
  is_active?: boolean;
}
