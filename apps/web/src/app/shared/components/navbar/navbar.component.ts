import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { LucideUser, LucideSun, LucideMoon, LucideMenu } from '@lucide/angular';

import { AuthService } from '../../../core/services/auth.service';
import { ThemeService } from '../../../core/services/theme.service';
import { SidebarService } from '../../../core/services/sidebar.service';

@Component({
  selector: 'app-navbar',
  standalone: true,
  imports: [CommonModule, RouterModule, LucideUser, LucideSun, LucideMoon, LucideMenu],
  template: `
    <header class="navbar">
      <div class="navbar-left">
        <button class="icon-btn" (click)="sidebarService.toggleCollapse()">
          <svg lucideMenu [size]="20"></svg>
        </button>
        <a class="navbar-brand-link" routerLink="/admin/dashboard">
          <img src="logo.svg" alt="Aliento Andino" class="navbar-logo" />
          <span class="navbar-brand">Aliento Andino</span>
        </a>
      </div>
      <div class="navbar-right">
        <button class="icon-btn" (click)="themeService.toggle()" title="Cambiar tema">
          @if (themeService.theme() === 'dark') {
            <svg lucideSun [size]="18"></svg>
          } @else {
            <svg lucideMoon [size]="18"></svg>
          }
        </button>
        <a class="user-info" routerLink="/admin/profile" title="Mi perfil">
          <svg lucideUser [size]="18"></svg>
          <span class="user-name">{{ authService.currentUser()?.full_name }}</span>
        </a>
      </div>
    </header>
  `,
  styles: [
    `
      .navbar {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 0 32px 0 16px;
        height: 56px;
        min-height: 56px;
        background: var(--bg-body);
        border-bottom: 1px solid var(--border-color);
      }

      .navbar-logo {
        width: 30px;
        height: 30px;
        filter: drop-shadow(0 0 2px var(--color-primary)) drop-shadow(0 0 3px var(--color-primary));
      }

      .navbar-brand-link {
        display: flex;
        align-items: center;
        gap: 8px;
        text-decoration: none;
        cursor: pointer;
      }

      .navbar-brand {
        font-size: 16px;
        font-weight: 600;
        color: var(--text-secondary);
      }

      .navbar-left {
        display: flex;
        align-items: center;
        gap: 8px;
      }

      .menu-btn {
        display: none;
      }

      .navbar-right {
        display: flex;
        align-items: center;
        gap: 12px;
      }

      .user-info {
        display: flex;
        align-items: center;
        gap: 8px;
        color: var(--text-muted);
        font-size: 14px;
        text-decoration: none;
        border-radius: 8px;
        padding: 6px 10px;
        transition:
          color 0.15s,
          background 0.15s;
      }

      .user-info:hover {
        color: var(--text-secondary);
        background: var(--bg-hover);
      }

      .user-name {
        font-weight: 500;
      }

      .icon-btn {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 36px;
        height: 36px;
        border: none;
        background: none;
        color: var(--text-dimmed);
        cursor: pointer;
        border-radius: 8px;
        transition:
          color 0.15s,
          background 0.15s;
      }

      .icon-btn:hover {
        color: var(--text-secondary);
        background: var(--bg-hover);
      }

      .logout-btn:hover {
        color: var(--color-error);
        background: var(--color-error-subtle);
      }

      .menu-btn {
        display: none;
      }

      @media (max-width: 768px) {
        .navbar {
          padding: 0 12px;
        }

        .navbar-brand {
          font-size: 13px;
        }

        .user-name {
          display: none;
        }

        .navbar-right {
          gap: 4px;
        }

        .user-info {
          padding: 6px;
        }

        .menu-btn {
          display: flex;
        }
      }
    `,
  ],
})
export class NavbarComponent {
  readonly authService = inject(AuthService);
  readonly themeService = inject(ThemeService);
  readonly sidebarService = inject(SidebarService);

  logout(): void {
    this.authService.logout();
  }
}
