import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import {
  LucideMusic,
  LucideFolderOpen,
  LucideActivity,
  LucideUsers,
  LucideStar,
  LucideTrendingUp,
  LucideListMusic,
  LucidePlusCircle,
  LucideShield,
} from '@lucide/angular';

import { AuthService } from '../../../core/services/auth.service';
import { LessonService } from '../../../core/services/lesson.service';
import { AdminStatsOverview } from '../../../core/models/lesson.model';

@Component({
  selector: 'app-lessons-dashboard',
  standalone: true,
  imports: [
    CommonModule,
    LucideMusic, LucideFolderOpen, LucideActivity, LucideUsers,
    LucideStar, LucideTrendingUp, LucideListMusic, LucidePlusCircle, LucideShield,
  ],
  template: `
    <h2 class="section-title">Lecciones — Resumen</h2>

    @if (stats()) {
      <div class="stats-grid">
        <div class="stat-card">
          <svg lucideMusic [size]="28" class="icon-primary"></svg>
          <div class="stat-value">{{ stats()!.total_lessons }}</div>
          <div class="stat-label">Lecciones</div>
        </div>
        <div class="stat-card">
          <svg lucideFolderOpen [size]="28" class="icon-purple"></svg>
          <div class="stat-value">{{ stats()!.total_categories }}</div>
          <div class="stat-label">Categorías</div>
        </div>
        <div class="stat-card">
          <svg lucideActivity [size]="28" class="icon-success"></svg>
          <div class="stat-value">{{ stats()!.total_practice_sessions }}</div>
          <div class="stat-label">Sesiones</div>
        </div>
        <div class="stat-card">
          <svg lucideUsers [size]="28" class="icon-warning"></svg>
          <div class="stat-value">{{ stats()!.total_users_active }}</div>
          <div class="stat-label">Usuarios Activos</div>
        </div>
        <div class="stat-card">
          <svg lucideStar [size]="28" class="icon-primary"></svg>
          <div class="stat-value stat-text">{{ stats()!.highest_rated_lesson || 'N/A' }}</div>
          <div class="stat-label">Mejor Calificada</div>
        </div>
        <div class="stat-card">
          <svg lucideTrendingUp [size]="28" class="icon-success"></svg>
          <div class="stat-value stat-text">{{ stats()!.most_played_lesson || 'N/A' }}</div>
          <div class="stat-label">Más Jugada</div>
        </div>
      </div>
    }

    <h3 class="section-subtitle">Accesos Rápidos</h3>
    <div class="quick-actions">
      <div class="action-card" (click)="navigateTo('/admin/lessons/categories')">
        <svg lucideFolderOpen [size]="22" class="icon-primary"></svg>
        <span>Gestionar Categorías</span>
      </div>
      <div class="action-card" (click)="navigateTo('/admin/lessons/list')">
        <svg lucideListMusic [size]="22" class="icon-primary"></svg>
        <span>Gestionar Lecciones</span>
      </div>
      <div class="action-card" (click)="navigateTo('/admin/lessons/new')">
        <svg lucidePlusCircle [size]="22" class="icon-primary"></svg>
        <span>Nueva Lección</span>
      </div>
      <div class="action-card" (click)="navigateTo('/admin/moderation')">
        <svg lucideShield [size]="22" class="icon-primary"></svg>
        <span>Moderación Social</span>
      </div>
    </div>
  `,
  styles: [`
    .section-title { color: var(--color-primary); margin-bottom: 24px; font-size: 22px; }
    .section-subtitle { color: var(--text-secondary); margin: 32px 0 16px; font-size: 18px; }

    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
      gap: 16px;
    }
    .stat-card {
      color: var(--text-secondary);
      padding: 20px;
      text-align: center;
    }
    .stat-value { font-size: 28px; font-weight: 700; color: var(--text-secondary); margin-top: 8px; }
    .stat-value.stat-text { font-size: 16px; font-weight: 600; }
    .stat-label { font-size: 13px; color: var(--text-muted); margin-top: 4px; }

    .quick-actions {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 16px;
    }
    .action-card {
      color: var(--text-secondary);
      padding: 24px;
      display: flex;
      align-items: center;
      gap: 12px;
      cursor: pointer;
      border-radius: 10px;
      transition: background 0.15s;
    }
    .action-card:hover { background: var(--bg-hover); }
  `],
})
export class LessonsDashboardComponent implements OnInit {
  readonly authService = inject(AuthService);
  private readonly lessonService = inject(LessonService);
  private readonly router = inject(Router);

  readonly stats = signal<AdminStatsOverview | null>(null);

  ngOnInit(): void {
    this.lessonService.loadStats().subscribe({
      next: (s) => this.stats.set(s),
    });
  }

  navigateTo(path: string): void {
    this.router.navigate([path]);
  }
}
