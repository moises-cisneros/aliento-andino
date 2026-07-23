import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';

import { SidebarComponent } from '../sidebar/sidebar.component';
import { NavbarComponent } from '../navbar/navbar.component';

@Component({
  selector: 'app-admin-layout',
  standalone: true,
  imports: [RouterOutlet, SidebarComponent, NavbarComponent],
  template: `
    <div class="admin-layout">
      <app-navbar />
      <div class="body-area">
        <app-sidebar />
        <main class="content">
          <router-outlet />
        </main>
      </div>
    </div>
  `,
  styles: [`
    .admin-layout {
      display: flex;
      flex-direction: column;
      height: 100vh;
      overflow: hidden;
    }

    .body-area {
      flex: 1;
      display: flex;
      overflow: hidden;
    }

    .content {
      flex: 1;
      overflow-y: auto;
      padding: 28px 32px;
      min-width: 0;
    }

    @media (max-width: 768px) {
      .content {
        padding: 16px;
      }
    }
  `],
})
export class AdminLayoutComponent {}
