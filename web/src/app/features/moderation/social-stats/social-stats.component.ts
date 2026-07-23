import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  LucideFileText,
  LucideMessageCircle,
  LucideHeart,
  LucideAlertTriangle,
  LucideBan,
} from '@lucide/angular';

import { ModerationService } from '../../../core/services/moderation.service';

@Component({
  selector: 'app-social-stats',
  standalone: true,
  imports: [
    CommonModule,
    LucideFileText, LucideMessageCircle, LucideHeart, LucideAlertTriangle, LucideBan,
  ],
  template: `
    <div class="social-stats">
      <h2>Estadísticas sociales</h2>

      @if (moderationService.socialStats(); as stats) {
        <div class="stats-grid">
          <div class="card stat-card">
            <svg lucideFileText [size]="28" class="icon-primary"></svg>
            <div class="stat-value">{{ stats.total_posts }}</div>
            <div class="stat-label">Posts totales</div>
          </div>

          <div class="card stat-card">
            <svg lucideMessageCircle [size]="28" class="icon-primary"></svg>
            <div class="stat-value">{{ stats.total_comments }}</div>
            <div class="stat-label">Comentarios</div>
          </div>

          <div class="card stat-card">
            <svg lucideHeart [size]="28" class="icon-primary"></svg>
            <div class="stat-value">{{ stats.total_likes }}</div>
            <div class="stat-label">Likes</div>
          </div>

          <div class="card stat-card warn">
            <svg lucideAlertTriangle [size]="28" class="icon-warning"></svg>
            <div class="stat-value">{{ stats.total_reports_pending }}</div>
            <div class="stat-label">Reportes pendientes</div>
          </div>

          <div class="card stat-card danger">
            <svg lucideBan [size]="28" class="icon-error"></svg>
            <div class="stat-value">{{ stats.total_users_banned }}</div>
            <div class="stat-label">Usuarios baneados</div>
          </div>
        </div>

        @if (stats.most_active_users.length > 0) {
          <h3>Top usuarios activos</h3>
          <div class="table-container">
            <table class="table">
              <thead>
                <tr>
                  <th>Nombre</th>
                  <th>Usuario</th>
                  <th>Posts</th>
                </tr>
              </thead>
              <tbody>
                @for (u of stats.most_active_users; track u.username) {
                  <tr>
                    <td>{{ u.full_name }}</td>
                    <td>&#64;{{ u.username }}</td>
                    <td>{{ u.posts_count }}</td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
        }
      } @else {
        <div class="loading">Cargando estadísticas...</div>
      }
    </div>
  `,
  styles: [`
    .social-stats { }
    h2 { color: var(--color-primary); margin-bottom: 20px; font-size: 22px; }
    h3 { color: var(--text-secondary); margin: 24px 0 12px 0; }
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      gap: 16px;
    }
    .stat-card {
      text-align: center;
      display: flex; flex-direction: column; align-items: center; gap: 8px;
    }
    .icon-primary { color: var(--color-primary); }
    .icon-warning { color: var(--color-warning); }
    .icon-error { color: var(--color-error); }
    .stat-value { font-size: 32px; font-weight: bold; color: var(--text-primary); }
    .stat-label { color: var(--text-muted); font-size: 14px; }
    .loading { text-align: center; color: var(--text-dimmed); padding: 48px; }
  `],
})
export class SocialStatsComponent implements OnInit {
  readonly moderationService = inject(ModerationService);

  ngOnInit(): void {
    this.moderationService.loadSocialStats().subscribe();
  }
}
