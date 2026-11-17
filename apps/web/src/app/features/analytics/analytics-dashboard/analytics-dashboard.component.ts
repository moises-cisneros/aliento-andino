import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatSnackBar } from '@angular/material/snack-bar';

import {
  AnalyticsAdminService,
  InstrumentMetrics,
} from '../../../core/services/analytics-admin.service';

/**
 * [SUB-21-B] Tablero de analítica pedagógica por instrumento andino.
 *
 * Muestra, con señales reactivas, la precisión de notas y la tasa de
 * finalización por instrumento (barras SVG nativas), con filtro por instrumento
 * y exportación a CSV. Consume [AnalyticsAdminService].
 */
@Component({
  selector: 'app-analytics-dashboard',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="analytics-dashboard">
      <div class="header-row">
        <h2>Reportes analíticos por instrumento</h2>
        <div class="controls">
          <select
            class="form-select"
            [ngModel]="instrument()"
            (ngModelChange)="onInstrumentChange($event)"
            aria-label="Filtrar por instrumento"
          >
            <option value="all">Todos los instrumentos</option>
            <option value="quena">Quena</option>
            <option value="zampona">Zampoña</option>
            <option value="tarka">Tarka</option>
          </select>
          <button
            class="btn-export"
            type="button"
            [disabled]="exporting() || metrics().length === 0"
            (click)="exportCsv()"
          >
            {{ exporting() ? 'Generando…' : 'Exportar CSV' }}
          </button>
        </div>
      </div>

      @if (loading()) {
        <p class="state-msg">Cargando métricas…</p>
      } @else if (metrics().length === 0) {
        <p class="state-msg" data-test="empty">Sin datos para el filtro seleccionado.</p>
      } @else {
        <div class="cards">
          @for (m of metrics(); track m.instrument) {
            <div class="metric-card" data-test="metric-card">
              <h3>{{ instrumentLabel(m.instrument) }}</h3>
              <p class="sessions">{{ m.sessions }} sesiones</p>

              <div class="metric">
                <span class="metric-label">Precisión de notas</span>
                <svg viewBox="0 0 100 8" class="bar" preserveAspectRatio="none">
                  <rect x="0" y="0" width="100" height="8" class="bar-bg"></rect>
                  <rect
                    x="0"
                    y="0"
                    [attr.width]="pct(m.avg_note_precision)"
                    height="8"
                    class="bar-fill precision"
                  ></rect>
                </svg>
                <span class="metric-value">{{ pct(m.avg_note_precision) }}%</span>
              </div>

              <div class="metric">
                <span class="metric-label">Finalización</span>
                <svg viewBox="0 0 100 8" class="bar" preserveAspectRatio="none">
                  <rect x="0" y="0" width="100" height="8" class="bar-bg"></rect>
                  <rect
                    x="0"
                    y="0"
                    [attr.width]="pct(m.completion_rate)"
                    height="8"
                    class="bar-fill completion"
                  ></rect>
                </svg>
                <span class="metric-value">{{ pct(m.completion_rate) }}%</span>
              </div>

              <p class="score">Puntaje medio: {{ m.avg_score }}</p>
            </div>
          }
        </div>
      }
    </div>
  `,
  styles: [
    `
      .header-row {
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 16px;
        flex-wrap: wrap;
        margin-bottom: 16px;
      }
      .header-row h2 {
        margin: 0;
        color: var(--color-primary);
        font-size: 22px;
      }
      .controls {
        display: flex;
        gap: 12px;
        align-items: center;
      }
      .btn-export {
        padding: 8px 16px;
        border: none;
        border-radius: 8px;
        background: var(--color-primary);
        color: #fff;
        cursor: pointer;
      }
      .btn-export:disabled {
        opacity: 0.5;
        cursor: not-allowed;
      }
      .cards {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
        gap: 16px;
      }
      .metric-card {
        background: var(--bg-muted);
        border-radius: 12px;
        padding: 16px;
      }
      .metric-card h3 {
        margin: 0 0 4px;
        text-transform: capitalize;
      }
      .sessions {
        color: var(--text-secondary);
        margin: 0 0 12px;
      }
      .metric {
        display: grid;
        grid-template-columns: 1fr;
        gap: 4px;
        margin-bottom: 12px;
      }
      .metric-label {
        font-size: 13px;
        color: var(--text-secondary);
      }
      .bar {
        width: 100%;
        height: 8px;
      }
      .bar-bg {
        fill: var(--color-outline, #e2e8f0);
      }
      .bar-fill.precision {
        fill: var(--color-primary);
      }
      .bar-fill.completion {
        fill: var(--color-success);
      }
      .metric-value {
        font-size: 13px;
        font-weight: 600;
      }
      .state-msg {
        color: var(--text-secondary);
        padding: 24px 0;
      }
    `,
  ],
})
export class AnalyticsDashboardComponent implements OnInit {
  private readonly service = inject(AnalyticsAdminService);
  private readonly snackBar = inject(MatSnackBar);

  readonly instrument = signal<string>('all');
  readonly metrics = signal<InstrumentMetrics[]>([]);
  readonly loading = signal<boolean>(false);
  readonly exporting = signal<boolean>(false);

  private readonly labels: Record<string, string> = {
    quena: 'Quena',
    zampona: 'Zampoña',
    tarka: 'Tarka',
  };

  ngOnInit(): void {
    this.load();
  }

  instrumentLabel(key: string): string {
    return this.labels[key] ?? key;
  }

  pct(value: number): number {
    return Math.round(value * 100);
  }

  onInstrumentChange(value: string): void {
    this.instrument.set(value);
    this.load();
  }

  load(): void {
    this.loading.set(true);
    this.service.getInstrumentMetrics(this.instrument()).subscribe({
      next: (rows) => {
        this.metrics.set(rows);
        this.loading.set(false);
      },
      error: () => {
        this.metrics.set([]);
        this.loading.set(false);
      },
    });
  }

  exportCsv(): void {
    this.exporting.set(true);
    this.service.exportMetricsCsv(this.instrument()).subscribe({
      next: (blob) => {
        this.exporting.set(false);
        this.triggerDownload(blob, `metricas-${this.instrument()}.csv`);
      },
      error: () => {
        this.exporting.set(false);
        this.snackBar.open('Error al generar archivo de exportación', 'OK', {
          duration: 3000,
        });
      },
    });
  }

  private triggerDownload(blob: Blob, filename: string): void {
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    URL.revokeObjectURL(url);
  }
}
