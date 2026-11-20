import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NgxChartsModule, Color, ScaleType, LegendPosition } from '@swimlane/ngx-charts';
import {
  LucideUsers,
  LucideBookOpen,
  LucideActivity,
  LucideMessageSquare,
  LucideHeart,
  LucideShield,
  LucideAlertTriangle,
  LucideMusic,
  LucideTrendingUp,
} from '@lucide/angular';
import {
  AnalyticsService,
  DataPoint,
  MultiSeries,
  OverviewData,
} from '../../../core/services/analytics.service';
import {
  AnalyticsAdminService,
  InstrumentMetrics,
} from '../../../core/services/analytics-admin.service';
import { catchError, forkJoin, of } from 'rxjs';

@Component({
  selector: 'app-reports-dashboard',
  standalone: true,
  imports: [
    CommonModule,
    NgxChartsModule,
    LucideUsers,
    LucideBookOpen,
    LucideActivity,
    LucideMessageSquare,
    LucideHeart,
    LucideShield,
    LucideAlertTriangle,
    LucideMusic,
    LucideTrendingUp,
  ],
  template: `
    <div class="reports-page">
      <h2>Reportes y Analíticas</h2>
      <p class="subtitle">Métricas generales del sistema.</p>

      @if (loading()) {
        <div class="loading">Cargando datos...</div>
      } @else {
        <!-- KPI Cards -->
        <div class="kpi-grid">
          <div class="kpi-card">
            <div class="kpi-icon"><svg lucideUsers [size]="22" class="icon-primary"></svg></div>
            <div class="kpi-info">
              <span class="kpi-value">{{ overview()?.total_users ?? 0 }}</span>
              <span class="kpi-label">Usuarios totales</span>
            </div>
          </div>
          <div class="kpi-card">
            <div class="kpi-icon"><svg lucideActivity [size]="22" class="icon-success"></svg></div>
            <div class="kpi-info">
              <span class="kpi-value">{{ overview()?.active_users ?? 0 }}</span>
              <span class="kpi-label">Activos</span>
            </div>
          </div>
          <div class="kpi-card">
            <div class="kpi-icon"><svg lucideBookOpen [size]="22" class="icon-primary"></svg></div>
            <div class="kpi-info">
              <span class="kpi-value">{{ overview()?.total_lessons ?? 0 }}</span>
              <span class="kpi-label">Lecciones</span>
            </div>
          </div>
          <div class="kpi-card">
            <div class="kpi-icon"><svg lucideMusic [size]="22" class="icon-purple"></svg></div>
            <div class="kpi-info">
              <span class="kpi-value">{{ overview()?.total_sessions ?? 0 }}</span>
              <span class="kpi-label">Sesiones de práctica</span>
            </div>
          </div>
          <div class="kpi-card">
            <div class="kpi-icon">
              <svg lucideMessageSquare [size]="22" class="icon-info"></svg>
            </div>
            <div class="kpi-info">
              <span class="kpi-value">{{ overview()?.total_posts ?? 0 }}</span>
              <span class="kpi-label">Posts</span>
            </div>
          </div>
          <div class="kpi-card">
            <div class="kpi-icon"><svg lucideHeart [size]="22" class="icon-error"></svg></div>
            <div class="kpi-info">
              <span class="kpi-value">{{ overview()?.total_likes ?? 0 }}</span>
              <span class="kpi-label">Likes</span>
            </div>
          </div>
          <div class="kpi-card">
            <div class="kpi-icon"><svg lucideShield [size]="22" class="icon-warning"></svg></div>
            <div class="kpi-info">
              <span class="kpi-value">{{ overview()?.pending_reports ?? 0 }}</span>
              <span class="kpi-label">Reportes pendientes</span>
            </div>
          </div>
          <div class="kpi-card">
            <div class="kpi-icon">
              <svg lucideAlertTriangle [size]="22" class="icon-error"></svg>
            </div>
            <div class="kpi-info">
              <span class="kpi-value">{{ overview()?.banned_users ?? 0 }}</span>
              <span class="kpi-label">Baneados</span>
            </div>
          </div>
        </div>

        <!-- Period selector -->
        <div class="period-selector">
          <span class="period-label">Período:</span>
          <div class="tabs">
            @for (p of periods; track p.value) {
              <button
                class="tab"
                [class.active]="selectedDays() === p.value"
                (click)="changePeriod(p.value)"
              >
                {{ p.label }}
              </button>
            }
          </div>
        </div>

        <!-- Row 1: User registrations + Practice sessions -->
        <div class="chart-row">
          <div class="chart-card">
            <h3>Usuarios registrados</h3>
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
                  [animations]="true"
                >
                </ngx-charts-line-chart>
              } @else {
                <div class="chart-empty">Sin datos para este período</div>
              }
            </div>
          </div>

          <div class="chart-card">
            <h3>Sesiones de práctica</h3>
            <div class="chart-wrapper">
              @if (practiceOverTime().length) {
                <ngx-charts-line-chart
                  [results]="practiceTimeSeries()"
                  [xAxis]="true"
                  [yAxis]="true"
                  [showXAxisLabel]="false"
                  [showYAxisLabel]="false"
                  [scheme]="colorSuccess"
                  [autoScale]="true"
                  [animations]="true"
                >
                </ngx-charts-line-chart>
              } @else {
                <div class="chart-empty">Sin datos para este período</div>
              }
            </div>
          </div>
        </div>

        <!-- Row 2: Social activity (multi-line) + Reports over time -->
        <div class="chart-row">
          <div class="chart-card">
            <h3>Actividad social</h3>
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
                  [animations]="true"
                >
                </ngx-charts-line-chart>
              } @else {
                <div class="chart-empty">Sin datos para este período</div>
              }
            </div>
          </div>

          <div class="chart-card">
            <h3>Reportes en el tiempo</h3>
            <div class="chart-wrapper">
              @if (reportsOverTime().length) {
                <ngx-charts-bar-vertical
                  [results]="reportsOverTime()"
                  [xAxis]="true"
                  [yAxis]="true"
                  [showXAxisLabel]="false"
                  [showYAxisLabel]="false"
                  [scheme]="colorWarning"
                  [animations]="true"
                >
                </ngx-charts-bar-vertical>
              } @else {
                <div class="chart-empty">Sin datos para este período</div>
              }
            </div>
          </div>
        </div>

        <!-- Row 3: Pie charts -->
        <div class="chart-row chart-row-thirds">
          <div class="chart-card">
            <h3>Lecciones por categoría</h3>
            <div class="chart-wrapper">
              @if (lessonsByCategory().length) {
                <ngx-charts-pie-chart
                  [results]="lessonsByCategory()"
                  [scheme]="colorMulti"
                  [labels]="true"
                  [doughnut]="true"
                  [animations]="true"
                >
                </ngx-charts-pie-chart>
              } @else {
                <div class="chart-empty">Sin datos</div>
              }
            </div>
          </div>

          <div class="chart-card">
            <h3>Lecciones por dificultad</h3>
            <div class="chart-wrapper">
              @if (lessonsByDifficulty().length) {
                <ngx-charts-pie-chart
                  [results]="lessonsByDifficulty()"
                  [scheme]="colorDifficulty"
                  [labels]="true"
                  [doughnut]="true"
                  [animations]="true"
                >
                </ngx-charts-pie-chart>
              } @else {
                <div class="chart-empty">Sin datos</div>
              }
            </div>
          </div>

          <div class="chart-card">
            <h3>Reportes por estado</h3>
            <div class="chart-wrapper">
              @if (reportsByStatus().length) {
                <ngx-charts-pie-chart
                  [results]="reportsByStatus()"
                  [scheme]="colorReportStatus"
                  [labels]="true"
                  [doughnut]="true"
                  [animations]="true"
                >
                </ngx-charts-pie-chart>
              } @else {
                <div class="chart-empty">Sin datos</div>
              }
            </div>
          </div>
        </div>

        <!-- Métricas pedagógicas por instrumento andino -->
        <div class="chart-row">
          <div class="chart-card chart-full">
            <h3>
              <svg lucideMusic [size]="18" class="icon-primary"></svg>
              Métricas por instrumento andino
            </h3>
            @if (instrumentMetrics().length) {
              <table class="instrument-table">
                <thead>
                  <tr>
                    <th>Instrumento</th>
                    <th>Sesiones</th>
                    <th>Puntaje prom.</th>
                    <th>Precisión de notas</th>
                    <th>Precisión de tempo</th>
                    <th>Completitud</th>
                  </tr>
                </thead>
                <tbody>
                  @for (m of instrumentMetrics(); track m.instrument) {
                    <tr>
                      <td>{{ m.instrument | titlecase }}</td>
                      <td>{{ m.sessions }}</td>
                      <td>{{ m.avg_score | number: '1.0-1' }}</td>
                      <td>{{ m.avg_note_precision | number: '1.0-1' }}</td>
                      <td>{{ m.avg_tempo_accuracy | number: '1.0-1' }}</td>
                      <td>{{ m.completion_rate | number: '1.0-1' }}</td>
                    </tr>
                  }
                </tbody>
              </table>
            } @else {
              <div class="chart-empty">Sin datos de práctica por instrumento</div>
            }
          </div>
        </div>

        <!-- Row 4: Top lessons bar chart -->
        <div class="chart-row">
          <div class="chart-card chart-full">
            <h3>
              <svg lucideTrendingUp [size]="18" class="icon-primary"></svg>
              Lecciones más practicadas
            </h3>
            <div class="chart-wrapper">
              @if (topLessons().length) {
                <ngx-charts-bar-horizontal
                  [results]="topLessons()"
                  [xAxis]="true"
                  [yAxis]="true"
                  [showXAxisLabel]="false"
                  [showYAxisLabel]="false"
                  [scheme]="colorPrimary"
                  [animations]="true"
                >
                </ngx-charts-bar-horizontal>
              } @else {
                <div class="chart-empty">Sin datos</div>
              }
            </div>
          </div>
        </div>
      }
    </div>
  `,
  styles: [
    `
      .reports-page {
        color: var(--text-secondary);
      }

      h2 {
        color: var(--text-primary);
        font-size: 22px;
        margin-bottom: 4px;
      }

      .subtitle {
        color: var(--text-dimmed);
        font-size: 14px;
        margin-bottom: 24px;
      }

      .loading {
        text-align: center;
        color: var(--text-muted);
        padding: 60px 0;
        font-size: 14px;
      }

      /* ─── KPI Grid ─── */
      .kpi-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
        gap: 12px;
        margin-bottom: 28px;
      }

      .kpi-card {
        padding: 18px;
        display: flex;
        align-items: center;
        gap: 14px;
      }

      .kpi-icon {
        width: 42px;
        height: 42px;
        border-radius: 10px;
        background: var(--bg-hover);
        display: flex;
        align-items: center;
        justify-content: center;
        flex-shrink: 0;
      }

      .kpi-info {
        display: flex;
        flex-direction: column;
      }

      .kpi-value {
        font-size: 22px;
        font-weight: 700;
        color: var(--text-primary);
        line-height: 1.2;
      }

      .kpi-label {
        font-size: 12px;
        color: var(--text-dimmed);
        margin-top: 2px;
      }

      /* ─── Period selector ─── */
      .period-selector {
        display: flex;
        align-items: center;
        gap: 12px;
        margin-bottom: 20px;
      }

      .period-label {
        font-size: 13px;
        color: var(--text-muted);
      }

      /* ─── Charts layout ─── */
      .chart-row {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 16px;
        margin-bottom: 16px;
      }

      .chart-row-thirds {
        grid-template-columns: 1fr 1fr 1fr;
      }

      .instrument-table {
        width: 100%;
        border-collapse: collapse;
        font-size: 13px;
      }
      .instrument-table th,
      .instrument-table td {
        padding: 8px 12px;
        text-align: left;
        border-bottom: 1px solid var(--bg-border);
      }
      .instrument-table th {
        color: var(--text-muted);
        font-weight: 500;
      }
      .chart-card {
        padding: 20px 0;
        min-height: 320px;
        display: flex;
        flex-direction: column;
        overflow: hidden;
      }

      .chart-card h3 {
        font-size: 14px;
        font-weight: 600;
        color: var(--text-secondary);
        margin-bottom: 16px;
        display: flex;
        align-items: center;
        gap: 8px;
        flex-shrink: 0;
      }

      .chart-full {
        grid-column: 1 / -1;
      }

      /* Wrapper que permite a ngx-charts auto-dimensionarse */
      .chart-wrapper {
        flex: 1;
        position: relative;
        min-height: 0;
        width: 100%;
      }

      .chart-wrapper ngx-charts-line-chart,
      .chart-wrapper ngx-charts-bar-vertical,
      .chart-wrapper ngx-charts-bar-horizontal,
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

      /* ─── ngx-charts theme override ─── */
      :host ::ng-deep {
        .ngx-charts {
          text {
            fill: var(--text-tertiary) !important;
            font-size: 11px !important;
          }

          .tick text {
            fill: var(--text-muted) !important;
            font-size: 11px !important;
          }

          .gridline-path {
            stroke: var(--bg-border) !important;
          }

          .refline-path {
            stroke: var(--bg-border) !important;
          }

          .line {
            stroke-width: 2.5;
          }

          .area {
            opacity: 0.15;
          }

          .label {
            fill: var(--text-secondary) !important;
          }

          .legend-labels {
            background: transparent !important;
          }

          .legend-label {
            color: var(--text-secondary) !important;
          }

          .legend-label-text {
            color: var(--text-secondary) !important;
            fill: var(--text-secondary) !important;
            font-size: 12px !important;
          }

          .legend-wrap {
            padding: 0 !important;
          }

          .chart-legend .legend-label:hover {
            color: var(--text-primary) !important;
          }

          .tooltip-anchor {
            fill: var(--bg-body);
            stroke: var(--bg-border);
          }

          .ngx-charts-outer {
            overflow: visible;
          }
        }

        .chart-tooltip {
          background: var(--bg-elevated) !important;
          border: 1px solid var(--bg-border) !important;
          color: var(--text-secondary) !important;
          border-radius: 8px !important;
          padding: 8px 12px !important;
          font-size: 12px !important;
          box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3) !important;
        }

        .tooltip-val {
          font-weight: 600;
          color: var(--text-primary) !important;
        }
      }

      /* ─── Utility icon classes ─── */
      .icon-purple {
        color: var(--color-purple);
      }
      .icon-info {
        color: var(--color-blue);
      }

      /* ─── Tablet landscape ─── */
      @media (max-width: 1200px) {
        .chart-row-thirds {
          grid-template-columns: 1fr 1fr;
        }
      }

      /* ─── Tablet portrait ─── */
      @media (max-width: 1024px) {
        .chart-row {
          grid-template-columns: 1fr;
        }
        .chart-row-thirds {
          grid-template-columns: 1fr;
        }
        .chart-card {
          min-height: 280px;
        }
      }

      /* ─── Mobile large ─── */
      @media (max-width: 768px) {
        .kpi-grid {
          grid-template-columns: repeat(2, 1fr);
        }
        .kpi-card {
          gap: 10px;
        }
        .kpi-icon {
          width: 36px;
          height: 36px;
        }
        .kpi-value {
          font-size: 18px;
        }
        .kpi-label {
          font-size: 11px;
        }
        .chart-card {
          min-height: 250px;
        }
        .period-selector {
          flex-wrap: wrap;
        }
      }

      /* ─── Mobile small ─── */
      @media (max-width: 480px) {
        h2 {
          font-size: 18px;
        }
        .subtitle {
          font-size: 13px;
          margin-bottom: 16px;
        }
        .kpi-grid {
          grid-template-columns: 1fr 1fr;
          gap: 8px;
        }
        .kpi-card {
          gap: 8px;
        }
        .kpi-icon {
          width: 32px;
          height: 32px;
        }
        .kpi-value {
          font-size: 16px;
        }
        .chart-card {
          min-height: 220px;
        }
        .chart-card h3 {
          font-size: 13px;
          margin-bottom: 12px;
        }
      }
    `,
  ],
})
export class ReportsDashboardComponent implements OnInit {
  private analytics = inject(AnalyticsService);
  private analyticsAdmin = inject(AnalyticsAdminService);

