import { test, expect } from "@playwright/test";
import { login } from "./auth";

/**
 * US5 Independent Test (T069):
 *  - open period → totals rollup
 *  - bulk adjust selected
 *  - payslip export
 *  - loan affects deductions (SC-004: view payroll < 1 min)
 *
 * Runs against a real dev server with a seeded tenant. Skipped by default.
 */
test.describe("US5 — payroll, loans & adjustments", () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
  });
  test.skip("payroll period totals render (SC-004 < 1 min)", async ({ page }) => {
    await page.goto("/payroll");
    await expect(page.getByText(/net|الصافي/i)).toBeVisible();
  });

  test.skip("bulk adjust selected slips", async ({ page }) => {
    await page.goto("/payroll");
    await page.getByRole("checkbox").nth(1).click();
    await page.getByRole("button", { name: /approve bulk|اعتماد متعدد/i }).click();
    await expect(page.getByText(/success|تم بنجاح/i)).toBeVisible();
  });

  test.skip("payslip export produces a file", async ({ page }) => {
    await page.goto("/payroll");
    const download = page.waitForEvent("download");
    await page.getByRole("button", { name: /excel/i }).first().click();
    expect((await download).suggestedFilename()).toMatch(/\.xlsx$/i);
  });

  test.skip("create a loan", async ({ page }) => {
    await page.goto("/loans");
    await page.getByRole("button", { name: /new loan|سلفة جديدة/i }).click();
    await page.getByLabel(/employee|موظف/i).fill("1");
    await page.getByLabel(/principal|المبلغ الأساسي/i).fill("2000");
    await page.getByLabel(/installment|القسط/i).fill("200");
    await page.getByRole("button", { name: /^(create|إنشاء)$/i }).click();
    await expect(page.getByText(/success|تم بنجاح/i)).toBeVisible();
  });
});
