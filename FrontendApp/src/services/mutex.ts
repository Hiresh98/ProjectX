/**
 * Minimal promise-based mutex (no external dependency). Used to serialize
 * token-refresh so concurrent 401s don't trigger multiple refresh calls.
 */
export class Mutex {
  private locked = false;
  private waiters: Array<() => void> = [];

  isLocked(): boolean {
    return this.locked;
  }

  async acquire(): Promise<() => void> {
    while (this.locked) {
      await new Promise<void>((resolve) => this.waiters.push(resolve));
    }
    this.locked = true;
    return () => this.release();
  }

  /** Resolves immediately if unlocked; otherwise waits for release. */
  async waitForUnlock(): Promise<void> {
    if (!this.locked) return;
    await new Promise<void>((resolve) => this.waiters.push(resolve));
  }

  private release(): void {
    this.locked = false;
    const next = this.waiters;
    this.waiters = [];
    next.forEach((resolve) => resolve());
  }
}
