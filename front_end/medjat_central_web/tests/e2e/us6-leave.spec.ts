import { test, expect } from "@playwright/test";

/**
 * US6 Independent Test (T075):
 *  - approve/reject leave → status + dashboard count update (SC-004 < 1 min)
 *  - create leave
 *  - act on a break request
 *
 * Runs against a real dev server with a seeded tenant. Skipped by default.
 */
test.describe("US6 — leave & breaks", () => {
  test.skip("approve a pending leave", async ({ page }) => {
    await page.goto("/leaves");
    await page.getByRole("button", { name: /^(approve|اعتماد)$/i }).first().click();
    await expect(page.getByText(/success|تم بنجاح/i)).toBeVisible();
  });

  test.skip("create a leave", async ({ page }) => {
    await page.goto("/leaves");
    await page.getByRole("button", { name: /new leave|إجازة جديدة/i }).click();
    await page.getByLabel(/employee|موظف/i).fill("1");
    await page.getByRole("button", { name: /^(create|إنشاء)$/i }).click();
    await expect(page.getByText(/success|تم بنجاح/i)).toBeVisible();
  });

  test.skip("act on a break request", async ({ page }) => {
    await page.goto("/breaks");
    await page.getByRole("button", { name: /^(approve|اعتماد)$/i }).first().click();
    await expect(page.getByText(/success|تم بنجاح/i)).toBeVisible();
  });
});
