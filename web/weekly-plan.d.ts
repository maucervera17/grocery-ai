export function measure(
  quantity: number,
  unit: string,
): { kind: string; amount: number } | null;
export function optimizeWeekly(rows: any[], options?: any): any;
export function recommendWeekly(rows: any[], options?: any): any;
export function weeklyExport(plan: any): string;
export function recordWeeklyPurchase(
  snapshot: any,
  purchases: any[],
  paidCents: number,
  date?: string,
): any;

export function soldByWeight(listing: any): boolean;

export function qualifiersMatch(name: string, query?: string): boolean;
