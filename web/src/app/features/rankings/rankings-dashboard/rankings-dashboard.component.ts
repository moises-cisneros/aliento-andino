import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import {
  LucideUsers,
  LucideStar,
  LucideTrophy,
  LucideTrendingUp,
  LucideMedal,
  LucideCrown,
  LucideChevronRight,
  LucideBarChart3,
} from '@lucide/angular';

import { RankingService } from '../../../core/services/ranking.service';

@Component({
  selector: 'app-rankings-dashboard',
  standalone: true,
  imports: [
    CommonModule, RouterModule,
    LucideUsers, LucideStar, LucideTrophy, LucideTrendingUp,
    LucideMedal, LucideCrown, LucideChevronRight, LucideBarChart3,
  ],
  template: `
    <div class="rankings-dashboard">
      <div class="header">
        <h2>Rankings & Logros</h2>
        <p class="subtitle">Gestión del sistema de XP, niveles y logros</p>
      </div>

      @if (rankingService.rankingStats(); as stats) {
        <div class="stats-grid">
          <div class="card stat-card">
            <svg lucideUsers [size]="28" class="icon-primary"></svg>
            <div class="stat-value">{{ stats.total_users_with_xp }}</div>
            <div class="stat-label">Usuarios con XP</div>
          </div>

          <div class="card stat-card">
            <svg lucideStar [size]="28" class="icon-primary"></svg>
            <div class="stat-value">{{ stats.total_xp_awarded | number }}</div>
            <div class="stat-label">XP total otorgado</div>
          </div>

          <div class="card stat-card">
            <svg lucideTrophy [size]="28" class="icon-primary"></svg>
            <div class="stat-value">{{ stats.total_achievements_unlocked }}</div>
            <div class="stat-label">Logros desbloqueados</div>
          </div>

          <div class="card stat-card">
            <svg lucideTrendingUp [size]="28" class="icon-primary"></svg>
            <div class="stat-value">{{ stats.average_level | number:'1.1-1' }}</div>
            <div class="stat-label">Nivel promedio</div>
          </div>

          <div class="card stat-card">
            <svg lucideMedal [size]="28" class="icon-primary"></svg>
            <div class="stat-value">{{ stats.max_level }}</div>
            <div class="stat-label">Nivel más alto</div>
          </div>

          @if (stats.top_user) {
            <div class="card stat-card highlight">
              <svg lucideCrown [size]="28" class="icon-warning"></svg>
              <div class="stat-value">{{ stats.top_user.username }}</div>
              <div class="stat-label">
                Top usuario — Nivel {{ stats.top_user.level }} ({{ stats.top_user.total_xp | number }} XP)
              </div>
            </div>
          }
        </div>
      } @else {
        <div class="loading">Cargando estadísticas...</div>
      }

      <div class="nav-cards">
        <a class="card nav-card" routerLink="achievements">
          <svg lucideTrophy [size]="28" class="icon-primary"></svg>
          <div>
            <h3>Logros</h3>
            <p>Crear, editar y eliminar logros del sistema</p>
          </div>
          <svg lucideChevronRight [size]="20" class="arrow"></svg>
        </a>

        <a class="card nav-card" routerLink="leaderboard">
          <svg lucideBarChart3 [size]="28" class="icon-primary"></svg>
          <div>
            <h3>Leaderboard</h3>
            <p>Ver rankings globales, semanales y rachas</p>
          </div>
          <svg lucideChevronRight [size]="20" class="arrow"></svg>
        </a>
      </div>
    </div>
  `,
  styles: [`
    .rankings-dashboard { }
    .header { margin-bottom: 24px; }
    h2 { color: var(--color-primary); margin: 0; font-size: 22px; }
    .subtitle { color: var(--text-muted); margin: 4px 0 0 0; }
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      gap: 16px;
      margin-bottom: 32px;
    }
    .stat-card {
      text-align: center;
      display: flex; flex-direction: column; align-items: center; gap: 8px;
    }
    .icon-primary { color: var(--color-primary); }
    .icon-warning { color: var(--color-warning); }
    .stat-value { font-size: 28px; font-weight: bold; color: var(--text-primary); }
    .stat-label { color: var(--text-muted); font-size: 13px; }
    .nav-cards { display: flex; flex-direction: column; gap: 12px; }
    .nav-card {
      display: flex; align-items: center; gap: 16px; cursor: pointer;
      transition: border-color 0.2s;
      border-left: 3px solid transparent;
      text-decoration: none;
    }
    .nav-card:hover { border-left-color: var(--color-primary); }
    .nav-card h3 { color: var(--text-secondary); margin: 0 0 4px 0; }
    .nav-card p { color: var(--text-dimmed); margin: 0; font-size: 13px; }
    .nav-card div { flex: 1; }
    .arrow { color: var(--text-dimmed); }
    .loading { text-align: center; color: var(--text-dimmed); padding: 48px; }
  `],
})
export class RankingsDashboardComponent implements OnInit {
  readonly rankingService = inject(RankingService);

  ngOnInit(): void {
    this.rankingService.loadRankingStats().subscribe();
  }
}
