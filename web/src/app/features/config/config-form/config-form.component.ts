import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatSnackBar } from '@angular/material/snack-bar';
import { LucideSettings, LucideSave, LucideLoader, LucideSparkles } from '@lucide/angular';

import { ConfigAdminService, AppConfig } from '../../../core/services/config-admin.service';

@Component({
  selector: 'app-config-form',
  standalone: true,
  imports: [CommonModule, FormsModule, LucideSettings, LucideSave, LucideLoader, LucideSparkles],
  template: `
    <div class="page-header">
      <h2 class="page-title"><svg lucideSettings [size]="20"></svg> Configuración</h2>
    </div>

    <div class="notice">
      Estos valores afectan la app en vivo: los precios se muestran a los clientes en la
      pantalla de planes y se usan para estimar el MRR; los días de prueba aplican a las nuevas
      pruebas gratis; el feedback de IA se puede apagar para no gastar en Gemini.
    </div>

    @if (loading()) {
      <div class="loading"><svg lucideLoader [size]="20" class="spinner"></svg> Cargando...</div>
    } @else if (config(); as c) {
      <div class="config-card">
        <h3 class="section-title">Planes y precios</h3>

        <div class="form-row">
          <div class="form-group">
            <label>Precio mensual (USD)</label>
            <div class="input-prefix">
              <span class="prefix">$</span>
              <input type="number" class="form-input" min="0" step="0.01"
                     [(ngModel)]="c.price_monthly" />
            </div>
          </div>
          <div class="form-group">
            <label>Precio anual (USD)</label>
            <div class="input-prefix">
              <span class="prefix">$</span>
              <input type="number" class="form-input" min="0" step="0.01"
                     [(ngModel)]="c.price_annual" />
            </div>
            <span class="hint">≈ \${{ (c.price_annual / 12) | number: '1.2-2' }}/mes</span>
          </div>
        </div>

        <div class="form-group">
          <label>Días de prueba gratis</label>
          <input type="number" class="form-input narrow" min="0" step="1"
                 [(ngModel)]="c.trial_days" />
        </div>

        <h3 class="section-title">Funciones</h3>

        <label class="toggle-row">
          <div class="toggle-text">
            <span class="toggle-label"><svg lucideSparkles [size]="15"></svg> Feedback de IA</span>
            <span class="toggle-desc">
              Genera el resumen con Gemini al terminar una práctica. Apagalo para cortar el gasto.
            </span>
          </div>
          <input type="checkbox" class="switch" [(ngModel)]="c.ai_feedback_enabled" />
        </label>

        <button class="btn btn-primary save-btn" [disabled]="saving()" (click)="save()">
          @if (saving()) {
            <svg lucideLoader [size]="16" class="spinner"></svg> Guardando...
          } @else {
            <svg lucideSave [size]="16"></svg> Guardar cambios
          }
        </button>
      </div>
    } @else {
      <div class="notice error">No se pudo cargar la configuración.</div>
    }
  `,
  styles: [`
    :host { display: block; max-width: 640px; }
    .page-header { margin-bottom: 16px; }
    .page-title { color: var(--color-primary); font-size: 22px; margin: 0; display: flex; align-items: center; gap: 8px; }
    .notice { font-size: 13px; color: var(--text-muted); background: var(--bg-surface-alt); border: 1px solid var(--bg-border); border-radius: 10px; padding: 10px 14px; margin-bottom: 20px; }
    .notice.error { color: var(--color-warning); }
    .loading { display: flex; align-items: center; gap: 8px; color: var(--text-muted); padding: 20px; }

    .config-card { background: var(--bg-surface); border: 1px solid var(--bg-border); border-radius: 14px; padding: 22px; }
    .section-title { font-size: 14px; color: var(--text-secondary); margin: 0 0 14px; text-transform: uppercase; letter-spacing: 0.5px; }
    .section-title:not(:first-child) { margin-top: 26px; padding-top: 22px; border-top: 1px solid var(--bg-border); }

    .form-row { display: flex; gap: 16px; }
    .form-row .form-group { flex: 1; }
    .form-group { margin-bottom: 18px; }
    .form-group label { display: block; font-size: 13px; color: var(--text-secondary); margin-bottom: 6px; font-weight: 500; }
    .form-input { width: 100%; }
    .form-input.narrow { max-width: 140px; }
    .input-prefix { position: relative; }
    .input-prefix .prefix { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: var(--text-dimmed); font-size: 14px; }
    .input-prefix .form-input { padding-left: 26px; }
    .hint { display: block; font-size: 11px; color: var(--text-dimmed); margin-top: 4px; }

    .toggle-row { display: flex; align-items: center; justify-content: space-between; gap: 16px; cursor: pointer; padding: 4px 0; }
    .toggle-text { display: flex; flex-direction: column; gap: 3px; }
    .toggle-label { display: flex; align-items: center; gap: 6px; font-size: 14px; color: var(--text-primary); font-weight: 500; }
    .toggle-desc { font-size: 12px; color: var(--text-dimmed); max-width: 460px; }
    .switch { width: 42px; height: 24px; flex-shrink: 0; cursor: pointer; accent-color: var(--color-primary); }

    .save-btn { display: inline-flex; align-items: center; gap: 8px; margin-top: 22px; }
    .spinner { animation: spin 1s linear infinite; }
    @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
  `],
})
export class ConfigFormComponent {
  private readonly svc = inject(ConfigAdminService);
  private readonly snackBar = inject(MatSnackBar);

  readonly config = signal<AppConfig | null>(null);
  readonly loading = signal(true);
  readonly saving = signal(false);

  constructor() {
    this.svc.get().subscribe({
      next: (c) => {
        this.config.set(c);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  save(): void {
    const c = this.config();
    if (!c) return;
    this.saving.set(true);
    this.svc.update({
      price_monthly: Number(c.price_monthly),
      price_annual: Number(c.price_annual),
      trial_days: Number(c.trial_days),
      ai_feedback_enabled: c.ai_feedback_enabled,
    }).subscribe({
      next: (updated) => {
        this.config.set(updated);
        this.saving.set(false);
        this.snackBar.open('Configuración guardada', 'OK', { duration: 3000 });
      },
      error: () => {
        this.saving.set(false);
        this.snackBar.open('Error al guardar la configuración', 'OK', { duration: 3000 });
      },
    });
  }
}
