import { Component, inject, OnInit, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { NgxChartsModule, Color, ScaleType, LegendPosition } from '@swimlane/ngx-charts';
import {
  LucideBookOpen,
  LucideShield,
  LucideTrophy,
  LucideUsers,
  LucideBarChart3,
  LucideActivity,
  LucideAlertTriangle,
  LucideArrowRight,
  LucideMusic,
} from '@lucide/angular';

import { AuthService } from '../../core/services/auth.service';
import {
  AnalyticsService,
  OverviewData,
  DataPoint,
  MultiSeries,
} from '../../core/services/analytics.service';
import { forkJoin } from 'rxjs';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [
    CommonModule,
    RouterModule,
    NgxChartsModule,
    LucideBookOpen,
    LucideShield,
    LucideTrophy,
    LucideUsers,
    LucideBarChart3,
    LucideActivity,
    LucideAlertTriangle,
    LucideArrowRight,
    LucideMusic,
  ],
  template: `
    <div class="dashboard">
      <!-- Header -->
      <header class="dash-header">
        <div>
          <h1>Hola, {{ firstName() }}</h1>
          <p class="date">{{ today }}</p>
        </div>
      </header>

      <!-- KPIs -->
      <section class="kpi-strip">
        <div class="kpi" routerLink="/admin/users">
          <div class="kpi-icon kpi-cyan"><svg lucideUsers [size]="18"></svg></div>
          <div class="kpi-data">
            <span class="kpi-num">{{ overview()?.total_users ?? '–' }}</span>
            <span class="kpi-label">Usuarios</span>
          </div>
        </div>
        <div class="kpi" routerLink="/admin/users">
          <div class="kpi-icon kpi-green"><svg lucideActivity [size]="18"></svg></div>
          <div class="kpi-data">
            <span class="kpi-num">{{ overview()?.active_users ?? '–' }}</span>
            <span class="kpi-label">Activos</span>
          </div>
        </div>
        <div class="kpi" routerLink="/admin/lessons/dashboard">
          <div class="kpi-icon kpi-purple"><svg lucideBookOpen [size]="18"></svg></div>
          <div class="kpi-data">
            <span class="kpi-num">{{ overview()?.total_lessons ?? '–' }}</span>
            <span class="kpi-label">Lecciones</span>
          </div>
        </div>
        <div class="kpi">
          <div class="kpi-icon kpi-blue"><svg lucideMusic [size]="18"></svg></div>
          <div class="kpi-data">
            <span class="kpi-num">{{ overview()?.total_sessions ?? '–' }}</span>
            <span class="kpi-label">Prácticas</span>
          </div>
        </div>
        <div class="kpi" routerLink="/admin/moderation/reports">
          <div class="kpi-icon kpi-amber"><svg lucideAlertTriangle [size]="18"></svg></div>
          <div class="kpi-data">
            <span class="kpi-num">{{ overview()?.pending_reports ?? '–' }}</span>
            <span class="kpi-label">Pendientes</span>
          </div>
        </div>
      </section>

      <!-- Charts row -->
      <section class="charts-section">
        <div class="chart-row">
          <div class="chart-card">
            <h3>Nuevos usuarios <span class="chart-period">últimos 30 días</span></h3>
            <div class="chart-wrapper">
              @if (usersOverTime().length) {
                <ngx-charts-line-chart
                  [results]="usersTimeSeries()"
                  [xAxis]="true"
                  [yAxis]="true"
                  [showXAxisLabel]="false"
                  [showYAxisLabel]="false"
                  [scheme]="colorPrimary"
                  [autoScale]="true"
                  [animations]="true">
                </ngx-charts-line-chart>
              } @else {
                <div class="chart-empty">Sin datos</div>
              }
            </div>
          </div>

          <div class="chart-card">
            <h3>Sesiones de práctica <span class="chart-period">últimos 30 días</span></h3>
            <div class="chart-wrapper">
              @if (practiceOverTime().length) {
                <ngx-charts-bar-vertical
                  [results]="practiceOverTime()"
                  [xAxis]="true"
                  [yAxis]="true"
                  [showXAxisLabel]="false"
                  [showYAxisLabel]="false"
                  [scheme]="colorSuccess"
                  [animations]="true">
                </ngx-charts-bar-vertical>
              } @else {
                <div class="chart-empty">Sin datos</div>
              }
            </div>
          </div>
        </div>

        <div class="chart-row">
          <div class="chart-card">
            <h3>Actividad social <span class="chart-period">últimos 30 días</span></h3>
            <div class="chart-wrapper">
              @if (socialTimeSeries().length) {
                <ngx-charts-line-chart
                  [results]="socialTimeSeries()"
                  [xAxis]="true"
                  [yAxis]="true"
                  [showXAxisLabel]="false"
                  [showYAxisLabel]="false"
                  [scheme]="colorSocial"
                  [autoScale]="true"
                  [legend]="true"
                  [legendPosition]="legendBelow"
                  [animations]="true">
                </ngx-charts-line-chart>
              } @else {
                <div class="chart-empty">Sin datos</div>
              }
            </div>
          </div>

          <div class="chart-card">
            <h3>Lecciones por categoría</h3>
            <div class="chart-wrapper">
              @if (lessonsByCategory().length) {
                <ngx-charts-pie-chart
                  [results]="lessonsByCategory()"
                  [scheme]="colorMulti"
                  [labels]="true"
                  [doughnut]="true"
                  [animations]="true">
                </ngx-charts-pie-chart>
              } @else {
                <div class="chart-empty">Sin datos</div>
              }
            </div>
          </div>
        </div>
      </section>

      <!-- Quick access -->
      <section class="modules">
        <h2>Módulos</h2>
        <div class="mod-grid">
          @for (mod of modules; track mod.route) {
            <a class="mod-card" [routerLink]="mod.route">
              <div class="mod-top">
                <div class="mod-icon" [style.color]="mod.color">
                  @if (mod.id === 'lessons') { <svg lucideBookOpen [size]="22"></svg> }
                  @if (mod.id === 'moderation') { <svg lucideShield [size]="22"></svg> }
                  @if (mod.id === 'rankings') { <svg lucideTrophy [size]="22"></svg> }
                  @if (mod.id === 'users') { <svg lucideUsers [size]="22"></svg> }
                  @if (mod.id === 'reports') { <svg lucideBarChart3 [size]="22"></svg> }
                </div>
                <svg lucideArrowRight [size]="16" class="mod-arrow"></svg>
              </div>
              <h3>{{ mod.name }}</h3>
              <p>{{ mod.desc }}</p>
            </a>
          }
        </div>
      </section>
    </div>
  `,
  styles: [`
    .dashboard {
      max-width: 1100px;
    }

    /* ── Header ── */
    .dash-header h1 {
      font-size: 24px;
      font-weight: 700;
      color: var(--text-primary);
      margin: 0;
      letter-spacing: -0.3px;
    }

    .date {
      color: var(--text-dimmed);
      font-size: 13px;
      margin: 4px 0 0;
    }

    /* ── KPI Strip ── */
    .kpi-strip {
      display: flex;
      gap: 12px;
      margin: 28px 0 36px;
      overflow-x: auto;
      -webkit-overflow-scrolling: touch;
      scrollbar-width: none;
    }
    .kpi-strip::-webkit-scrollbar { display: none; }

    .kpi {
      flex: 1;
      min-width: 140px;
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 16px;
      cursor: pointer;
    }

    .kpi-icon {
      width: 36px;
      height: 36px;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .kpi-cyan  { background: rgba(6,182,212,0.12); color: var(--color-primary); }
    .kpi-green { background: rgba(16,185,129,0.12); color: var(--color-success); }
    .kpi-purple { background: rgba(124,58,237,0.12); color: var(--color-purple); }
    .kpi-blue  { background: rgba(59,130,246,0.12); color: var(--color-blue); }
    .kpi-amber { background: rgba(245,158,11,0.12); color: var(--color-warning); }

    .kpi-data {
      display: flex;
      flex-direction: column;
    }
    .kpi-num {
      font-size: 20px;
      font-weight: 700;
      color: var(--text-primary);
      line-height: 1.2;
    }
    .kpi-label {
      font-size: 11px;
      color: var(--text-dimmed);
      margin-top: 1px;
      text-transform: uppercase;
      letter-spacing: 0.4px;
    }

    /* ── Charts ── */
    .charts-section {
      margin-bottom: 8px;
    }

    .chart-row {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 14px;
      margin-bottom: 14px;
    }

    .chart-card {
      padding: 18px 0;
      min-height: 280px;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }

    .chart-card h3 {
      font-size: 14px;
      font-weight: 600;
      color: var(--text-secondary);
      margin: 0 0 14px;
      flex-shrink: 0;
    }

    .chart-period {
      font-weight: 400;
      color: var(--text-dimmed);
      font-size: 12px;
      margin-left: 4px;
    }

    .chart-wrapper {
      flex: 1;
      position: relative;
      min-height: 0;
      width: 100%;
    }

    .chart-wrapper ngx-charts-line-chart,
    .chart-wrapper ngx-charts-bar-vertical,
    .chart-wrapper ngx-charts-pie-chart {
      position: absolute;
      inset: 0;
    }

    .chart-empty {
      position: absolute;
      inset: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--text-dimmed);
      font-size: 13px;
    }

    :host ::ng-deep {
      .ngx-charts text {
        fill: var(--text-tertiary) !important;
        font-size: 11px !important;
      }
      .ngx-charts .gridline-path { stroke: var(--bg-border) !important; }
      .ngx-charts .line { stroke-width: 2.5; }
      .ngx-charts .tick text { fill: var(--text-muted) !important; font-size: 11px !important; }
      .ngx-charts .legend-labels { background: transparent !important; }
      .ngx-charts .legend-label { color: var(--text-secondary) !important; }
      .ngx-charts .legend-label-text { color: var(--text-secondary) !important; fill: var(--text-secondary) !important; font-size: 12px !important; }
      .ngx-charts .legend-wrap { padding: 0 !important; }
      .ngx-charts .advanced-pie-legend .legend-item .item-color { font-size: 12px !important; }
      .ngx-charts .label { fill: var(--text-secondary) !important; }
      .chart-tooltip {
        background: var(--bg-elevated) !important;
        border: 1px solid var(--bg-border) !important;
        color: var(--text-secondary) !important;
        border-radius: 8px !important;
        font-size: 12px !important;
      }
      .tooltip-val { font-weight: 600; color: var(--text-primary) !important; }
    }

    /* ── Modules ── */
    .modules {
      margin-top: 36px;
    }

    .modules h2 {
      font-size: 15px;
      font-weight: 600;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.6px;
      margin: 0 0 14px;
    }

    .mod-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      gap: 12px;
    }

    .mod-card {
      padding: 20px;
      cursor: pointer;
      text-decoration: none;
      display: flex;
      flex-direction: column;
      border-radius: 10px;
      transition: background 0.15s;
    }
    .mod-card:hover { background: var(--bg-hover); }
    .mod-card:hover .mod-arrow { opacity: 1; }

    .mod-top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 14px;
    }

    .mod-icon {
      width: 40px;
      height: 40px;
      border-radius: 10px;
      background: var(--bg-hover);
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .mod-arrow {
      color: var(--text-dimmed);
      opacity: 0;
      transition: opacity 0.15s;
    }

    .mod-card h3 {
      font-size: 15px;
      font-weight: 600;
      color: var(--text-primary);
      margin: 0 0 4px;
    }

    .mod-card p {
      font-size: 13px;
      color: var(--text-dimmed);
      margin: 0;
      line-height: 1.4;
    }

    /* ── Responsive ── */
    @media (max-width: 1024px) {
      .chart-row { grid-template-columns: 1fr; }
    }

    @media (max-width: 768px) {
      .kpi-strip { gap: 8px; }
      .kpi { min-width: 120px; padding: 12px; }
      .kpi-num { font-size: 17px; }
      .chart-card { min-height: 240px; padding: 14px; }
      .mod-grid { grid-template-columns: repeat(2, 1fr); gap: 10px; }
      .mod-card { padding: 16px; }
    }

    @media (max-width: 480px) {
      .dash-header h1 { font-size: 20px; }
      .kpi-strip { margin: 20px 0 28px; }
      .kpi { min-width: 110px; padding: 10px; gap: 8px; }
      .kpi-icon { width: 30px; height: 30px; }
      .kpi-num { font-size: 15px; }
      .kpi-label { font-size: 10px; }
      .chart-card { min-height: 200px; padding: 12px; }
      .chart-card h3 { font-size: 13px; }
      .mod-grid { grid-template-columns: 1fr; }
      .modules h2 { font-size: 13px; }
    }
  `],
})
export class DashboardComponent implements OnInit {
  private authService = inject(AuthService);
  private analytics = inject(AnalyticsService);

