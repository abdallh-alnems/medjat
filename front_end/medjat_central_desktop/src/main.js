'use strict';

/**
 * Medjat Central — desktop shell.
 *
 * The window renders the live web app (app.medjatapp.com), so every `deploy-web.sh`
 * reaches installed copies without shipping a new installer. Anything the browser
 * cannot do — local network, file system, silent printing — belongs here in the main
 * process and is handed to the page through `src/preload.js`.
 */

const {
  app,
  BrowserWindow,
  Menu,
  Notification,
  session,
  shell,
  ipcMain,
} = require('electron');
const path = require('node:path');
const fs = require('node:fs');

const APP_URL = process.env.MEDJAT_URL || 'https://app.medjatapp.com';
const APP_ORIGIN = new URL(APP_URL).origin;
const IS_MAC = process.platform === 'darwin';

/**
 * Firebase sign-in runs as a popup on the auth domain and hands the credential back by
 * postMessage, falling back to a full-page redirect. Both leave the app origin, so these
 * hosts have to stay inside the app — bouncing them to the system browser breaks login.
 */
const AUTH_HOSTS = [
  'medjat.firebaseapp.com',
  'accounts.google.com',
  'accounts.youtube.com',
  'appleid.apple.com',
  'appleid.cdn-apple.com',
];

app.setName('Medjat Central');

let mainWindow = null;

// ---------------------------------------------------------------- window state

const stateFile = () => path.join(app.getPath('userData'), 'window-state.json');

function loadState() {
  const fallback = { width: 1360, height: 860, maximized: false };
  try {
    const saved = JSON.parse(fs.readFileSync(stateFile(), 'utf8'));
    if (!Number.isFinite(saved.width) || !Number.isFinite(saved.height)) return fallback;
    return { ...fallback, ...saved };
  } catch {
    return fallback;
  }
}

function saveState() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  const bounds = mainWindow.getNormalBounds();
  const state = { ...bounds, maximized: mainWindow.isMaximized() };
  try {
    fs.writeFileSync(stateFile(), JSON.stringify(state));
  } catch {
    // A window that cannot remember its size is not worth failing a launch over.
  }
}

// ---------------------------------------------------------------- navigation

function isInternal(url) {
  try {
    return new URL(url).origin === APP_ORIGIN;
  } catch {
    return false;
  }
}

function isAuthFlow(url) {
  try {
    const { protocol, hostname } = new URL(url);
    return protocol === 'https:' && AUTH_HOSTS.includes(hostname);
  } catch {
    return false;
  }
}

function showOffline(code) {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  mainWindow.loadFile(path.join(__dirname, 'offline.html'), {
    query: { code: String(code ?? ''), url: APP_URL },
  });
}

// ---------------------------------------------------------------- window

function createWindow() {
  const state = loadState();

  mainWindow = new BrowserWindow({
    x: state.x,
    y: state.y,
    width: state.width,
    height: state.height,
    minWidth: 1024,
    minHeight: 680,
    show: false,
    backgroundColor: '#F9FCFC',
    title: 'Medjat Central',
    autoHideMenuBar: !IS_MAC,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: false,
      // Sign-in popups inherit this preload; the bridge checks the origin against this
      // so it is never handed to Google's or Apple's pages.
      additionalArguments: [`--medjat-app-origin=${APP_ORIGIN}`],
    },
  });

  if (state.maximized) mainWindow.maximize();

  mainWindow.once('ready-to-show', () => mainWindow.show());

  let saveTimer = null;
  const queueSave = () => {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(saveState, 400);
  };
  mainWindow.on('resize', queueSave);
  mainWindow.on('move', queueSave);
  mainWindow.on('close', saveState);
  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  // Links to anywhere other than the app — or the sign-in flow — open in the real browser.
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (isInternal(url)) {
      return {
        action: 'allow',
        overrideBrowserWindowOptions: {
          backgroundColor: '#F9FCFC',
          autoHideMenuBar: !IS_MAC,
        },
      };
    }
    if (isAuthFlow(url)) {
      return {
        action: 'allow',
        overrideBrowserWindowOptions: {
          width: 520,
          height: 700,
          minimizable: false,
          maximizable: false,
          autoHideMenuBar: true,
        },
      };
    }
    shell.openExternal(url);
    return { action: 'deny' };
  });

  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (isInternal(url) || isAuthFlow(url) || url.startsWith('file://')) return;
    event.preventDefault();
    shell.openExternal(url);
  });

  // ERR_ABORTED (-3) is a navigation the page itself replaced — not a failure.
  mainWindow.webContents.on(
    'did-fail-load',
    (_event, errorCode, _desc, _validatedURL, isMainFrame) => {
      if (!isMainFrame || errorCode === -3) return;
      showOffline(errorCode);
    },
  );

  mainWindow.webContents.on('render-process-gone', () => {
    showOffline('render');
  });

  mainWindow.loadURL(APP_URL);
}