  readonly loading = signal(true);
  readonly overview = signal<OverviewData | null>(null);
  readonly usersOverTime = signal<DataPoint[]>([]);
  readonly practiceOverTime = signal<DataPoint[]>([]);
  readonly socialTimeSeries = signal<MultiSeries[]>([]);
  readonly reportsOverTime = signal<DataPoint[]>([]);
  readonly lessonsByCategory = signal<DataPoint[]>([]);
  readonly lessonsByDifficulty = signal<DataPoint[]>([]);
  readonly reportsByStatus = signal<DataPoint[]>([]);
  readonly topLessons = signal<DataPoint[]>([]);
  readonly instrumentMetrics = signal<InstrumentMetrics[]>([]);
  readonly selectedDays = signal(30);

  readonly usersTimeSeries = signal<MultiSeries[]>([]);
  readonly practiceTimeSeries = signal<MultiSeries[]>([]);

  readonly legendBelow = LegendPosition.Below;

  readonly periods = [
    { label: '7 días', value: 7 },
    { label: '30 días', value: 30 },
    { label: '90 días', value: 90 },
    { label: '1 año', value: 365 },
  ];

  // ─── Color schemes ───
  colorPrimary: Color = {
    name: 'primary',
    selectable: true,
    group: ScaleType.Ordinal,
    domain: ['#06b6d4'],
  };
  colorSuccess: Color = {
    name: 'success',
    selectable: true,
    group: ScaleType.Ordinal,
    domain: ['#10b981'],
  };
  colorWarning: Color = {
    name: 'warning',
    selectable: true,
    group: ScaleType.Ordinal,
    domain: ['#f59e0b'],
  };
  colorSocial: Color = {
    name: 'social',
    selectable: true,
    group: ScaleType.Ordinal,
    domain: ['#3b82f6', '#8b5cf6', '#ef4444'],
  };
  colorMulti: Color = {
    name: 'multi',
    selectable: true,
    group: ScaleType.Ordinal,
    domain: ['#06b6d4', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#f97316', '#3b82f6'],
  };
  colorDifficulty: Color = {
    name: 'diff',
    selectable: true,
    group: ScaleType.Ordinal,
    domain: ['#10b981', '#f59e0b', '#ef4444'],
  };
  colorReportStatus: Color = {
    name: 'report',
    selectable: true,
    group: ScaleType.Ordinal,
    domain: ['#f59e0b', '#10b981', '#ef4444', '#6b7280'],
  };

  ngOnInit(): void {
    this.loadAll();
  }

  changePeriod(days: number): void {
    this.selectedDays.set(days);
    this.loadTimeSeries(days);
  }

  private loadAll(): void {
    this.loading.set(true);
    forkJoin({
      overview: this.analytics.getOverview(),
      users: this.analytics.getUsersOverTime(this.selectedDays()),
      practice: this.analytics.getPracticeOverTime(this.selectedDays()),
      social: this.analytics.getSocialOverTime(this.selectedDays()),
      reports: this.analytics.getReportsOverTime(this.selectedDays()),
      byCategory: this.analytics.getLessonsByCategory(),
      byDifficulty: this.analytics.getLessonsByDifficulty(),
      byStatus: this.analytics.getReportsByStatus(),
      topLessons: this.analytics.getTopLessons(),
      instruments: this.analyticsAdmin
        .getInstrumentMetrics('all')
        .pipe(catchError(() => of([] as InstrumentMetrics[]))),
    }).subscribe({
      next: (data) => {
        this.overview.set(data.overview);
        this.setTimeSeriesData(data.users, data.practice, data.social, data.reports);
        this.lessonsByCategory.set(data.byCategory);
        this.lessonsByDifficulty.set(data.byDifficulty);
        this.reportsByStatus.set(data.byStatus);
        this.topLessons.set(data.topLessons);
        this.instrumentMetrics.set(data.instruments);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  private loadTimeSeries(days: number): void {
    forkJoin({
      users: this.analytics.getUsersOverTime(days),
      practice: this.analytics.getPracticeOverTime(days),
      social: this.analytics.getSocialOverTime(days),
      reports: this.analytics.getReportsOverTime(days),
    }).subscribe((data) => {
      this.setTimeSeriesData(data.users, data.practice, data.social, data.reports);
    });
  }

  private setTimeSeriesData(
    users: DataPoint[],
    practice: DataPoint[],
    social: { posts: DataPoint[]; comments: DataPoint[]; likes: DataPoint[] },
    reports: DataPoint[],
  ): void {
    this.usersOverTime.set(users);
    this.practiceOverTime.set(practice);
    this.reportsOverTime.set(this.formatDates(reports));

    this.usersTimeSeries.set([{ name: 'Registros', series: this.formatDates(users) }]);
    this.practiceTimeSeries.set([{ name: 'Sesiones', series: this.formatDates(practice) }]);
    this.socialTimeSeries.set([
      { name: 'Posts', series: this.formatDates(social.posts) },
      { name: 'Comentarios', series: this.formatDates(social.comments) },
      { name: 'Likes', series: this.formatDates(social.likes) },
    ]);
  }

  private formatDates(data: DataPoint[]): DataPoint[] {
    return data.map((d) => ({
      name: new Date(d.name + 'T00:00:00').toLocaleDateString('es', {
        day: '2-digit',
        month: 'short',
      }),
      value: d.value,
    }));
  }
}
