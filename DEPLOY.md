# Deployment Guide: Railway (Backend) + Vercel (Frontend)

## 1. Deploy the Backend on Railway (free tier)

1. Go to [railway.com](https://railway.com) and sign up / log in
2. Click **"New Project"** → **"Deploy from GitHub Repo"**
3. Connect your GitHub account and select the `Workout` repository
4. Railway will auto-detect the config. Set these **environment variables**:
   - `DATA_DIR` = `/app/data` (where the SQLite database lives)
5. Railway auto-builds and deploys. Your API will be at something like:
   ```
   https://workout-production-xxxx.up.railway.app
   ```
6. Copy that URL — you'll need it for the frontend.

### Railway Build Settings (if not auto-detected)
- **Root Directory**: `server`
- **Build Command**: `npm install && npm run build`
- **Start Command**: `npm run start`

## 2. Deploy the Frontend on Vercel (free tier)

1. Go to [vercel.com](https://vercel.com) and sign up / log in
2. Click **"Add New Project"** → Import the `Workout` GitHub repo
3. Configure:
   - **Framework Preset**: Vite
   - **Root Directory**: `client`
   - **Build Command**: `npm run build` (auto-detected)
   - **Output Directory**: `dist` (auto-detected)
4. Add this **environment variable**:
   - `VITE_API_URL` = `https://workout-production-xxxx.up.railway.app` (your Railway URL from step 1)
5. Deploy! Your app will be live at something like:
   ```
   https://workout-xxxx.vercel.app
   ```

## 3. Open on Your Phone

Just open the Vercel URL in your phone's browser. That's it!

**Tip**: On iPhone, tap the share button → "Add to Home Screen" to make it feel like a native app.

## Local Development

Nothing changes for local dev — `npm run dev` still works:
- Client runs on `http://localhost:5173` with Vite proxy to the server
- Server runs on `http://localhost:3001`
- The `VITE_API_URL` env var defaults to empty string (uses proxy in dev)
