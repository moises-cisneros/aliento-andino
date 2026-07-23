import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { forkJoin } from 'rxjs';
import { NgxChartsModule, Color, ScaleType } from '@swimlane/ngx-charts';
import { LucideLoader, LucideDownload } from '@lucide/angular';

import { CsvExportService } from '../../../core/services/csv-export.service';

import {
  BusinessAnalyticsService,
  FunnelData,
  RetentionData,
  DataPoint,
  LessonPerformance,
  AiUsage,
  AiUsageBucket,
} from '../../../core/services/business-analytics.service';

@Component({
  selector: 'app-business-dashboard',
  standalone: true,
  imports: [CommonModule, NgxChartsModule, LucideLoader, LucideDownload],
  template: `
    <div class="page-header">
      <h2 class="page-title">Negocio</h2>
    </div>

    @if (loading()) {
      <div class="loading-container"><svg lucideLoader [size]="32" class="spinner icon-primary"></svg></div>
    } @else {
      <!-- Embudo de conversión -->
      <h3 class="section-title">Embudo de conversión</h3>
      @if (funnel(); as f) {
        <div class="funnel">
          <div class="funnel-step">
            <span class="funnel-value">{{ f.registered }}</span>
            <span class="funnel-label">Registrados</span>
            <span class="funnel-pct">100%</span>
          </div>
          <div class="funnel-arrow">→</div>
          <div class="funnel-step">
            <span class="funnel-value">{{ f.practiced }}</span>
            <span class="funnel-label">Practicaron</span>
            <span class="funnel-pct">{{ f.practiced_pct }}% del total</span>
          </div>
          <div class="funnel-arrow">→</div>
          <div class="funnel-step premium">
            <span class="funnel-value">{{ f.premium }}</span>
            <span class="funnel-label">Premium</span>
            <span class="funnel-pct">{{ f.premium_pct }}% del total</span>
          </div>
        </div>
      }

      <!-- Retención -->
      <h3 class="section-title">Retención y actividad</h3>
      @if (retention(); as r) {
        <div class="kpi-row">
          <div class="kpi-card"><span class="kpi-value">{{ r.active_7d }}</span><span class="kpi-label">Activos últimos 7 días ({{ r.active_7d_pct }}%)</span></div>
          <div class="kpi-card"><span class="kpi-value">{{ r.active_30d }}</span><span class="kpi-label">Activos últimos 30 días ({{ r.active_30d_pct }}%)</span></div>
          <div class="kpi-card"><span class="kpi-value">{{ r.active_premium }}</span><span class="kpi-label">Premium activos</span></div>
          <div class="kpi-card"><span class="kpi-value">{{ r.expired_premium }}</span><span class="kpi-label">Premium vencidos (churn)</span></div>
        </div>
      }

      <!-- Altas premium en el tiempo -->
      <h3 class="section-title">Altas de premium (últimos 90 días)</h3>
      <div class="chart-card">
        @if (premiumSeries()[0].series.length > 0) {
          <div class="chart-wrapper">
            <ngx-charts-line-chart
              [results]="premiumSeries()"
              [xAxis]="true" [yAxis]="true" [autoScale]="true"
              [scheme]="colorPrimary">
            </ngx-charts-line-chart>
          </div>
        } @else {
          <div class="chart-empty">Todavía no hay altas de premium en el período.</div>
        }
      </div>

      <!-- Lecciones donde más cuesta -->
      <div class="section-head">
        <h3 class="section-title">Lecciones donde más cuesta (menor score promedio)</h3>
        <button class="btn btn-ghost export-btn"
                [disabled]="csvExport.downloading() === 'lesson-performance.csv'"
                (click)="csvExport.exportLessonPerformance()">
          <svg lucideDownload [size]="15"></svg> Exportar CSV
        </button>
      </div>
      <div class="table-container">
        <table class="table">
          <thead><tr><th>Lección</th><th>Intentos</th><th>Score promedio</th></tr></thead>
          <tbody>
            @for (l of lessonPerf(); track l.title) {
              <tr>
                <td>{{ l.title }}</td>
                <td>{{ l.attempts }}</td>
                <td><span [class.low]="l.avg_score < 60">{{ l.avg_score }}%</span></td>
              </tr>
            }
            @if (lessonPerf().length === 0) {
              <tr><td colspan="3" class="empty">Sin datos de práctica todavía.</td></tr>
            }
          </tbody>
        </table>
      </div>

      <!-- Costo de IA -->
      <h3 class="section-title">Costo de IA (Gemini · feedback de práctica + tutor Vivi)</h3>
      @if (aiUsage(); as ai) {
        @if (ai.has_real) {
          <!-- Datos REALES (tokens de usage_metadata) -->
          <div class="kpi-row">
            <div class="kpi-card"><span class="kpi-value small">{{ ai.model }}</span><span class="kpi-label">Modelo</span></div>
            <div class="kpi-card"><span class="kpi-value">{{ ai.real.total.calls }}</span><span class="kpi-label">Llamadas reales (total · {{ ai.real.last30.calls }} en 30d)</span></div>
            <div class="kpi-card"><span class="kpi-value">{{ ai.real.total.total_tokens | number }}</span><span class="kpi-label">Tokens reales (in {{ ai.real.total.input_tokens | number }} / out {{ ai.real.total.output_tokens | number }})</span></div>
            <div class="kpi-card"><span class="kpi-value">\${{ ai.real.total.cost_usd | number: '1.2-4' }}</span><span class="kpi-label">Costo real total (30d \${{ ai.real.last30.cost_usd | number: '1.2-4' }})</span></div>
          </div>
          <div class="table-container">
            <table class="table">
              <thead><tr><th>Tipo</th><th>Llamadas</th><th>Tokens entrada</th><th>Tokens salida</th><th>Costo real</th></tr></thead>
              <tbody>
                @for (k of realKinds(); track k.key) {
                  <tr>
                    <td>{{ kindLabel(k.key) }}</td>
                    <td>{{ k.calls | number }}</td>
                    <td>{{ k.input_tokens | number }}</td>
                    <td>{{ k.output_tokens | number }}</td>
                    <td>\${{ k.cost_usd | number: '1.2-6' }}</td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
          <div class="ai-note">
            {{ ai.note }}
            <span class="ai-assumptions">
              Precios: \${{ ai.price_input_per_1m_usd }}/1M tokens de entrada, \${{ ai.price_output_per_1m_usd }}/1M de salida.
            </span>
          </div>
        } @else {
          <!-- Aún sin tokens reales: estimado -->
          <div class="kpi-row">
            <div class="kpi-card"><span class="kpi-value small">{{ ai.model }}</span><span class="kpi-label">Modelo</span></div>
            <div class="kpi-card"><span class="kpi-value">{{ ai.total_feedback_calls }}</span><span class="kpi-label">Llamadas de feedback (total · {{ ai.feedback_calls_30d }} en 30d)</span></div>
            <div class="kpi-card"><span class="kpi-value">\${{ ai.est_total_cost_usd | number: '1.2-4' }}</span><span class="kpi-label">Costo estimado total</span></div>
            <div class="kpi-card"><span class="kpi-value">\${{ ai.est_cost_30d_usd | number: '1.2-4' }}</span><span class="kpi-label">Costo estimado últimos 30 días</span></div>
          </div>
          <div class="ai-note">
            {{ ai.note }}
            <span class="ai-assumptions">
              Supuestos: ~{{ ai.assumptions.avg_input_tokens }} tokens entrada + {{ ai.assumptions.avg_output_tokens }} salida por llamada;
              \${{ ai.assumptions.price_input_per_1m_usd }}/1M entrada, \${{ ai.assumptions.price_output_per_1m_usd }}/1M salida
              (= \${{ ai.est_cost_per_call_usd | number: '1.2-6' }} por llamada).
            </span>
          </div>
        }
        <div class="chart-card">
          @if (aiSeries()[0].series.length > 0) {
            <div class="chart-wrapper">
              <ngx-charts-line-chart [results]="aiSeries()" [xAxis]="true" [yAxis]="true" [autoScale]="true" [scheme]="colorViolet"></ngx-charts-line-chart>
            </div>
          } @else {
            <div class="chart-empty">Sin llamadas de IA en el período.</div>
          }
        </div>
      }
    }
  `,
  styles: [`
    :host { display: block; }
    .page-header { margin-bottom: 8px; }
    .page-title { color: var(--color-primary); font-size: 22px; margin: 0; }
    .section-title { color: var(--text-secondary); font-size: 15px; margin: 26px 0 12px; }
    .section-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
    .section-head .section-title { margin-bottom: 12px; }
    .export-btn { display: inline-flex; align-items: center; gap: 6px; flex-shrink: 0; }

    .loading-container { display: flex; justify-content: center; padding: 64px; }
    .spinner { animation: spin 1s linear infinite; }
    @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

    .funnel { display: flex; align-items: stretch; gap: 8px; flex-wrap: wrap; }
    .funnel-step { flex: 1; min-width: 140px; background: var(--bg-surface); border: 1px solid var(--bg-border); border-radius: 12px; padding: 16px; display: flex; flex-direction: column; gap: 2px; }
    .funnel-step.premium { border-color: var(--color-success); }
    .funnel-value { font-size: 26px; font-weight: 700; color: var(--text-primary); }
    .funnel-label { font-size: 13px; color: var(--text-secondary); }
    .funnel-pct { font-size: 12px; color: var(--color-primary); margin-top: 4px; }
    .funnel-arrow { display: flex; align-items: center; color: var(--text-dimmed); font-size: 20px; }

    .kpi-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
    .kpi-card { background: var(--bg-surface); border: 1px solid var(--bg-border); border-radius: 12px; padding: 14px 16px; }
    .kpi-value { display: block; font-size: 24px; font-weight: 700; color: var(--text-primary); }
    .kpi-label { display: block; font-size: 11.5px; color: var(--text-dimmed); margin-top: 2px; }

    .chart-card { background: var(--bg-surface); border: 1px solid var(--bg-border); border-radius: 12px; padding: 12px; }
    .chart-wrapper { height: 280px; }
    .chart-empty { padding: 48px; text-align: center; color: var(--text-dimmed); }

    .low { color: var(--color-error); font-weight: 600; }
    .empty { text-align: center; color: var(--text-dimmed); padding: 24px; }

    .kpi-value.small { font-size: 16px; }
    .ai-note { font-size: 12px; color: var(--text-muted); background: var(--bg-surface-alt); border: 1px solid var(--bg-border); border-radius: 10px; padding: 10px 14px; margin: 12px 0; line-height: 1.5; }
    .ai-assumptions { display: block; color: var(--text-dimmed); margin-top: 4px; }
  `],
})
export class BusinessDashboardComponent implements OnInit {
  private readonly svc = inject(BusinessAnalyticsService);
  readonly csvExport = inject(CsvExportService);

