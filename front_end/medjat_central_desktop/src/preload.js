'use strict';

/**
 * The bridge between the web app and the desktop shell.
 *
 * Everything exposed here is callable from the page as `window.medjat.*`. The web
 * app should feature-detect with `window.medjat?.isDesktop` so the same deploy keeps
 * working in a plain browser, where this object simply does not exist.
 *
 * Native capabilities the browser cannot reach — reading a ZKTeco terminal over the
 * LAN, silent printing, writing to a fixed export folder — get added as methods here
 * plus an `ipcMain.handle` in `main.js`. Adding one means shipping a new installer;
 * the UI driving it stays in the web app and keeps updating on its own.
 */

const { contextBridge, ipcRenderer } = require('electron');

// Sign-in popups on the Firebase/Google/Apple domains load with this same preload.
// Only the app itself (and the bundled offline page) may see the bridge.
const originArg = process.argv.find((arg) => arg.startsWith('--medjat-app-origin='));
const appOrigin = originArg ? originArg.slice('--medjat-app-origin='.length) : null;
const isTrustedPage = location.protocol === 'file:' || location.origin === appOrigin;

if (isTrustedPage) {
  contextBridge.exposeInMainWorld('medjat', {
    isDesktop: true,
    retry: () => ipcRenderer.invoke('app:retry'),
    info: () => ipcRenderer.invoke('app:info'),
    // Passkeys cannot be answered in this window; the real browser can, and
    // returns the session over medjat://auth.
    signInWithBrowser: () => ipcRenderer.invoke('auth:browser'),
  });
}
