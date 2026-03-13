const { app, BrowserWindow, Tray, Menu, ipcMain, nativeImage, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const http = require('http');

const isDev = !app.isPackaged;

// ── Config (stored in ~/Library/Application Support/Discord Image Dashboard/) ──

const USER_DATA_DIR = app.getPath('userData');
const APP_CONFIG_PATH = path.join(USER_DATA_DIR, 'config.json');

function readConfig() {
  try {
    return JSON.parse(fs.readFileSync(APP_CONFIG_PATH, 'utf8'));
  } catch {
    return {};
  }
}

function writeConfig(data) {
  fs.mkdirSync(USER_DATA_DIR, { recursive: true });
  fs.writeFileSync(APP_CONFIG_PATH, JSON.stringify(data, null, 2));
}

// ── Sub-repo path resolution ────────────────────────────────────────────────

function resolveSubrepo(name) {
  if (!isDev) {
    return path.join(process.resourcesPath, name);
  }
  // In dev: try post-merge layout first, then worktree layout
  const candidates = [
    path.join(__dirname, '..', name),              // post-merge: orchestrator/app/../name
    path.join(__dirname, '../../../..', name),     // worktree:   orchestrator/.claude/worktrees/xyz/app/../../../../name
  ];
  const found = candidates.find((p) => fs.existsSync(p));
  if (!found) {
    console.error(`[app] Could not find sub-repo: ${name}`);
    console.error('[app] Searched:', candidates);
  }
  return found || candidates[0];
}

const CLIENT_PATH = resolveSubrepo('discord-image-dashboard-client');
const BOT_PATH = resolveSubrepo('discord-image-dashboard-bot');

console.log('[app] CLIENT_PATH:', CLIENT_PATH);
console.log('[app] BOT_PATH:', BOT_PATH);

// ── Server startup ──────────────────────────────────────────────────────────

let serverStarted = false;

function startServer() {
  if (serverStarted) return;
  serverStarted = true;

  const config = readConfig();
  if (config.discordBotToken) process.env.DISCORD_BOT_TOKEN = config.discordBotToken;
  if (config.discordGuildId) process.env.DISCORD_GUILD_ID = config.discordGuildId;

  // Pre-configure the bot path so the client skips interactive discovery
  try {
    const botConfigPath = path.join(CLIENT_PATH, 'bot-config.json');
    fs.writeFileSync(botConfigPath, JSON.stringify({ botPath: BOT_PATH }, null, 2));
  } catch (err) {
    console.error('[app] Failed to write bot-config.json:', err.message);
  }

  try {
    require(path.join(CLIENT_PATH, 'server.js'));
    console.log('[app] Client server started');
  } catch (err) {
    console.error('[app] Failed to start client server:', err);
  }
}

// Wait until the server is accepting connections, then resolve
function waitForServer(port, timeout = 10000) {
  return new Promise((resolve, reject) => {
    const deadline = Date.now() + timeout;

    function attempt() {
      const req = http.get(`http://localhost:${port}`, () => {
        req.destroy();
        resolve();
      });
      req.on('error', () => {
        if (Date.now() > deadline) {
          reject(new Error(`Server on port ${port} did not start within ${timeout}ms`));
        } else {
          setTimeout(attempt, 200);
        }
      });
      req.setTimeout(500, () => req.destroy());
    }

    attempt();
  });
}

// ── Windows ─────────────────────────────────────────────────────────────────

let mainWindow = null;
let settingsWindow = null;

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 900,
    minHeight: 600,
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#2f3136',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
    },
    show: false,
  });

  mainWindow.loadURL('http://localhost:5002');

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  // Hide to tray on close rather than quitting
  mainWindow.on('close', (e) => {
    if (!app.isQuitting) {
      e.preventDefault();
      mainWindow.hide();
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

function openSettings() {
  if (settingsWindow) {
    settingsWindow.focus();
    return;
  }

  settingsWindow = new BrowserWindow({
    width: 500,
    height: 340,
    resizable: false,
    minimizable: false,
    maximizable: false,
    title: 'Discord Image Dashboard — Settings',
    backgroundColor: '#2f3136',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
    },
  });

  settingsWindow.loadFile(path.join(__dirname, 'settings.html'));
  settingsWindow.setMenu(null);

  settingsWindow.on('closed', () => {
    settingsWindow = null;
  });
}

// ── Tray ─────────────────────────────────────────────────────────────────────

let tray = null;

function createTray() {
  const iconPath = path.join(__dirname, 'assets', 'tray-icon.png');
  const icon = nativeImage.createFromPath(iconPath).resize({ width: 16, height: 16 });
  icon.setTemplateImage(true); // adapts to dark/light menu bar

  tray = new Tray(icon);
  tray.setToolTip('Discord Image Dashboard');

  const menu = Menu.buildFromTemplate([
    {
      label: 'Show Dashboard',
      click() {
        if (mainWindow) {
          mainWindow.show();
          mainWindow.focus();
        } else {
          createMainWindow();
        }
      },
    },
    {
      label: 'Settings',
      click() {
        openSettings();
      },
    },
    { type: 'separator' },
    {
      label: 'Quit',
      click() {
        app.isQuitting = true;
        app.quit();
      },
    },
  ]);

  tray.setContextMenu(menu);
  tray.on('click', () => {
    if (mainWindow) {
      mainWindow.isVisible() ? mainWindow.focus() : mainWindow.show();
    } else {
      createMainWindow();
    }
  });
}

// ── IPC handlers ─────────────────────────────────────────────────────────────

ipcMain.handle('get-config', () => readConfig());

ipcMain.handle('save-config', (_event, data) => {
  const existing = readConfig();
  const merged = { ...existing, ...data };
  writeConfig(merged);

  // Apply immediately to running process
  if (merged.discordBotToken) process.env.DISCORD_BOT_TOKEN = merged.discordBotToken;
  if (merged.discordGuildId) process.env.DISCORD_GUILD_ID = merged.discordGuildId;

  return { success: true };
});

// ── App lifecycle ─────────────────────────────────────────────────────────────

app.whenReady().then(async () => {
  createTray();
  startServer();

  try {
    await waitForServer(5002);
    console.log('[app] Server ready');
  } catch (err) {
    console.error('[app] Server timeout:', err.message);
  }

  createMainWindow();

  const config = readConfig();
  if (!config.discordBotToken || !config.discordGuildId) {
    openSettings();
  }
});

// Keep app alive when all windows are closed (lives in tray)
app.on('window-all-closed', (e) => {
  e.preventDefault();
});

app.on('activate', () => {
  if (mainWindow) {
    mainWindow.show();
    mainWindow.focus();
  } else {
    createMainWindow();
  }
});

app.on('before-quit', () => {
  app.isQuitting = true;
});