  readonly loading = signal(true);
  readonly funnel = signal<FunnelData | null>(null);
  readonly retention = signal<RetentionData | null>(null);
  readonly premiumSeries = signal<{ name: string; series: DataPoint[] }[]>([{ name: 'Altas premium', series: [] }]);
  readonly lessonPerf = signal<LessonPerformance[]>([]);
  readonly aiUsage = signal<AiUsage | null>(null);
  readonly aiSeries = signal<{ name: string; series: DataPoint[] }[]>([{ name: 'Llamadas IA', series: [] }]);

  colorPrimary: Color = { name: 'primary', selectable: true, group: ScaleType.Ordinal, domain: ['#06b6d4'] };
  colorViolet: Color = { name: 'violet', selectable: true, group: ScaleType.Ordinal, domain: ['#8b5cf6'] };

  ngOnInit(): void {
    forkJoin({
      funnel: this.svc.getFunnel(),
      retention: this.svc.getRetention(),
      premium: this.svc.getPremiumOverTime(90),
      lessons: this.svc.getLessonPerformance(10),
      ai: this.svc.getAiUsage(),
      aiTime: this.svc.getAiUsageOverTime(30),
    }).subscribe({
      next: (d) => {
        this.funnel.set(d.funnel);
        this.retention.set(d.retention);
        this.premiumSeries.set([{ name: 'Altas premium', series: d.premium }]);
        this.lessonPerf.set(d.lessons);
        this.aiUsage.set(d.ai);
        this.aiSeries.set([{ name: 'Llamadas IA', series: d.aiTime }]);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  realKinds(): (AiUsageBucket & { key: string })[] {
    const byKind = this.aiUsage()?.real?.by_kind ?? {};
    return Object.entries(byKind).map(([key, v]) => ({ key, ...v }));
  }

  kindLabel(key: string): string {
    const map: Record<string, string> = {
      practice_feedback: 'Feedback de práctica',
      tutor: 'Tutor Vivi',
    };
    return map[key] ?? key;
  }
}