// ---------------------------------------------------------------- session

function configureSession() {
  const ses = session.defaultSession;

  // The page may legitimately ask for these; everything else is refused outright.
  const allowed = new Set([
    'clipboard-read',
    'clipboard-sanitized-write',
    'fullscreen',
    'geolocation',
    'media',
    'notifications',
  ]);

  ses.setPermissionRequestHandler((_wc, permission, callback) => {
    callback(allowed.has(permission));
  });

  ses.setPermissionCheckHandler((_wc, permission, origin) => {
    return allowed.has(permission) && (origin === APP_ORIGIN || origin === '');
  });

  // Payslips and exports are a core flow — tell the user where the file landed.
  ses.on('will-download', (_event, item) => {
    item.once('done', (_e, state) => {
      if (state !== 'completed' || !Notification.isSupported()) return;
      const file = item.getSavePath();
      const notification = new Notification({
        title: 'اكتمل التنزيل',
        body: path.basename(file),
      });
      notification.on('click', () => shell.showItemInFolder(file));
      notification.show();
    });
  });
}

// ---------------------------------------------------------------- menu

function buildMenu() {
  const template = [
    ...(IS_MAC
      ? [
          {
            label: 'Medjat Central',
            submenu: [
              { role: 'about', label: 'عن التطبيق' },
              { type: 'separator' },
              { role: 'hide', label: 'إخفاء' },
              { role: 'hideOthers', label: 'إخفاء الباقي' },
              { role: 'unhide', label: 'إظهار الكل' },
              { type: 'separator' },
              { role: 'quit', label: 'إنهاء' },
            ],
          },
        ]
      : []),
    {
      label: 'ملف',
      submenu: [
        {
          label: 'طباعة…',
          accelerator: 'CmdOrCtrl+P',
          click: () => mainWindow?.webContents.print(),
        },
        { type: 'separator' },
        IS_MAC ? { role: 'close', label: 'إغلاق النافذة' } : { role: 'quit', label: 'خروج' },
      ],
    },
    {
      label: 'تحرير',
      submenu: [
        { role: 'undo', label: 'تراجع' },
        { role: 'redo', label: 'إعادة' },
        { type: 'separator' },
        { role: 'cut', label: 'قص' },
        { role: 'copy', label: 'نسخ' },
        { role: 'paste', label: 'لصق' },
        { role: 'selectAll', label: 'تحديد الكل' },
      ],
    },
    {
      label: 'عرض',
      submenu: [
        {
          label: 'إعادة التحميل',
          accelerator: 'CmdOrCtrl+R',
          click: () => mainWindow?.loadURL(APP_URL),
        },
        { role: 'forceReload', label: 'إعادة تحميل كاملة' },
        { type: 'separator' },
        { role: 'resetZoom', label: 'حجم أصلي' },
        { role: 'zoomIn', label: 'تكبير' },
        { role: 'zoomOut', label: 'تصغير' },
        { type: 'separator' },
        { role: 'togglefullscreen', label: 'ملء الشاشة' },
        { type: 'separator' },
        { role: 'toggleDevTools', label: 'أدوات المطوّر' },
      ],
    },
    {
      label: 'نافذة',
      submenu: [
        { role: 'minimize', label: 'تصغير' },
        ...(IS_MAC ? [{ role: 'zoom', label: 'تكبير' }, { role: 'front', label: 'إحضار للأمام' }] : []),
      ],
    },
    {
      label: 'مساعدة',
      submenu: [
        {
          label: 'الدعم الفني',
          click: () => shell.openExternal('https://medjatapp.com/support.html'),
        },
        {
          label: 'فتح في المتصفح',
          click: () => shell.openExternal(APP_URL),
        },
      ],
    },
  ];

  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

// ---------------------------------------------------------------- lifecycle

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (!mainWindow) return;
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  });

  app.whenReady().then(() => {
    configureSession();
    buildMenu();
    createWindow();

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
  });

  app.on('window-all-closed', () => {
    if (!IS_MAC) app.quit();
  });
}

// ---------------------------------------------------------------- bridge

ipcMain.handle('app:retry', () => {
  mainWindow?.loadURL(APP_URL);
});

ipcMain.handle('app:info', () => ({
  version: app.getVersion(),
  electron: process.versions.electron,
  platform: process.platform,
  url: APP_URL,
}));
