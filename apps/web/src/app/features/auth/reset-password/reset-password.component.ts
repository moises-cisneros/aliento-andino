import { Component, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  ReactiveFormsModule,
  FormBuilder,
  FormGroup,
  Validators,
  AbstractControl,
} from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';
import { LucideEye, LucideEyeOff, LucideArrowLeft } from '@lucide/angular';

import { AuthService } from '../../../core/services/auth.service';
import { LoadingSpinnerComponent } from '../../../shared/components/loading-spinner/loading-spinner.component';

@Component({
  selector: 'app-reset-password',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    RouterLink,
    LoadingSpinnerComponent,
    LucideEye,
    LucideEyeOff,
    LucideArrowLeft,
  ],
  template: `
    <div class="page">
      <div class="container">
        <!-- Brand -->
        <div class="brand">
          <img src="logo.svg" alt="Aliento Andino" class="brand-logo" />
          <h1 class="brand-name">Aliento<span class="brand-ai">Andino</span></h1>
        </div>

        <p class="subtitle">Ingresá el código de 6 dígitos y tu nueva contraseña</p>

        <form [formGroup]="resetForm" (ngSubmit)="onSubmit()" class="form">
          <div class="field">
            <input
              class="code-input"
              formControlName="code"
              maxlength="6"
              placeholder="000000"
              autocomplete="one-time-code"
            />
            @if (resetForm.get('code')?.hasError('required') && resetForm.get('code')?.touched) {
              <span class="field-error">El código es obligatorio</span>
            }
            @if (resetForm.get('code')?.hasError('pattern') && resetForm.get('code')?.touched) {
              <span class="field-error">Debe ser un código de 6 dígitos</span>
            }
          </div>

          <div class="field">
            <div class="password-field">
              <input
                formControlName="password"
                [type]="hidePassword() ? 'password' : 'text'"
                placeholder="Nueva contraseña"
                autocomplete="new-password"
              />
              <button type="button" class="toggle-pw" (click)="hidePassword.set(!hidePassword())">
                @if (hidePassword()) {
                  <svg lucideEyeOff [size]="16"></svg>
                } @else {
                  <svg lucideEye [size]="16"></svg>
                }
              </button>
            </div>
            @if (
              resetForm.get('password')?.hasError('required') && resetForm.get('password')?.touched
            ) {
              <span class="field-error">La contraseña es obligatoria</span>
            }
            @if (
              resetForm.get('password')?.hasError('minlength') && resetForm.get('password')?.touched
            ) {
              <span class="field-error">Mínimo 8 caracteres</span>
            }
          </div>

          <div class="field">
            <div class="password-field">
              <input
                formControlName="passwordConfirm"
                [type]="hideConfirm() ? 'password' : 'text'"
                placeholder="Confirmar contraseña"
                autocomplete="new-password"
              />
              <button type="button" class="toggle-pw" (click)="hideConfirm.set(!hideConfirm())">
                @if (hideConfirm()) {
                  <svg lucideEyeOff [size]="16"></svg>
                } @else {
                  <svg lucideEye [size]="16"></svg>
                }
              </button>
            </div>
            @if (
              resetForm.get('passwordConfirm')?.hasError('passwordMismatch') &&
              resetForm.get('passwordConfirm')?.touched
            ) {
              <span class="field-error">Las contraseñas no coinciden</span>
            }
          </div>

          <button class="action-btn" type="submit" [disabled]="isLoading()">
            @if (isLoading()) {
              <app-loading-spinner />
            } @else {
              Cambiar contraseña
            }
          </button>
        </form>

        <a routerLink="/auth/login" class="back-link">
          <svg lucideArrowLeft [size]="15"></svg>
          Volver al inicio de sesión
        </a>
      </div>
    </div>
  `,
  styles: [
    `
      .page {
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 100vh;
        background: var(--bg-body);
      }

      .container {
        width: 100%;
        max-width: 360px;
        padding: 0 24px;
        display: flex;
        flex-direction: column;
        align-items: center;
      }

      /* ── Brand ── */
      .brand {
        display: flex;
        flex-direction: column;
        align-items: center;
        margin-bottom: 32px;
      }

      .brand-logo {
        width: 56px;
        height: 56px;
        margin-bottom: 16px;
        filter: drop-shadow(0 0 8px var(--color-primary))
          drop-shadow(0 0 20px rgba(6, 182, 212, 0.3));
      }

      .brand-name {
        font-size: 26px;
        font-weight: 700;
        letter-spacing: -0.5px;
        color: var(--text-primary);
      }

      .brand-ai {
        color: var(--color-primary);
        margin-left: 6px;
        font-weight: 600;
      }

      .subtitle {
        color: var(--text-dimmed);
        font-size: 14px;
        text-align: center;
        margin-bottom: 32px;
      }

      /* ── Form ── */
      .form {
        width: 100%;
        display: flex;
        flex-direction: column;
        gap: 16px;
      }

      .field {
        display: flex;
        flex-direction: column;
      }

      .field input,
      .password-field input {
        width: 100%;
        height: 48px;
        padding: 0 16px;
        background: var(--bg-surface);
        border: 1px solid var(--bg-border);
        border-radius: 10px;
        color: var(--text-secondary);
        font-size: 14px;
        outline: none;
        transition: border-color 0.2s;
      }

      .field input::placeholder,
      .password-field input::placeholder {
        color: var(--text-dimmed);
      }

      .field input:focus,
      .password-field input:focus {
        border-color: var(--color-primary);
      }

      .code-input {
        font-size: 24px !important;
        font-weight: 700;
        letter-spacing: 8px;
        text-align: center;
      }

      .code-input::placeholder {
        letter-spacing: 8px;
      }

      .password-field {
        position: relative;
      }

      .password-field input {
        padding-right: 44px;
      }

      .toggle-pw {
        position: absolute;
        right: 4px;
        top: 50%;
        transform: translateY(-50%);
        width: 36px;
        height: 36px;
        display: flex;
        align-items: center;
        justify-content: center;
        border: none;
        background: none;
        color: var(--text-dimmed);
        cursor: pointer;
        border-radius: 8px;
        transition: color 0.15s;
      }

      .toggle-pw:hover {
        color: var(--text-secondary);
      }

      .field-error {
        font-size: 12px;
        color: var(--color-error);
        margin-top: 6px;
        padding-left: 2px;
      }

      /* ── Button ── */
      .action-btn {
        width: 100%;
        height: 48px;
        margin-top: 8px;
        border: none;
        border-radius: 10px;
        background: var(--color-primary);
        color: #fff;
        font-size: 15px;
        font-weight: 600;
        cursor: pointer;
        transition: opacity 0.2s;
      }

      .action-btn:hover:not(:disabled) {
        opacity: 0.9;
      }
      .action-btn:disabled {
        opacity: 0.5;
        cursor: not-allowed;
      }

      /* ── Back ── */
      .back-link {
        margin-top: 28px;
        font-size: 13px;
        color: var(--text-dimmed);
        display: inline-flex;
        align-items: center;
        gap: 4px;
        transition: color 0.15s;
      }

      .back-link:hover {
        color: var(--color-primary);
      }
    `,
  ],
})
export class ResetPasswordComponent {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private snackBar = inject(MatSnackBar);
  private router = inject(Router);

