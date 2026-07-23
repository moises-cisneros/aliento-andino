import { Injectable, signal } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class SidebarService {
  /** Mobile overlay state */
  readonly isOpen = signal(false);
  /** Desktop collapsed state (icon-only) */
  readonly collapsed = signal(true);

  toggle(): void {
    this.isOpen.update(v => !v);
  }

  open(): void {
    this.isOpen.set(true);
  }

  close(): void {
    this.isOpen.set(false);
  }

  toggleCollapse(): void {
    if (window.innerWidth <= 768) {
      this.isOpen.update(v => !v);
    } else {
      this.collapsed.update(v => !v);
    }
  }
}