  readonly overview = signal<OverviewData | null>(null);
  readonly usersOverTime = signal<DataPoint[]>([]);
  readonly practiceOverTime = signal<DataPoint[]>([]);
  readonly socialTimeSeries = signal<MultiSeries[]>([]);
  readonly lessonsByCategory = signal<DataPoint[]>([]);

  readonly usersTimeSeries = computed<MultiSeries[]>(() => [
    { name: 'Usuarios', series: this.usersOverTime() },
  ]);

  readonly legendBelow = LegendPosition.Below;

  readonly colorPrimary: Color = { name: 'primary', selectable: true, group: ScaleType.Ordinal, domain: ['#06b6d4'] };
  readonly colorSuccess: Color = { name: 'success', selectable: true, group: ScaleType.Ordinal, domain: ['#10b981'] };
  readonly colorSocial: Color = { name: 'social', selectable: true, group: ScaleType.Ordinal, domain: ['#3b82f6', '#7c3aed', '#ef4444'] };
  readonly colorMulti: Color = { name: 'multi', selectable: true, group: ScaleType.Ordinal, domain: ['#06b6d4', '#10b981', '#f59e0b', '#7c3aed', '#3b82f6', '#ef4444', '#ec4899'] };

  readonly firstName = () => {
    const name = this.authService.currentUser()?.full_name ?? '';
    return name.split(' ')[0] || 'Admin';
  };

