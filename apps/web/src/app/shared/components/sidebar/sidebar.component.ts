import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, NavigationEnd, Router } from '@angular/router';
import { filter } from 'rxjs';
import {
  LucideLayoutDashboard,
  LucideBookOpen,
  LucideShield,
  LucideTrophy,
  LucideUsers,
  LucideChevronDown,
  LucideChevronRight,
  LucideX,
  LucideDynamicIcon,
  LucideBarChart3,
  LucideCreditCard,
  LucideMegaphone,
  LucideTrendingUp,
  LucideSettings,
  LucideScrollText,
  LucideIconData,
} from '@lucide/angular';
import { SidebarService } from '../../../core/services/sidebar.service';

interface NavLink {
  label: string;
  icon: LucideIconData;
  route: string;
}

interface NavGroup {
  label: string;
  icon: LucideIconData;
  children: { label: string; route: string }[];
}

type NavItem = (NavLink & { type: 'link' }) | (NavGroup & { type: 'group' });

@Component({
  selector: 'app-sidebar',
  standalone: true,
  imports: [
    CommonModule,
    RouterModule,
    LucideDynamicIcon,
    LucideChevronDown,
    LucideChevronRight,
    LucideX,
  ],
  template: `
    <!-- Backdrop for mobile -->
    @if (sidebarService.isOpen()) {
      <div class="backdrop" (click)="sidebarService.close()"></div>
    }
    <aside
      class="sidebar"
      [class.open]="sidebarService.isOpen()"
      [class.collapsed]="sidebarService.collapsed()"
    >
      <div class="sidebar-header-mobile">
        <a
          class="sidebar-brand-link"
          routerLink="/admin/dashboard"
          (click)="sidebarService.close()"
        >
          <img src="iconopiano.svg" alt="Aliento Andino" class="sidebar-logo" />
          <span class="sidebar-brand-text">Aliento Andino</span>
        </a>
        <button class="close-btn" (click)="sidebarService.close()">
          <svg lucideX [size]="20"></svg>
        </button>
      </div>

      <nav class="sidebar-nav">
        @for (item of navItems; track item.label) {
          @if (item.type === 'link') {
            <a
              class="nav-item"
              [routerLink]="item.route"
              routerLinkActive="active"
              [routerLinkActiveOptions]="{ exact: item.route === '/admin/dashboard' }"
              [title]="sidebarService.collapsed() ? item.label : ''"
            >
              <svg [lucideIcon]="item.icon" [size]="20"></svg>
              @if (!sidebarService.collapsed() || sidebarService.isOpen()) {
                <span>{{ item.label }}</span>
              }
            </a>
          } @else {
            <div class="nav-group">
              @if (sidebarService.collapsed() && !sidebarService.isOpen()) {
                <a
                  class="nav-item"
                  [routerLink]="item.children[0].route"
                  routerLinkActive="active"
                  [title]="item.label"
                >
                  <svg [lucideIcon]="item.icon" [size]="20"></svg>
                </a>
              } @else {
                <button
                  class="nav-item group-toggle"
                  [class.expanded]="expandedGroups().has(item.label)"
                  (click)="toggleGroup(item.label)"
                >
                  <svg [lucideIcon]="item.icon" [size]="20"></svg>
                  <span>{{ item.label }}</span>
                  @if (expandedGroups().has(item.label)) {
                    <svg lucideChevronDown [size]="16" class="chevron"></svg>
                  } @else {
                    <svg lucideChevronRight [size]="16" class="chevron"></svg>
                  }
                </button>
                @if (expandedGroups().has(item.label)) {
                  <div class="nav-children">
                    @for (child of item.children; track child.route) {
                      <a class="nav-child" [routerLink]="child.route" routerLinkActive="active">
                        {{ child.label }}
                      </a>
                    }
                  </div>
                }
              }
            </div>
          }
        }
      </nav>
    </aside>
  `,
  styles: [
    `
      :host {
        display: contents;
      }

      .backdrop {
        display: none;
      }

      .sidebar {
        width: 260px;
        min-width: 260px;
        height: 100vh;
        background: var(--bg-body);
        display: flex;
        flex-direction: column;
        overflow-y: auto;
        overflow-x: hidden;
        transition:
          width 0.25s ease,
          min-width 0.25s ease;
      }

      .sidebar.collapsed {
        width: 68px;
        min-width: 68px;
      }

      .sidebar-header-mobile {
        display: none;
      }

      .sidebar-header {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 16px 14px;
        white-space: nowrap;
        overflow: hidden;
        height: 56px;
        min-height: 56px;
      }

      .sidebar.collapsed .sidebar-header {
        justify-content: center;
        padding: 16px 0;
      }

      .logo-icon {
        width: 28px;
        height: 28px;
        filter: drop-shadow(0 0 2px var(--color-primary)) drop-shadow(0 0 3px var(--color-primary));
      }

      .hamburger-btn {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 36px;
        height: 36px;
        min-width: 36px;
        border: none;
        background: none;
        color: var(--text-muted);
        cursor: pointer;
        border-radius: 8px;
        transition:
          color 0.15s,
          background 0.15s;
      }

      .hamburger-btn:hover {
        color: var(--text-secondary);
        background: var(--bg-hover);
      }

      .close-btn {
        display: none;
        margin-left: auto;
        background: none;
        border: none;
        color: var(--text-muted);
        cursor: pointer;
        padding: 4px;
        border-radius: 6px;
      }

      .close-btn:hover {
        color: var(--text-secondary);
        background: var(--bg-hover);
      }

      .logo-text {
        font-size: 17px;
        font-weight: 700;
        color: var(--text-primary);
        letter-spacing: -0.3px;
      }

      .sidebar-nav {
        flex: 1;
        padding: 12px 0;
        display: flex;
        flex-direction: column;
        gap: 2px;
      }

      .nav-item {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 10px 20px;
        color: var(--text-muted);
        text-decoration: none;
        font-size: 14px;
        font-weight: 500;
        border: none;
        background: none;
        width: 100%;
        cursor: pointer;
        transition:
          color 0.15s,
          background 0.15s;
        border-left: 3px solid transparent;
        white-space: nowrap;
        overflow: hidden;
      }

      .sidebar.collapsed .nav-item {
        justify-content: center;
        padding: 10px 0;
        border-left: none;
      }

      .nav-item:hover {
        color: var(--text-secondary);
        background: var(--color-primary-hover);
      }

      .sidebar.collapsed .nav-item:hover,
      .sidebar.collapsed .group-toggle.expanded {
        background: none;
      }

      .nav-item.active {
        color: var(--color-primary);
        border-left-color: var(--color-primary);
      }

      .sidebar.collapsed .nav-item.active {
        border-left-color: transparent;
      }

      .group-toggle {
        font-family: 'Inter', 'Segoe UI', Roboto, sans-serif;
      }

      .group-toggle .chevron {
        margin-left: auto;
        opacity: 0.5;
      }

      .group-toggle.expanded {
        color: var(--text-secondary);
      }

      .nav-children {
        display: flex;
        flex-direction: column;
        gap: 1px;
      }

      .nav-child {
        display: block;
        padding: 8px 20px 8px 56px;
        color: var(--text-dimmed);
        text-decoration: none;
        font-size: 13px;
        font-weight: 500;
        transition:
          color 0.15s,
          background 0.15s;
        border-left: 3px solid transparent;
      }

      .nav-child:hover {
        color: var(--text-tertiary);
        background: rgba(6, 182, 212, 0.04);
      }

      .nav-child.active {
        color: var(--color-primary);
        background: rgba(6, 182, 212, 0.08);
        border-left-color: var(--color-primary);
      }

      /* Collapsed popover for groups */
      .nav-group {
        position: relative;
      }

      .nav-popover {
        position: absolute;
        left: 68px;
        top: 0;
        min-width: 180px;
        background: var(--bg-card);
        border: 1px solid var(--border-default);
        border-radius: 8px;
        padding: 8px 0;
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
        z-index: 200;
      }

      .popover-title {
        padding: 6px 16px 8px;
        font-size: 12px;
        font-weight: 600;
        color: var(--text-muted);
        text-transform: uppercase;
        letter-spacing: 0.5px;
      }

      .popover-link {
        display: block;
        padding: 7px 16px;
        color: var(--text-dimmed);
        text-decoration: none;
        font-size: 13px;
        font-weight: 500;
        transition:
          color 0.15s,
          background 0.15s;
      }

      .popover-link:hover {
        color: var(--text-secondary);
        background: var(--color-primary-hover);
      }

      .popover-link.active {
        color: var(--color-primary);
      }

      @media (max-width: 768px) {
        .backdrop {
          display: block;
          position: fixed;
          inset: 0;
          background: rgba(0, 0, 0, 0.5);
          z-index: 99;
        }

        .sidebar-header-mobile {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 12px 14px;
        }

        .sidebar-brand-link {
          display: flex;
          align-items: center;
          gap: 10px;
          text-decoration: none;
          color: var(--text-primary);
        }

        .sidebar-logo {
          width: 28px;
          height: 28px;
          filter: drop-shadow(0 0 2px var(--color-primary))
            drop-shadow(0 0 3px var(--color-primary));
        }

        .sidebar-brand-text {
          font-size: 1rem;
          font-weight: 600;
          letter-spacing: -0.01em;
        }

        .sidebar {
          position: fixed;
          left: 0;
          top: 0;
          z-index: 100;
          transform: translateX(-100%);
          transition: transform 0.25s ease;
          background: var(--bg-body);
          box-shadow: 4px 0 24px rgba(0, 0, 0, 0.3);
          width: 260px;
          min-width: 260px;
        }

        .sidebar.collapsed {
          width: 260px;
          min-width: 260px;
        }

        .sidebar.open {
          transform: translateX(0);
        }

        .sidebar.collapsed .nav-item {
          justify-content: flex-start;
          padding: 10px 20px;
          border-left: 3px solid transparent;
        }

        .sidebar.collapsed .sidebar-header {
          justify-content: flex-start;
          padding: 16px 14px;
        }

        .hamburger-btn {
          display: none;
        }

        .close-btn {
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .nav-popover {
          display: none;
        }
      }
    `,
  ],
})
export class SidebarComponent {
  readonly sidebarService = inject(SidebarService);
  private readonly router = inject(Router);
  readonly expandedGroups = signal<Set<string>>(new Set());