  readonly hidePassword = signal(true);
  readonly hideConfirm = signal(true);
  readonly isLoading = signal(false);

  resetForm: FormGroup = this.fb.group(
    {
      code: ['', [Validators.required, Validators.pattern(/^\d{6}$/)]],
      password: ['', [Validators.required, Validators.minLength(8)]],
      passwordConfirm: ['', [Validators.required]],
    },
    { validators: this.passwordMatchValidator },
  );

  private passwordMatchValidator(group: AbstractControl) {
    const pass = group.get('password')?.value;
    const confirm = group.get('passwordConfirm')?.value;
    if (pass !== confirm) {
      group.get('passwordConfirm')?.setErrors({ passwordMismatch: true });
    }
    return null;
  }

  onSubmit(): void {
    if (this.resetForm.invalid) {
      this.resetForm.markAllAsTouched();
      return;
    }

    this.isLoading.set(true);
    const { code, password, passwordConfirm } = this.resetForm.value;

    this.authService.resetPassword(code, password, passwordConfirm).subscribe({
      next: () => {
        this.isLoading.set(false);
        this.snackBar.open('Contraseña actualizada correctamente', 'OK', {
          duration: 3000,
          panelClass: ['snackbar-success'],
        });
        this.router.navigate(['/auth/login']);
      },
      error: (err: { error?: { detail?: string } }) => {
        this.isLoading.set(false);
        const message = err.error?.detail ?? 'Error al cambiar la contraseña';
        this.snackBar.open(message, 'Cerrar', {
          duration: 5000,
          panelClass: ['snackbar-error'],
        });
      },
    });
  }
}
