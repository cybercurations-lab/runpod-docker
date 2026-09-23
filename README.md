# RunPod Docker Images — Build via GitHub Actions

## Why GitHub Actions (not local build)
Local build of a 22GB image needs ~40-50GB temp space during build.
Agent37 has only 19GB — **local build would crash the system.**
GitHub Actions runs in the cloud — zero local disk impact.

## Setup (one-time)

1. **Create a GitHub repo** (private or public)
2. **Push this directory** to the repo
3. **Create Docker Hub account** (free) → get API token at hub.docker.com → Account Settings → Security → New Access Token (Write scope)
4. **Add GitHub Secrets** (repo → Settings → Secrets → Actions):
   - `DOCKERHUB_USERNAME` = your Docker Hub username
   - `DOCKERHUB_TOKEN` = Docker Hub access token
5. **Edit** `.github/workflows/build-image.yml` — change `DOCKERHUB_REPO` to your Docker Hub username

## Build

GitHub repo → Actions tab → "Build RunPod Docker Image" → Run workflow:
- `image_tag`: `wan22-comfyui:v1`
- `model`: `wan22-comfyui` (or `base` for no models)

Build takes ~20-40 min in cloud. No local resources used.

## Deploy on RunPod

Pods → Deploy → Template: select your image, or API:
```json
{
  "name": "wan22-comfyui",
  "image": "cyber2000/wan22-comfyui:v1",
  "gpu": {"id": "NVIDIA GeForce RTX 4090", "count": 1},
  "ports": ["8188/http", "22/tcp"],
  "startSsh": true
}
```

## Image variants

| Model | Build arg | Size | Contents |
|-------|-----------|------|----------|
| `base` | `MODEL=base` | ~5GB | ComfyUI only, no models |
| `wan22-comfyui` | `MODEL=wan22` | ~22GB | + Wan 2.2 Q5_K_M (480p + 720p) |

### Adding more models (Flux, SDXL, etc.)
Create separate Dockerfiles — don't stack them into one image:
```
runpod-docker/
├── Dockerfile              # wan22 (this one)
├── Dockerfile.flux         # Flux Dev
├── Dockerfile.sdxl         # SDXL
└── base/                   # shared base image
```
Or extend the base image:
```dockerfile
FROM cyber2000/runpod-base:v1
RUN wget ... flux model ...
```

## Disk space

### GitHub Actions
- Runner: ~14GB free after cleanup
- Workflow frees ~20GB more (removes .NET, Android SDK, etc.)
- Intermediate layers cleaned via BuildKit
- **Limit: ~40GB total** — enough for 22GB image

### If image exceeds GitHub Actions limits
- Use a VPS (ComfyVPS4 has space) — build there, push to Docker Hub
- Or split into multi-stage build (model download as separate layer)

### Docker Hub free tier
- Public repos: unlimited storage ✓
- Private repos: 100GB total
- Pull rate: 6hr per IP
- **22GB public image: no problem**

## Disk space during local build (if you must)
```bash
# Needs ~50GB free
df -h  # check first
docker build --platform linux/amd64 -t user/image:v1 .
# Clean up after:
docker system prune -af
```

## File structure
```
runpod-docker/
├── Dockerfile                      # Main build file (wan22 or base)
├── start.sh                        # Container entrypoint
├── README.md                       # This file
└── .github/
    └── workflows/
        └── build-image.yml         # GitHub Actions workflow
```

## Cost
| Item | Cost |
|------|------|
| GitHub Actions build | Free (2000 min/month) |
| Docker Hub (public) | Free |
| RunPod GPU compute | Per-second, only while pod runs |
| RunPod image pull | Free (cached after first pull) |