  constructor() {
    this.router.events.pipe(filter((e) => e instanceof NavigationEnd)).subscribe(() => {
      this.sidebarService.close();
    });
  }

  readonly dashboardIcon = LucideLayoutDashboard;
  readonly usersIcon = LucideUsers;
  readonly chevronDown = LucideChevronDown;
  readonly chevronRight = LucideChevronRight;

  readonly navItems: NavItem[] = [
    {
      type: 'link',
      label: 'Dashboard',
      icon: LucideLayoutDashboard,
      route: '/admin/dashboard',
    },
    {
      type: 'group',
      label: 'Lecciones',
      icon: LucideBookOpen,
      children: [
        { label: 'Resumen', route: '/admin/lessons/dashboard' },
        { label: 'Categorías', route: '/admin/lessons/categories' },
        { label: 'Lista', route: '/admin/lessons/list' },
      ],
    },
    {
      type: 'group',
      label: 'Moderación',
      icon: LucideShield,
      children: [
        { label: 'Reportes', route: '/admin/moderation/reports' },
        { label: 'Posts reportados', route: '/admin/moderation/reported-posts' },
        { label: 'Usuarios baneados', route: '/admin/moderation/banned-users' },
        { label: 'Estadísticas', route: '/admin/moderation/stats' },
      ],
    },
    {
      type: 'group',
      label: 'Rankings',
      icon: LucideTrophy,
      children: [
        { label: 'Resumen', route: '/admin/rankings/dashboard' },
        { label: 'Logros', route: '/admin/rankings/achievements' },
        { label: 'Leaderboard', route: '/admin/rankings/leaderboard' },
      ],
    },
    {
      type: 'link',
      label: 'Usuarios',
      icon: LucideUsers,
      route: '/admin/users',
    },
    {
      type: 'link',
      label: 'Suscripciones',
      icon: LucideCreditCard,
      route: '/admin/subscriptions',
    },
    {
      type: 'link',
      label: 'Anuncios',
      icon: LucideMegaphone,
      route: '/admin/announcements',
    },
    {
      type: 'link',
      label: 'Negocio',
      icon: LucideTrendingUp,
      route: '/admin/business',
    },
    {
      type: 'link',
      label: 'Reportes',
      icon: LucideBarChart3,
      route: '/admin/reports',
    },
    {
      type: 'link',
      label: 'Configuración',
      icon: LucideSettings,
      route: '/admin/config',
    },
    {
      type: 'link',
      label: 'Auditoría',
      icon: LucideScrollText,
      route: '/admin/audit',
    },
  ];

  toggleGroup(label: string): void {
    const current = new Set(this.expandedGroups());
    if (current.has(label)) {
      current.delete(label);
    } else {
      current.add(label);
    }
    this.expandedGroups.set(current);
  }

  isExpanded(label: string): boolean {
    return this.expandedGroups().has(label);
  }
}
