import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';
import { LucideArrowLeft } from '@lucide/angular';

import { LessonService } from '../../../core/services/lesson.service';
import { CategoryService } from '../../../core/services/category.service';
import { UploadService } from '../../../core/services/upload.service';
import { ANDEAN_INSTRUMENT_OPTIONS } from '../../../core/models/lesson.model';

@Component({
  selector: 'app-lesson-form',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, LucideArrowLeft],
  template: `
    <div class="lesson-form-wrapper">
      <div class="header-row">
        <h2>{{ isEdit() ? 'Editar Lección' : 'Nueva Lección' }}</h2>
        <button class="btn btn-ghost" (click)="goBack()">
          <svg lucideArrowLeft [size]="16"></svg> Volver
        </button>
      </div>

      <div class="form-card card">
        <form [formGroup]="form" (ngSubmit)="save()">
          <div class="form-group">
            <label>Título</label>
            <input
              class="form-input"
              formControlName="title"
              placeholder="Ej: Escala de Do Mayor"
            />
            @if (form.get('title')?.hasError('required') && form.get('title')?.touched) {
              <span class="form-error">El título es obligatorio</span>
            }
          </div>

          <div class="form-group">
            <label>Descripción</label>
            <textarea class="form-textarea" formControlName="description" rows="3"></textarea>
          </div>

          <div class="form-group">
            <label for="instrument">Instrumento andino</label>
            <select id="instrument" class="form-select" formControlName="instrument">
              @for (opt of instruments; track opt.value) {
                <option [value]="opt.value">{{ opt.label }}</option>
              }
            </select>
            @if (form.get('instrument')?.hasError('required') && form.get('instrument')?.touched) {
              <span class="form-error">El instrumento es obligatorio</span>
            }
          </div>

          <div class="row-2">
            <div class="form-group">
              <label>Categoría</label>
              <select class="form-select" formControlName="category_id">
                <option value="">Seleccionar...</option>
                @for (cat of categoryService.categories(); track cat.id) {
                  <option [value]="cat.id">{{ cat.name }}</option>
                }
              </select>
              @if (
                form.get('category_id')?.hasError('required') && form.get('category_id')?.touched
              ) {
                <span class="form-error">La categoría es obligatoria</span>
              }
            </div>

            <div class="form-group">
              <label>Dificultad</label>
              <select class="form-select" formControlName="difficulty">
                <option value="principiante">Principiante</option>
                <option value="intermedio">Intermedio</option>
                <option value="avanzado">Avanzado</option>
              </select>
            </div>
          </div>

          <div class="row-3">
            <div class="form-group">
              <label>Tempo (BPM)</label>
              <input class="form-input" formControlName="tempo_bpm" type="number" />
            </div>

            <div class="form-group">
              <label>Compás</label>
              <input class="form-input" formControlName="time_signature" placeholder="4/4" />
            </div>

            <div class="form-group">
              <label>Tonalidad</label>
              <input class="form-input" formControlName="key_signature" placeholder="C" />
            </div>
          </div>

          <div class="row-2">
            <div class="form-group">
              <label>Orden</label>
              <input class="form-input" formControlName="order" type="number" />
            </div>

            <div class="checkbox-field">
              <label class="checkbox">
                <input type="checkbox" formControlName="is_premium" />
                <span>Lección Premium</span>
              </label>
            </div>
          </div>

          <!-- Audio preview -->
          <div class="form-group">
            <label>Audio preview (.mp3)</label>
            @if (form.value.audio_preview_url) {
              <div class="audio-preview">
                <audio [src]="form.value.audio_preview_url" controls></audio>
                <button type="button" class="btn-link" (click)="clearAudio()">Quitar</button>
              </div>
            }
            <input
              type="file"
              accept="audio/mpeg,audio/mp3,audio/wav,audio/x-m4a"
              (change)="onAudioSelected($event)"
              [disabled]="uploadingAudio()"
            />
            @if (uploadingAudio()) {
              <small class="hint">Subiendo audio…</small>
            } @else if (form.value.audio_preview_url) {
              <small class="hint"
                >El audio actual se muestra arriba. Subí uno nuevo para reemplazarlo.</small
              >
            } @else {
              <small class="hint"
                >Opcional. El alumno podrá escuchar la lección antes de practicarla.</small
              >
            }
          </div>

          <div class="actions">
            <button type="button" class="btn btn-ghost" (click)="goBack()">Cancelar</button>
            <button type="submit" class="btn btn-primary" [disabled]="form.invalid || saving()">
              {{ saving() ? 'Guardando...' : isEdit() ? 'Actualizar' : 'Crear' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  `,
  styles: [
    `
      .lesson-form-wrapper {
        max-width: 800px;
        margin: 0 auto;
      }
      .header-row {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 20px;
      }
      .header-row h2 {
        color: var(--text-secondary);
        margin: 0;
      }
      .form-card {
        padding: 24px;
      }
      .row-2 {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 16px;
      }
      .row-3 {
        display: grid;
        grid-template-columns: 1fr 1fr 1fr;
        gap: 16px;
      }
      .checkbox-field {
        display: flex;
        align-items: center;
        padding-top: 24px;
      }
      .form-group {
        margin-bottom: 16px;
      }
      .actions {
        display: flex;
        justify-content: flex-end;
        gap: 12px;
        margin-top: 16px;
      }
      .audio-preview {
        display: flex;
        align-items: center;
        gap: 12px;
        margin-bottom: 8px;
      }
      .audio-preview audio {
        flex: 1;
        height: 36px;
      }
      .btn-link {
        background: none;
        border: none;
        color: var(--color-error);
        cursor: pointer;
        font-size: 13px;
        padding: 4px 8px;
      }
      .hint {
        display: block;
        color: var(--text-muted);
        font-size: 12px;
        margin-top: 4px;
      }
    `,
  ],
})
export class LessonFormComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly lessonService = inject(LessonService);
  readonly categoryService = inject(CategoryService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly snackBar = inject(MatSnackBar);
  private readonly uploadService = inject(UploadService);

  readonly isEdit = signal(false);
  readonly saving = signal(false);
  readonly uploadingAudio = signal(false);
  private lessonId = '';

  readonly instruments = ANDEAN_INSTRUMENT_OPTIONS;

  form!: FormGroup;

  ngOnInit(): void {
    this.categoryService.loadCategories().subscribe();

    this.form = this.fb.group({
      title: ['', Validators.required],
      description: [''],
      instrument: ['quena', Validators.required],
      category_id: ['', Validators.required],
      difficulty: ['principiante', Validators.required],
      tempo_bpm: [120, [Validators.required, Validators.min(20), Validators.max(300)]],
      time_signature: ['4/4'],
      key_signature: ['C'],
      order: [0],
      is_premium: [false],
      audio_preview_url: [''],
    });

    const id = this.route.snapshot.paramMap.get('id');
    if (id) {
      this.isEdit.set(true);
      this.lessonId = id;
      this.lessonService.getLesson(id).subscribe({
        next: (lesson) => {
          this.form.patchValue({
            title: lesson.title,
            description: lesson.description,
            instrument: lesson.instrument ?? 'quena',
            category_id: lesson.category_id,
            difficulty: lesson.difficulty,
            tempo_bpm: lesson.tempo_bpm,
            time_signature: lesson.time_signature,
            key_signature: lesson.key_signature,
            order: lesson.order,
            is_premium: lesson.is_premium,
            audio_preview_url: lesson.audio_preview_url ?? '',
          });
        },
      });
    }
  }

  save(): void {
    if (this.form.invalid) return;
    this.saving.set(true);

    const payload = this.form.value;

    const op = this.isEdit()
      ? this.lessonService.update(this.lessonId, payload)
      : this.lessonService.create(payload);

    op.subscribe({
      next: () => {
        this.snackBar.open(this.isEdit() ? 'Lección actualizada' : 'Lección creada', 'OK', {
          duration: 3000,
        });
        this.router.navigate(['/admin/lessons/list']);
      },
      error: (err) => {
        this.saving.set(false);
        this.snackBar.open(err.error?.detail || 'Error al guardar', 'OK', { duration: 3000 });
      },
    });
  }

  goBack(): void {
    this.router.navigate(['/admin/lessons/list']);
  }

  onAudioSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    this.uploadingAudio.set(true);
    this.uploadService.uploadFile(file, 'lessons').subscribe({
      next: (url) => {
        this.form.patchValue({ audio_preview_url: url });
        this.uploadingAudio.set(false);
        this.snackBar.open('Audio subido correctamente', 'OK', { duration: 2500 });
      },
      error: (err) => {
        this.uploadingAudio.set(false);
        this.snackBar.open(`Error al subir el audio: ${err.error?.detail ?? err.message}`, 'OK', {
          duration: 4000,
        });
      },
    });
  }

  clearAudio(): void {
    this.form.patchValue({ audio_preview_url: '' });
  }
}
