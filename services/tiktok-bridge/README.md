# TikTok Bridge Service

A Node.js service that connects to TikTok Live streams and forwards events to the Elixir app via WebSocket.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Elixir App (Pavoi)                                         │
│    └─ BridgeClient (WebSocket client)                       │
│         │                                                    │
│         │ WebSocket (ws://tiktok-bridge:8080/events)        │
│         │ HTTP (POST /connect, /disconnect)                 │
│         ▼                                                    │
├─────────────────────────────────────────────────────────────┤
│  TikTok Bridge (this service)                               │
│    └─ tiktok-live-connector library                         │
│         │                                                    │
│         │ TikTok Protocol (WebSocket + HTTP + protobuf)     │
│         ▼                                                    │
├─────────────────────────────────────────────────────────────┤
│  TikTok Live Servers                                        │
└─────────────────────────────────────────────────────────────┘
```

## API

### HTTP Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| GET | `/status` | List active connections and stats |
| POST | `/connect` | Connect to a TikTok stream |
| POST | `/disconnect` | Disconnect from a stream |

### WebSocket

Connect to `ws://host:8080/events` to receive real-time events.

#### Event Types

```json
{ "type": "connected", "uniqueId": "username", "roomId": "123", "roomInfo": {...} }
{ "type": "disconnected", "uniqueId": "username" }
{ "type": "chat", "uniqueId": "username", "data": { "userId": "...", "comment": "..." } }
{ "type": "gift", "uniqueId": "username", "data": { "giftName": "...", "diamondCount": 100 } }
{ "type": "like", "uniqueId": "username", "data": { "likeCount": 5, "totalLikeCount": 1000 } }
{ "type": "member", "uniqueId": "username", "data": { "userId": "...", "nickname": "..." } }
{ "type": "roomUser", "uniqueId": "username", "data": { "viewerCount": 500 } }
{ "type": "social", "uniqueId": "username", "data": { "displayType": "follow" } }
{ "type": "streamEnd", "uniqueId": "username" }
{ "type": "error", "uniqueId": "username", "error": "error message" }
```

## Local Development

```bash
cd services/tiktok-bridge
npm install
npm start
```

Test with curl:
```bash
# Health check
curl http://localhost:8080/health

# Connect to a stream (user must be live)
curl -X POST http://localhost:8080/connect \
  -H "Content-Type: application/json" \
  -d '{"uniqueId": "pavoi"}'

# Check status
curl http://localhost:8080/status

# Disconnect
curl -X POST http://localhost:8080/disconnect \
  -H "Content-Type: application/json" \
  -d '{"uniqueId": "pavoi"}'
```

## Railway Deployment

### 1. Add as a new service in Railway

1. Go to your Railway project
2. Click "New Service" → "GitHub Repo"
3. Select your repo and set:
   - **Root Directory**: `services/tiktok-bridge`
   - **Start Command**: `node server.js`

Or use the Dockerfile:
   - **Builder**: Dockerfile
   - **Dockerfile Path**: `services/tiktok-bridge/Dockerfile`

### 2. Configure environment variables

| Variable | Value | Description |
|----------|-------|-------------|
| `PORT` | `8080` | Server port (Railway sets this automatically) |
| `HOST` | `0.0.0.0` | Bind address |

### 3. Set up internal networking

Railway automatically provides internal URLs for services. Your bridge will be accessible at:
```
http://tiktok-bridge.railway.internal:8080
```

### 4. Update Elixir app configuration

Add to your Elixir app's environment variables in Railway:
```
TIKTOK_BRIDGE_URL=http://tiktok-bridge.railway.internal:8080
```

## Resource Requirements

- **Memory**: ~256-512MB (tiktok-live-connector is lightweight)
- **CPU**: Minimal (mostly I/O bound)
- **Network**: Internal only (no public exposure needed)

## Notes

- This service replaces Euler Stream as the TikTok connection provider
- Uses `tiktok-live-connector` which still relies on signing servers for TikTok authentication
- If signing servers become unavailable, consider implementing custom signing with Playwright
