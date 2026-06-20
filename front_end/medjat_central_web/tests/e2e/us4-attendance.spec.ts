import { test, expect } from "@playwright/test";

/**
 * US4 Independent Test (T060):
 *  - record manual attendance + note → persists
 *  - export day → file
 *  - empty export → message
 *
 * Runs against a real dev server with a seeded tenant. Skipped by default until
 * seed credentials are provided.
 */
test.describe("US4 — attendance", () => {
  test.skip("record manual attendance and add a note (SC-004 < 1 min)", async ({
    page,
  }) => {
    await page.goto("/attendance");
    await page.getByRole("button", { name: /manual record|تسجيل يدوي/i }).click();
    await page.getByLabel(/employee|موظف/i).fill("1");
    await page.getByLabel(/status|الحالة/i).click();
    await page.getByRole("option", { name: /present|حاضر/i }).click();
    await page.getByRole("button", { name: /save|حفظ/i }).click();
    await expect(page.getByText(/success|تم بنجاح/i)).toBeVisible();
  });

  test.skip("export day produces a file", async ({ page }) => {
    await page.goto("/attendance");
    const download = page.waitForEvent("download");
    await page.getByRole("button", { name: /pdf/i }).click();
    expect((await download).suggestedFilename()).toMatch(/\.(pdf|xlsx)$/i);
  });

  test.skip("empty day shows no-records message", async ({ page }) => {
    await page.goto("/attendance");
    await page.getByLabel(/date|التاريخ/i).fill("2000-01-01");
    await expect(page.getByText(/no records|لا توجد سجلات/i)).toBeVisible();
  });
});