  readonly today = new Date().toLocaleDateString('es-ES', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });

  readonly modules = [
    { id: 'lessons', name: 'Lecciones', desc: 'Gestionar lecciones y categorías', route: '/admin/lessons/dashboard', color: 'var(--color-primary)' },
    { id: 'moderation', name: 'Moderación', desc: 'Reportes, posts y bans', route: '/admin/moderation/reports', color: 'var(--color-warning)' },
    { id: 'rankings', name: 'Rankings', desc: 'XP, logros y leaderboards', route: '/admin/rankings/dashboard', color: 'var(--color-success)' },
    { id: 'users', name: 'Usuarios', desc: 'Gestión de cuentas', route: '/admin/users', color: 'var(--color-primary)' },
    { id: 'reports', name: 'Reportes', desc: 'Analíticas y métricas', route: '/admin/reports', color: 'var(--color-purple)' },
  ];

  ngOnInit(): void {
    forkJoin({
      overview: this.analytics.getOverview(),
      users: this.analytics.getUsersOverTime(30),
      practice: this.analytics.getPracticeOverTime(30),
      social: this.analytics.getSocialOverTime(30),
      categories: this.analytics.getLessonsByCategory(),
    }).subscribe({
      next: ({ overview, users, practice, social, categories }) => {
        this.overview.set(overview);
        this.usersOverTime.set(users);
        this.practiceOverTime.set(practice);
        this.socialTimeSeries.set([
          { name: 'Posts', series: social.posts },
          { name: 'Comentarios', series: social.comments },
          { name: 'Likes', series: social.likes },
        ]);
        this.lessonsByCategory.set(categories);
      },
    });
  }
}
