/**
 * Unit tests for the browser-attendance employee surface.
 *
 * Placed in `tests/unit/` rather than the `src/features/.../__tests__/` folder
 * the task named, because `vitest.config.ts` only collects
 * `tests/{unit,component,contract}/**` — a suite under `src/` would sit in the
 * repository looking like coverage while never running once.
 *
 * The PIN rules are tested against the *server's* rules deliberately. The
 * browser copy in `pinRejectReason` exists only to answer instantly; the control
 * is `EmployeeWebCredentialModel::rejectReason`. If the two drift, an employee
 * is told their PIN is fine and then refused on submit, which reads as a broken
 * product rather than a rejected choice — so the cases below are the ones the
 * PHP enumerates, and both sides must agree on each.
 */

import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { pinRejectReason, pinSchema, phoneSchema } from "@/features/employee-attendance/api";
import { getDeviceId } from "@/features/employee-attendance/device-id";

describe("pinRejectReason", () => {
  it("requires exactly six digits", () => {
    expect(pinRejectReason("12345")).toBe("length");
    expect(pinRejectReason("1234567")).toBe("length");
    expect(pinRejectReason("")).toBe("length");
    expect(pinRejectReason("12345a")).toBe("length");
    expect(pinRejectReason("١٢٣٤٥٦")).toBe("length"); // Arabic-Indic digits
  });

  it("rejects one repeated digit", () => {
    expect(pinRejectReason("000000")).toBe("repeated");
    expect(pinRejectReason("777777")).toBe("repeated");
  });

  it("rejects runs in either direction, not just the famous ones", () => {
    expect(pinRejectReason("123456")).toBe("sequence");
    expect(pinRejectReason("987654")).toBe("sequence");
    // The case a hand-written list of "obvious" PINs always misses: a run that
    // starts one digit over.
    expect(pinRejectReason("234567")).toBe("sequence");
    expect(pinRejectReason("456789")).toBe("sequence");
  });

  it("rejects a short block repeated to fill the length", () => {
    expect(pinRejectReason("121212")).toBe("pattern");
    expect(pinRejectReason("838383")).toBe("pattern");
    expect(pinRejectReason("246246")).toBe("pattern");
  });

  it("rejects the common ones the server bans", () => {
    // 112233 is on the server's list rather than caught structurally, so it is
    // the case most likely to drift between the two implementations.
    expect(pinRejectReason("112233")).toBe("common");
    expect(pinRejectReason("159753")).toBe("common");
    expect(pinRejectReason("102030")).toBe("common");
    // On the banned list, but the structural block-repeat rule reaches it first
    // in both implementations ("69" × 3). Asserted as rejected rather than as a
    // particular reason: the reason is a message, the rejection is the control.
    expect(pinRejectReason("696969")).not.toBeNull();
  });

  it("accepts an ordinary unremarkable PIN", () => {
    expect(pinRejectReason("284917")).toBeNull();
    expect(pinRejectReason("903581")).toBeNull();
  });

  it("does not judge the phone rule, which needs data the page lacks", () => {
    // The server rejects a PIN contained in the employee's phone number. The
    // browser cannot see it, so this must pass here and be caught on submit —
    // silently guessing would produce a rejection the employee cannot act on.
    expect(pinRejectReason("409407")).toBeNull();
  });

  it("pinSchema agrees with pinRejectReason", () => {
    expect(pinSchema.safeParse("284917").success).toBe(true);
    expect(pinSchema.safeParse("123456").success).toBe(false);
    expect(pinSchema.safeParse("12345").success).toBe(false);
  });
});

describe("phoneSchema", () => {
  it("trims and requires something plausible", () => {
    expect(phoneSchema.safeParse("  +201234567890 ").success).toBe(true);
    expect(phoneSchema.safeParse("12345").success).toBe(false);
    expect(phoneSchema.safeParse("").success).toBe(false);
  });
});

describe("getDeviceId", () => {
  beforeEach(() => {
    // jsdom keeps cookies between tests; clear the one under test.
    document.cookie = "medjat_emp_device=; path=/; max-age=0";
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("creates an id and persists it in a cookie", () => {
    const id = getDeviceId();
    expect(id).toBeTruthy();
    expect(document.cookie).toContain("medjat_emp_device=");
    expect(document.cookie).toContain(encodeURIComponent(id));
  });

  it("returns the same id on the next call", () => {
    const first = getDeviceId();
    const second = getDeviceId();
    expect(second).toBe(first);
  });

  it("falls back to getRandomValues when randomUUID is missing", () => {
    // Older Safari on iOS. The fallback must still be cryptographic: ids that
    // collide would put two unrelated employees on one "device" and raise a
    // false shared-device flag against both of them.
    const bytes = crypto.getRandomValues.bind(crypto);
    vi.stubGlobal("crypto", { getRandomValues: bytes });

    const id = getDeviceId();
    expect(id).toMatch(/^[0-9a-f]{32}$/);
  });

  it("marks itself untrusted rather than using Math.random", () => {
    vi.stubGlobal("crypto", {});
    const id = getDeviceId();
    expect(id.startsWith("nocrypto-")).toBe(true);
  });
});
