import {
  Component,
  inject,
  OnInit,
  signal,
  Input,
  Output,
  EventEmitter,
  Optional,
  Inject,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  ReactiveFormsModule,
  FormBuilder,
  FormGroup,
  Validators,
  FormsModule,
} from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import {
  LucidePlus,
  LucideTrash2,
  LucideWind,
  LucideMusic,
  LucideClock,
  LucideCheck,
  LucideAlertCircle,
} from '@lucide/angular';

import { LessonAdminService } from '../../../core/services/lesson-admin.service';
import { CategoryService } from '../../../core/services/category.service';
import {
  Lesson,
  LessonCreate,
  NoteSequenceCreate,
  AndeanInstrument,
  LessonDifficulty,
} from '../../../core/models/lesson.model';

@Component({
  selector: 'app-lesson-form-dialog',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    FormsModule,
    MatDialogModule,
    LucidePlus,
    LucideTrash2,
    LucideWind,
    LucideMusic,
    LucideClock,
    LucideCheck,
    LucideAlertCircle,
  ],
  template: `
    <div class="lesson-dialog-container">
      <h2 mat-dialog-title class="dialog-title">
        <svg lucideMusic [size]="20" class="title-icon"></svg>
        {{ isEdit() ? 'Editar Lección Andina' : 'Crear Nueva Lección Andina' }}
      </h2>

      <mat-dialog-content class="dialog-content">
        <form [formGroup]="form" class="lesson-form-grid">
          <!-- Sección Datos Generales -->
          <div class="section-title">Metadatos Curriculares</div>

          <div class="form-group full-width">
            <label class="form-label" for="title">Título de la Lección *</label>
            <input
              id="title"
              class="form-input"
              formControlName="title"
              placeholder="Ej: El Cóndor Pasa - Introducción en Quena"
            />
            @if (form.get('title')?.hasError('required') && form.get('title')?.touched) {
              <span class="form-error">El título es obligatorio</span>
            }
            @if (form.get('title')?.hasError('minlength') && form.get('title')?.touched) {
              <span class="form-error">El título debe tener al menos 3 caracteres</span>
            }
          </div>

          <div class="form-group full-width">
            <label class="form-label" for="description">Descripción Pedagógica *</label>
            <textarea
              id="description"
              class="form-textarea"
              formControlName="description"
              rows="2"
              placeholder="Explicación de digitaciones, respiración y articulación andina"
            ></textarea>
            @if (
              form.get('description')?.hasError('required') && form.get('description')?.touched
            ) {
              <span class="form-error">La descripción es obligatoria</span>
            }
          </div>

          <div class="row-3">
            <div class="form-group">
              <label class="form-label" for="instrument">Instrumento Andino *</label>
              <select id="instrument" class="form-select" formControlName="instrument">
                <option value="quena">Quena</option>
                <option value="zampona">Zampoña (Siku)</option>
                <option value="tarka">Tarka</option>
              </select>
            </div>

            <div class="form-group">
              <label class="form-label" for="category_id">Categoría *</label>
              <select id="category_id" class="form-select" formControlName="category_id">
                <option value="">Seleccionar categoría...</option>
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
              <label class="form-label" for="difficulty">Dificultad *</label>
              <select id="difficulty" class="form-select" formControlName="difficulty">
                <option value="principiante">Principiante</option>
                <option value="intermedio">Intermedio</option>
                <option value="avanzado">Avanzado</option>
              </select>
            </div>
          </div>

          <div class="row-3">
            <div class="form-group">
              <label class="form-label" for="tempo_bpm">Tempo (BPM) *</label>
              <input
                id="tempo_bpm"
                type="number"
                class="form-input"
                formControlName="tempo_bpm"
                min="40"
                max="200"
              />
              @if (
                form.get('tempo_bpm')?.hasError('min') || form.get('tempo_bpm')?.hasError('max')
              ) {
                <span class="form-error">El tempo debe estar entre 40 y 200 BPM</span>
              }
            </div>

            <div class="form-group">
              <label class="form-label" for="time_signature">Compás</label>
              <input
                id="time_signature"
                class="form-input"
                formControlName="time_signature"
                placeholder="4/4, 2/4, 6/8"
              />
            </div>

            <div class="form-group">
              <label class="form-label" for="key_signature">Tonalidad</label>
              <input
                id="key_signature"
                class="form-input"
                formControlName="key_signature"
                placeholder="G, C, Am, Em"
              />
            </div>
          </div>

          <div class="row-2">
            <div class="form-group">
              <label class="form-label" for="genre">Género Musical</label>
              <input
                id="genre"
                class="form-input"
                formControlName="genre"
                placeholder="Huayno, Sikuri, Yaraví, Carnavalito"
              />
            </div>

            <div class="form-group">
              <label class="form-label" for="artist">Autor / Compositor</label>
              <input
                id="artist"
                class="form-input"
                formControlName="artist"
                placeholder="Tradicional andino / Compositor"
              />
            </div>
          </div>

          <!-- Editor Interactivo de Partitura y Secuencia de Notas -->
          <div class="section-title sequence-header">
            <span>Secuencia de Notas Musicales y Marcas de Respiración</span>
            <span class="badge-count">{{ notes().length }} notas añadidas</span>
          </div>

          <div class="note-input-bar">
            <div class="input-inline">
              <label class="sublabel" for="newNoteTone">Nota (Notación Científica):</label>
              <input
                id="newNoteTone"
                class="form-input note-field"
                [(ngModel)]="newNoteTone"
                [ngModelOptions]="{ standalone: true }"
                placeholder="G4, A4, B4, C5, REST"
              />
            </div>

            <div class="input-inline">
              <label class="sublabel" for="newNoteDuration">Duración (Beats):</label>
              <select
                id="newNoteDuration"
                class="form-select duration-select"
                [(ngModel)]="newNoteDuration"
                [ngModelOptions]="{ standalone: true }"
              >
                <option [value]="0.5">0.5 (Corchea)</option>
                <option [value]="1.0">1.0 (Negra)</option>
                <option [value]="1.5">1.5 (Negra con puntillo)</option>
                <option [value]="2.0">2.0 (Blanca)</option>
                <option [value]="4.0">4.0 (Redonda)</option>
              </select>
            </div>

            <div class="input-inline breath-checkbox">
              <label class="checkbox-inline">
                <input
                  type="checkbox"
                  [(ngModel)]="newNoteBreath"
                  [ngModelOptions]="{ standalone: true }"
                />
                <span class="breath-label">
                  <svg lucideWind [size]="14"></svg> Marca de respiración
                </span>
              </label>
            </div>

            <button type="button" class="btn btn-secondary btn-add" (click)="addNote()">
              <svg lucidePlus [size]="16"></svg> Agregar Nota
            </button>
            <button type="button" class="btn btn-ghost btn-rest" (click)="addRest()">
              <svg lucideClock [size]="16"></svg> Silencio
            </button>
          </div>

          <!-- Mensaje de Validación de Secuencia Vacía -->
          @if (notes().length === 0) {
            <div class="empty-notes-warning" id="empty-notes-warning">
              <svg lucideAlertCircle [size]="18" class="warning-icon"></svg>
              <span>Debe agregar al menos una nota musical a la secuencia</span>
            </div>
          } @else {
            <!-- Visualizador interactivo de notas -->
            <div class="notes-chip-container">
              @for (note of notes(); track $index) {
                <div
                  class="note-chip"
                  [class.note-rest]="note.is_rest"
                  [class.has-breath]="note.has_breath_mark"
                >
                  <span class="note-pos">#{{ note.position }}</span>
                  <span class="note-tone">{{ note.is_rest ? 'REST' : note.note }}</span>
                  <span class="note-dur">{{ note.duration }}b</span>

                  @if (note.has_breath_mark) {
                    <span class="breath-indicator" title="Marca de respiración andina">
                      <svg lucideWind [size]="12"></svg>
                    </span>
                  }

                  <button
                    type="button"
                    class="btn-chip-action"
                    (click)="toggleBreathMark($index)"
                    title="Alternar respiración"
                  >
                    🌬️
                  </button>

                  <button
                    type="button"
                    class="btn-chip-delete"
                    (click)="removeNote($index)"
                    title="Eliminar nota"
                  >
                    <svg lucideTrash2 [size]="12"></svg>
                  </button>
                </div>
              }
            </div>
          }
        </form>
      </mat-dialog-content>

      <mat-dialog-actions align="end" class="dialog-actions">
        <button type="button" class="btn btn-ghost" (click)="cancel()">Cancelar</button>
        <button
          type="button"
          class="btn btn-primary btn-save"
          (click)="save()"
          [disabled]="form.invalid || notes().length === 0 || saving()"
        >
          <svg lucideCheck [size]="16"></svg>
          {{ saving() ? 'Guardando...' : isEdit() ? 'Actualizar Lección' : 'Crear Lección' }}
        </button>
      </mat-dialog-actions>
    </div>
  `,
  styles: [
    `
      .lesson-dialog-container {
        display: flex;
        flex-direction: column;
        max-width: 900px;
        color: var(--text-primary);
        background: var(--bg-surface);
        border-radius: 16px;
      }

      .dialog-title {
        display: flex;
        align-items: center;
        gap: 10px;
        margin: 0;
        padding: 20px 24px;
        font-size: 1.25rem;
        font-weight: 600;
        color: var(--text-primary);
        border-bottom: 1px solid var(--bg-border);
      }

      .title-icon {
        color: var(--color-primary);
      }

      .dialog-content {
        padding: 20px 24px;
        max-height: 75vh;
        overflow-y: auto;
      }

      .lesson-form-grid {
        display: flex;
        flex-direction: column;
        gap: 16px;
      }

      .section-title {
        font-size: 0.9rem;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        color: var(--color-primary);
        margin-top: 8px;
        border-bottom: 1px solid var(--bg-border);
        padding-bottom: 6px;
      }

      .sequence-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-top: 16px;
      }

      .badge-count {
        font-size: 0.75rem;
        background: var(--color-primary-subtle);
        color: var(--color-primary);
        padding: 2px 8px;
        border-radius: 12px;
        font-weight: 600;
      }

      .form-group {
        display: flex;
        flex-direction: column;
        gap: 6px;
      }

      .full-width {
        width: 100%;
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

      .form-label {
        font-size: 0.85rem;
        font-weight: 600;
        color: var(--text-secondary);
      }

      .form-input,
      .form-select,
      .form-textarea {
        background: var(--bg-surface-alt);
        border: 1px solid var(--bg-border);
        color: var(--text-primary);
        border-radius: 8px;
        padding: 8px 12px;
        font-size: 0.9rem;
        transition:
          border-color 0.2s,
          box-shadow 0.2s;
      }

      .form-input:focus,
      .form-select:focus,
      .form-textarea:focus {
        outline: none;
        border-color: var(--color-primary);
        box-shadow: 0 0 0 2px var(--color-primary-hover);
      }

      .form-error {
        color: var(--color-error);
        font-size: 0.78rem;
        font-weight: 500;
      }

      /* Barra de notas */
      .note-input-bar {
        display: flex;
        align-items: flex-end;
        gap: 12px;
        background: var(--bg-surface-alt);
        padding: 12px;
        border-radius: 10px;
        border: 1px solid var(--bg-border);
        flex-wrap: wrap;
      }

      .input-inline {
        display: flex;
        flex-direction: column;
        gap: 4px;
      }

      .sublabel {
        font-size: 0.75rem;
        color: var(--text-muted);
      }

      .note-field {
        width: 120px;
      }

      .duration-select {
        min-width: 150px;
      }

      .breath-checkbox {
        justify-content: center;
        padding-bottom: 8px;
      }

      .checkbox-inline {
        display: flex;
        align-items: center;
        gap: 6px;
        font-size: 0.85rem;
        cursor: pointer;
        color: var(--text-secondary);
      }

      .breath-label {
        display: inline-flex;
        align-items: center;
        gap: 4px;
      }

      .empty-notes-warning {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 12px 16px;
        background: var(--color-error-subtle);
        border: 1px solid var(--color-error);
        color: var(--color-error);
        border-radius: 8px;
        font-size: 0.85rem;
        font-weight: 500;
      }

      .notes-chip-container {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        max-height: 180px;
        overflow-y: auto;
        padding: 8px;
        background: var(--bg-body);
        border-radius: 8px;
        border: 1px dashed var(--bg-border);
      }

      .note-chip {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        background: var(--bg-elevated);
        border: 1px solid var(--bg-border);
        padding: 4px 8px;
        border-radius: 6px;
        font-size: 0.85rem;
      }

      .note-chip.has-breath {
        border-color: var(--color-primary);
        box-shadow: 0 0 4px var(--color-primary-hover);
      }

      .note-chip.note-rest {
        opacity: 0.7;
        background: var(--bg-surface-alt);
      }

      .note-pos {
        color: var(--text-muted);
        font-size: 0.75rem;
      }

      .note-tone {
        font-weight: 700;
        color: var(--color-primary);
      }

      .note-dur {
        color: var(--text-dimmed);
        font-size: 0.75rem;
      }

      .breath-indicator {
        color: var(--color-primary);
        display: inline-flex;
      }

      .btn-chip-action,
      .btn-chip-delete {
        background: none;
        border: none;
        cursor: pointer;
        padding: 2px;
        display: inline-flex;
        align-items: center;
        color: var(--text-muted);
        border-radius: 4px;
      }

      .btn-chip-delete:hover {
        color: var(--color-error);
      }

      .dialog-actions {
        padding: 16px 24px;
        border-top: 1px solid var(--bg-border);
        gap: 12px;
      }

      .btn {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        padding: 8px 16px;
        font-size: 0.9rem;
        font-weight: 600;
        border-radius: 8px;
        cursor: pointer;
        transition: all 0.2s;
        border: 1px solid transparent;
      }

      .btn-primary {
        background: var(--color-primary);
        color: #000;
      }

      .btn-primary:hover:not(:disabled) {
        filter: brightness(1.1);
      }

      .btn-primary:disabled {
        opacity: 0.45;
        cursor: not-allowed;
      }

      .btn-secondary {
        background: var(--bg-elevated);
        border-color: var(--bg-border);
        color: var(--text-primary);
      }

      .btn-ghost {
        background: transparent;
        color: var(--text-muted);
      }

      .btn-ghost:hover {
        color: var(--text-primary);
        background: var(--bg-hover);
      }
    `,
  ],
})
export class LessonFormDialogComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  readonly lessonAdminService = inject(LessonAdminService);
  readonly categoryService = inject(CategoryService);
  private readonly snackBar = inject(MatSnackBar);

  @Optional() private readonly dialogRef = inject(MatDialogRef<LessonFormDialogComponent>, {
    optional: true,
  });
  @Optional() @Inject(MAT_DIALOG_DATA) private readonly dialogData?: { lesson?: Lesson };

  @Input() lessonToEdit?: Lesson;
  @Output() saved = new EventEmitter<Lesson>();
  @Output() cancelled = new EventEmitter<void>();

  readonly isEdit = signal(false);
  readonly saving = signal(false);

  // Notas musicales interactivas
  readonly notes = signal<NoteSequenceCreate[]>([]);
  newNoteTone = 'G4';
  newNoteDuration = 1.0;
  newNoteBreath = false;

  readonly form: FormGroup = this.fb.group({
    title: ['', [Validators.required, Validators.minLength(3)]],
    description: ['', [Validators.required]],
    instrument: ['quena', [Validators.required]],
    category_id: ['', [Validators.required]],
    difficulty: ['principiante', [Validators.required]],
    tempo_bpm: [100, [Validators.required, Validators.min(40), Validators.max(200)]],
    time_signature: ['4/4'],
    key_signature: ['C'],
    genre: [''],
    artist: [''],
    order: [0],
    is_premium: [false],
  });

  ngOnInit(): void {
    const target = this.dialogData?.lesson || this.lessonToEdit;
    if (target) {
      this.isEdit.set(true);
      this.form.patchValue({
        title: target.title,
        description: target.description,
        instrument: target.instrument || 'quena',
        category_id: target.category_id,
        difficulty: target.difficulty,
        tempo_bpm: target.tempo_bpm,
        time_signature: target.time_signature || '4/4',
        key_signature: target.key_signature || 'C',
        genre: target.genre || '',
        artist: target.artist || '',
        order: target.order || 0,
        is_premium: target.is_premium || false,
      });

      if (target.notes && target.notes.length > 0) {
        this.notes.set(
          target.notes.map((n) => ({
            position: n.position,
            note: n.note,
            duration: n.duration,
            is_rest: n.is_rest,
            has_breath_mark: n.has_breath_mark || false,
            velocity: n.velocity || 80,
          })),
        );
      }
    }
  }

  addNote(): void {
    const tone = this.newNoteTone.trim().toUpperCase();
    if (!tone) return;

    const nextPos = this.notes().length + 1;
    const isRest = tone === 'REST';

    this.notes.update((prev) => [
      ...prev,
      {
        position: nextPos,
        note: isRest ? 'REST' : tone,
        duration: Number(this.newNoteDuration),
        is_rest: isRest,
        has_breath_mark: this.newNoteBreath,
        velocity: 80,
      },
    ]);

    // Reset breath mark for next note
    this.newNoteBreath = false;
  }

  addRest(): void {
    const nextPos = this.notes().length + 1;
    this.notes.update((prev) => [
      ...prev,
      {
        position: nextPos,
        note: 'REST',
        duration: Number(this.newNoteDuration),
        is_rest: true,
        has_breath_mark: false,
        velocity: 0,
      },
    ]);
  }

  removeNote(index: number): void {
    this.notes.update((prev) => {
      const updated = prev.filter((_, i) => i !== index);
      // Re-index positions
      return updated.map((note, i) => ({ ...note, position: i + 1 }));
    });
  }

  toggleBreathMark(index: number): void {
    this.notes.update((prev) =>
      prev.map((n, i) => (i === index ? { ...n, has_breath_mark: !n.has_breath_mark } : n)),
    );
  }

  save(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    if (this.notes().length === 0) {
      this.snackBar.open('Debe agregar al menos una nota musical a la secuencia', 'Cerrar', {
        duration: 4000,
      });
      return;
    }

    this.saving.set(true);
    const formVal = this.form.value;

    const payload: LessonCreate = {
      title: formVal.title,
      description: formVal.description,
      instrument: formVal.instrument as AndeanInstrument,
      category_id: formVal.category_id,
      difficulty: formVal.difficulty as LessonDifficulty,
      tempo_bpm: Number(formVal.tempo_bpm),
      time_signature: formVal.time_signature,
      key_signature: formVal.key_signature,
      genre: formVal.genre || null,
      artist: formVal.artist || null,
      order: Number(formVal.order || 0),
      is_premium: Boolean(formVal.is_premium),
      notes: this.notes(),
    };

    const target = this.dialogData?.lesson || this.lessonToEdit;

    const req$ =
      this.isEdit() && target?.id
        ? this.lessonAdminService.updateLesson(target.id, payload)
        : this.lessonAdminService.createLesson(payload);

    req$.subscribe({
      next: (savedLesson) => {
        this.saving.set(false);
        this.snackBar.open(
          this.isEdit() ? 'Lección actualizada con éxito' : 'Lección creada con éxito',
          'Cerrar',
          { duration: 3000 },
        );
        this.saved.emit(savedLesson);
        this.dialogRef?.close(savedLesson);
      },
      error: (err) => {
        this.saving.set(false);
        if (err.status === 401 || err.status === 403) {
          this.snackBar.open(
            'Falta de privilegios administrativos para gestionar lecciones',
            'Cerrar',
            { duration: 4000 },
          );
        } else {
          this.snackBar.open(
            err.error?.detail || 'Error al procesar la solicitud de la lección',
            'Cerrar',
            { duration: 4000 },
          );
        }
      },
    });
  }

  cancel(): void {
    this.cancelled.emit();
    this.dialogRef?.close();
  }
}
