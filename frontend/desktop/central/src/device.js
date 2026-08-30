'use strict';

/**
 * Reads attendance records straight off a ZKTeco terminal over the local network.
 *
 * This is the one thing the browser genuinely cannot do — a web page has no way
 * to open a TCP socket to 192.168.x.x — and so it is the reason the desktop
 * shell exists beyond being a window.
 *
 * What it deliberately does NOT do is invent a second ingestion path. The rows
 * come back as plain `user_id,punched_at` CSV and go to
 * `app/devices/import_punches.php`, the same vendor-neutral endpoint the web
 * page already uses for a USB export. Employee linking, direction, clock sanity
 * and repeat-tap suppression are therefore identical to a punch that arrived
 * over ADMS — none of that logic is duplicated here.
 *
 * Scope and limits, stated honestly:
 *   • The machine must be on the same LAN as the terminal. A manager at head
 *     office cannot read a branch device; that is what the ADMS push is for.
 *   • ZKTeco's port-4370 protocol varies by model and firmware. Some devices
 *     want a comm key; some newer ones disable the port entirely.
 *   • Reading does not clear the device, so importing twice is safe — the
 *     server suppresses duplicates.
 */

const net = require('node:net');

const DEFAULT_PORT = 4370;
const CONNECT_TIMEOUT_MS = 6000;
const READ_TIMEOUT_MS = 60000;
// Matches IMPORT_MAX_ROWS in app/devices/import_punches.php; a bigger read would
// only be rejected server-side after the user waited for it.
const MAX_ROWS = 20000;

/**
 * The renderer is remote web content, so it does not get to name arbitrary hosts:
 * without this the shell would be an open proxy from the page into anything the
 * user's machine can reach. Terminals live on the LAN, so the LAN is all we allow.
 */
function isPrivateAddress(host) {
  if (net.isIPv4(host) !== 4 && !net.isIP(host)) return false;
  const parts = host.split('.').map(Number);
  if (parts.length !== 4 || parts.some((n) => !Number.isInteger(n) || n < 0 || n > 255)) {
    return false;
  }
  const [a, b] = parts;
  if (a === 10) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 192 && b === 168) return true;
  if (a === 169 && b === 254) return true; // link-local
  if (a === 127) return true; // a terminal emulator on this machine
  return false;
}

/**
 * The device reports wall-clock time as read off its own screen. Formatting from
 * the local components — rather than toISOString() — keeps that reading intact;
 * converting to UTC here would shift every punch by the machine's offset and the
 * server would then apply the tenant's timezone to an already-shifted value.
 */
function formatLocal(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  const pad = (n) => String(n).padStart(2, '0');
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  );
}

function withTimeout(promise, ms, label) {
  return Promise.race([
    promise,
    new Promise((_resolve, reject) =>
      setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms),
    ),
  ]);
}

/**
 * Connects, reads the attendance log, and always releases the terminal.
 *
 * @param {{ip: string, port?: number}} options
 * @returns {Promise<{device: object, rows: Array<{userId: string, at: string}>, csv: string, truncated: boolean}>}
 */
async function readAttendance({ ip, port = DEFAULT_PORT } = {}) {
  if (typeof ip !== 'string' || !isPrivateAddress(ip)) {
    throw new Error('عنوان الجهاز يجب أن يكون على الشبكة المحلية');
  }
  const devicePort = Number.isInteger(port) && port > 0 && port < 65536 ? port : DEFAULT_PORT;

  // Required lazily: a machine that never reads a terminal should not pay for
  // loading the protocol library at startup.
  const Zkteco = require('zkteco-js');
  const device = new Zkteco(ip, devicePort, CONNECT_TIMEOUT_MS, 4000);

  let info = {};
  let records = [];
  // The connect lives inside the same try as the read: a timed-out createSocket
  // leaves the socket open and retrying, which keeps the event loop alive long
  // after the caller has given up — one leaked connection per failed attempt.
  try {
    await withTimeout(device.createSocket(), CONNECT_TIMEOUT_MS, 'الاتصال بالجهاز');

    // Best-effort identity: useful in the UI to prove which box answered, but a
    // firmware that refuses any of these should not fail the whole read.
    for (const [key, method] of [
      ['name', 'getDeviceName'],
      ['serial', 'getSerialNumber'],
      ['firmware', 'getFirmware'],
      ['time', 'getTime'],
    ]) {
      try {
        info[key] = await withTimeout(device[method](), CONNECT_TIMEOUT_MS, key);
      } catch {
        info[key] = null;
      }
    }

    // Freeze the terminal for the duration so the log cannot shift underneath
    // the read; the finally block below always releases it again.
    try {
      await withTimeout(device.disableDevice(), CONNECT_TIMEOUT_MS, 'إيقاف الجهاز مؤقتاً');
    } catch {
      // Older firmware may not support it — reading without the lock is fine.
    }

    const result = await withTimeout(device.getAttendances(), READ_TIMEOUT_MS, 'قراءة السجلات');
    records = Array.isArray(result) ? result : (result?.data ?? []);
  } finally {
    try {
      await device.enableDevice();
    } catch {
      // Never connected, or firmware without the command — the disconnect below
      // is what actually matters.
    }
    try {
      await device.disconnect();
    } catch {
      // Same.
    }
    // disconnect() is a no-op when the handshake never completed, so the socket
    // that timed out is torn down by hand.
    for (const socket of [device.ztcp?.socket, device.zudp?.socket]) {
      try {
        socket?.destroy?.();
        socket?.close?.();
      } catch {
        // Already gone.
      }
    }
  }

  const truncated = records.length > MAX_ROWS;
  const rows = [];
  for (const record of truncated ? records.slice(0, MAX_ROWS) : records) {
    const at = formatLocal(record.record_time ?? record.recordTime ?? record.timestamp);
    const userId = String(record.user_id ?? record.userId ?? '').trim();
    if (!at || userId === '') continue;
    rows.push({ userId, at });
  }

  const csv = ['user_id,punched_at', ...rows.map((r) => `${r.userId},${r.at}`)].join('\n');

  return {
    device: {
      ip,
      port: devicePort,
      name: info.name ?? null,
      serial: info.serial ?? null,
      firmware: info.firmware ?? null,
      clock: info.time ? formatLocal(info.time) : null,
    },
    rows,
    csv,
    total: records.length,
    truncated,
  };
}

module.exports = { readAttendance, isPrivateAddress, formatLocal };
