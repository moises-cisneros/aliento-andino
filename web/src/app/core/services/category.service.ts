import { Injectable, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap } from 'rxjs';

import { environment } from '../../../environments/environment';
import { Category, CategoryWithCount, CategoryCreate, CategoryUpdate } from '../models/category.model';

/// Servicio para gestión CRUD de categorías (admin).
@Injectable({ providedIn: 'root' })
export class CategoryService {
  private readonly apiUrl = `${environment.apiBaseUrl}/admin/categories`;
  private readonly publicUrl = `${environment.apiBaseUrl}/lessons/categories`;
  private readonly http = inject(HttpClient);

  // Estado reactivo
  readonly categories = signal<CategoryWithCount[]>([]);
  readonly isLoading = signal(false);

  /// Obtener todas las categorías con conteo de lecciones.
  loadCategories(): Observable<CategoryWithCount[]> {
    this.isLoading.set(true);
    return this.http.get<CategoryWithCount[]>(this.publicUrl).pipe(
      tap((cats) => {
        this.categories.set(cats);
        this.isLoading.set(false);
      }),
    );
  }

  /// Crear nueva categoría.
  create(data: CategoryCreate): Observable<Category> {
    return this.http.post<Category>(this.apiUrl, data);
  }

  /// Actualizar categoría existente.
  update(id: string, data: CategoryUpdate): Observable<Category> {
    return this.http.put<Category>(`${this.apiUrl}/${id}`, data);
  }

  /// Eliminar categoría (soft delete).
  delete(id: string): Observable<{ message: string }> {
    return this.http.delete<{ message: string }>(`${this.apiUrl}/${id}`);
  }
}
