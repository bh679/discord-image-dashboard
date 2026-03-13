# Discord Image Dashboard — Local Setup Guide

> **Hey Leonie!** In Step 2b, skip creating the `.env` file yourself — get it from Brennan directly.

---

## What You're Setting Up

A Discord bot that aggregates all images posted in your server, plus a web dashboard to browse them. Two separate services run locally:

| Service | Port | What it does |
|---|---|---|
| Bot + API | `5001` | Listens to Discord, stores images, serves the REST API |
| Web Dashboard | `5002` | Frontend you open in your browser |

---

## Prerequisites

### Node.js (v16 or higher)

Check if you have it:
```bash
node --version
```

If not installed, download from [nodejs.org](https://nodejs.org) (choose the LTS version).

### Git

Check if you have it:
```bash
git --version
```

If not installed, download from [git-scm.com](https://git-scm.com).

---

## Step 1 — Clone the Repositories

You need two repos: the bot and the dashboard. Clone them into the same folder.

```bash
# Create a folder to hold everything
mkdir discord-image-dashboard
cd discord-image-dashboard

# Clone the bot
git clone https://github.com/bh679/discord-image-dashboard-bot.git

# Clone the dashboard frontend
git clone https://github.com/bh679/discord-image-dashboard-client.git
```

---

## Step 2 — Set Up the Bot

### 2a. Install dependencies

```bash
cd discord-image-dashboard-bot
npm install
```

### 2b. Create your `.env` file

> **Hey Leonie — skip this and get this file from Brennan directly.**

<details>
<summary>Setting up your own .env from scratch — click to expand</summary>

Copy the example file:
```bash
cp .env.example .env
```

Open `.env` in any text editor and fill in your Discord credentials:

```
DISCORD_BOT_TOKEN=your_bot_token_here
DISCORD_GUILD_ID=your_server_id_here
PORT=5001
```

**How to get these values:**

**Bot Token:**
1. Go to [discord.com/developers/applications](https://discord.com/developers/applications)
2. Click **New Application** (or select an existing one)
3. Go to the **Bot** tab in the left sidebar
4. Click **Reset Token** and copy the token
5. Paste it as `DISCORD_BOT_TOKEN`

**Guild (Server) ID:**
1. In Discord, go to **Settings → Advanced** and enable **Developer Mode**
2. Right-click your server name in the left sidebar
3. Click **Copy Server ID**
4. Paste it as `DISCORD_GUILD_ID`

**Add the Bot to Your Server:**
1. In the Discord Developer Portal, go to **OAuth2 → URL Generator**
2. Under **Scopes**, check `bot`
3. Under **Bot Permissions**, check: `Read Messages/View Channels`, `Read Message History`
4. Copy the generated URL, paste it in your browser, and follow the prompts to add the bot to your server

</details>

---

## Step 3 — Set Up the Dashboard

Open a **new terminal tab**, then:

```bash
cd discord-image-dashboard-client
npm install
```

No `.env` needed — by default the dashboard connects to the bot API on `http://localhost:5001`. If your bot runs on a different port, create a `.env` file:

```
VITE_API_URL=http://localhost:5001
```

---

## Step 4 — Run Everything

You need **two terminal windows/tabs** running at the same time.

### Terminal 1 — Start the Bot

```bash
cd discord-image-dashboard-bot
npm run dev
```

You should see output confirming the bot is online and the API is listening on port `5001`.

### Terminal 2 — Start the Dashboard

```bash
cd discord-image-dashboard-client
npm run dev
```

The dashboard will be available at **[http://localhost:5002](http://localhost:5002)**.

---

## Step 5 — Verify It Works

1. Open **[http://localhost:5002](http://localhost:5002)** in your browser
2. The dashboard should load showing images from your Discord server
3. If no images appear, make sure the bot has been in your server and that messages with images have been sent recently

---

## Troubleshooting

**Bot won't connect / "Invalid token" error**
- Double-check your `DISCORD_BOT_TOKEN` in the `.env` file — no extra spaces or quotes

**No images showing in the dashboard**
- Confirm the bot is running (Terminal 1 shows it online)
- Confirm the bot has permission to read message history in your Discord server channels
- Images from before the bot was added won't appear — it needs to be present when messages are sent, or you can trigger a backfill if supported

**Dashboard shows "Failed to fetch" or blank**
- Confirm the bot API is running on port `5001` (check Terminal 1)
- Check that the `VITE_API_URL` in the client `.env` (if you created one) matches the bot's port

**Port already in use**
- Something else is using port `5001` or `5002`
- Stop the conflicting process, or change the port in the bot's `.env` (`PORT=5003`) and update the client's `VITE_API_URL` to match

---

## Stopping the Services

In each terminal, press **Ctrl+C** to stop the running service.
