import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatSnackBar } from '@angular/material/snack-bar';
import { LucideSend, LucideLoader, LucideCheckCircle, LucideMegaphone } from '@lucide/angular';

import { AnnouncementService, AnnouncementResult } from '../../../core/services/announcement.service';

@Component({
  selector: 'app-announcement-compose',
  standalone: true,
  imports: [CommonModule, FormsModule, LucideSend, LucideLoader, LucideCheckCircle, LucideMegaphone],
  template: `
    <div class="page-header">
      <h2 class="page-title"><svg lucideMegaphone [size]="20"></svg> Anuncios</h2>
    </div>

    <div class="notice">
      Enviá una notificación push (y a la campanita) a tus usuarios. Los que tengan
      el push desactivado igual la verán dentro de la app.
    </div>

    <div class="compose-card">
      <div class="form-group">
        <label>Título</label>
        <input class="form-input" [(ngModel)]="title" maxlength="120"
               placeholder="Ej: ¡Nueva lección disponible!" />
        <span class="counter">{{ title.length }}/120</span>
      </div>

      <div class="form-group">
        <label>Mensaje</label>
        <textarea class="form-input" rows="4" [(ngModel)]="body" maxlength="500"
                  placeholder="Escribí el mensaje del anuncio..."></textarea>
        <span class="counter">{{ body.length }}/500</span>
      </div>

      <div class="form-group">
        <label>Destinatarios</label>
        <select class="form-select" [(ngModel)]="segment">
          <option value="all">Todos los usuarios</option>
          <option value="premium">Solo Premium</option>
          <option value="free">Solo Gratuitos</option>
        </select>
      </div>

      <button class="btn btn-primary send-btn" [disabled]="!canSend() || sending()" (click)="send()">
        @if (sending()) {
          <svg lucideLoader [size]="16" class="spinner"></svg> Enviando...
        } @else {
          <svg lucideSend [size]="16"></svg> Enviar anuncio
        }
      </button>

      @if (lastResult(); as r) {
        <div class="result">
          <svg lucideCheckCircle [size]="18"></svg>
          Enviado a <strong>{{ r.recipients }}</strong> usuarios
          ({{ r.delivered }} dispositivos con push).
        </div>
      }
    </div>
  `,
  styles: [`
    :host { display: block; max-width: 640px; }
    .page-header { margin-bottom: 16px; }
    .page-title { color: var(--color-primary); font-size: 22px; margin: 0; display: flex; align-items: center; gap: 8px; }
    .notice { font-size: 13px; color: var(--text-muted); background: var(--bg-surface-alt); border: 1px solid var(--bg-border); border-radius: 10px; padding: 10px 14px; margin-bottom: 20px; }

    .compose-card { background: var(--bg-surface); border: 1px solid var(--bg-border); border-radius: 14px; padding: 22px; }
    .form-group { margin-bottom: 18px; position: relative; }
    .form-group label { display: block; font-size: 13px; color: var(--text-secondary); margin-bottom: 6px; font-weight: 500; }
    textarea.form-input { resize: vertical; font-family: inherit; }
    .counter { position: absolute; right: 4px; bottom: -16px; font-size: 11px; color: var(--text-dimmed); }

    .send-btn { display: inline-flex; align-items: center; gap: 8px; margin-top: 6px; }
    .spinner { animation: spin 1s linear infinite; }
    @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

    .result { display: flex; align-items: center; gap: 8px; margin-top: 18px; padding: 12px 14px; border-radius: 10px; background: var(--color-success-subtle); color: var(--color-success); font-size: 14px; }
  `],
})
export class AnnouncementComposeComponent {
  private readonly svc = inject(AnnouncementService);
  private readonly snackBar = inject(MatSnackBar);

  title = '';
  body = '';
  segment = 'all';
  readonly sending = signal(false);
  readonly lastResult = signal<AnnouncementResult | null>(null);

  canSend(): boolean {
    return this.title.trim().length > 0 && this.body.trim().length > 0;
  }

  send(): void {
    if (!this.canSend()) return;
    const label = this.segment === 'premium' ? 'los usuarios Premium'
      : this.segment === 'free' ? 'los usuarios Gratuitos' : 'TODOS los usuarios';
    if (!confirm(`¿Enviar este anuncio a ${label}?`)) return;

    this.sending.set(true);
    this.lastResult.set(null);
    this.svc.send(this.title.trim(), this.body.trim(), this.segment).subscribe({
      next: (r) => {
        this.sending.set(false);
        this.lastResult.set(r);
        this.snackBar.open('Anuncio enviado', 'OK', { duration: 3000 });
        this.title = '';
        this.body = '';
      },
      error: () => {
        this.sending.set(false);
        this.snackBar.open('Error al enviar el anuncio', 'OK', { duration: 3000 });
      },
    });
  }
}
