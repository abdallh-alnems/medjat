import { test, expect } from "@playwright/test";

/**
 * US8 Independent Test (T087):
 *  - select report + period → produced
 *  - export → correctly formatted file
 *
 * Runs against a real dev server with a seeded tenant. Skipped by default.
 */
test.describe("US8 — reports & exports", () => {
  test.skip("generate an attendance report", async ({ page }) => {
    await page.goto("/reports/attendance");
    await page.getByRole("button", { name: /generate report|توليد التقرير/i }).click();
    await expect(page.locator("table")).toBeVisible();
  });

  test.skip("export report to excel", async ({ page }) => {
    await page.goto("/reports/payroll");
    await page.getByRole("button", { name: /generate report|توليد التقرير/i }).click();
    const download = page.waitForEvent("download");
    await page.getByRole("button", { name: /^excel$/i }).click();
    expect((await download).suggestedFilename()).toMatch(/\.xlsx$/i);
  });

  test.skip("documents report shows stats", async ({ page }) => {
    await page.goto("/reports/documents");
    await expect(page.getByText(/total|الإجمالي/i)).toBeVisible();
  });
});
