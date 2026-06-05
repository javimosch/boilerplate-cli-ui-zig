# boilerplate-cli-ui-zig

Zig CLI with embedded web UI. Single binary, **190KB** — the smallest of all versions!
Part of [SuperCLI](https://github.com/javimosch/supercli) — build CLI/UI plugins fast for 2026.
| Stack | Repo | Binary | SDK Size |
|-------|------|--------|----------|
| Go + inline HTML | [boilerplate-cli-ui-go](https://github.com/javimosch/boilerplate-cli-ui-go) | ~5MB | ~150MB |
| Go + Vue 3 CDN | [boilerplate-cli-ui-go-v2-vue](https://github.com/javimosch/boilerplate-cli-ui-go-v2-vue) | ~5MB | ~150MB |
| Go + React 18 CDN | [boilerplate-cli-ui-go-v2-react](https://github.com/javimosch/boilerplate-cli-ui-go-v2-react) | ~5MB | ~150MB |
| Deno + vanilla JS | [boilerplate-cli-ui-deno](https://github.com/javimosch/boilerplate-cli-ui-deno) | ~76MB | ~100MB |
| Node.js + vanilla JS | [boilerplate-cli-ui-node](https://github.com/javimosch/boilerplate-cli-ui-node) | ~123MB | ~500MB+ |
| Python + React CDN | [boilerplate-cli-ui-python](https://github.com/javimosch/boilerplate-cli-ui-python) | ~10MB | ~300MB |
| Rust + vanilla JS | [boilerplate-cli-ui-rust](https://github.com/javimosch/boilerplate-cli-ui-rust) | ~1.1MB | ~800MB |
| .NET 8 + Vue 3 | [boilerplate-cli-ui-dotnet](https://github.com/javimosch/boilerplate-cli-ui-dotnet) | ~89MB | ~600MB |
| C++ + Vue 3 | [boilerplate-cli-ui-cpp](https://github.com/javimosch/boilerplate-cli-ui-cpp) | ~493KB | ~2GB+ |
| Nim + Vue 3 | [boilerplate-cli-ui-nim](https://github.com/javimosch/boilerplate-cli-ui-nim) | ~364KB | ~50MB |
| **Zig + Vue 3** | **boilerplate-cli-ui-zig** | **~190KB** |
| Dart + Vue 3 | [boilerplate-cli-ui-dart](https://github.com/javimosch/boilerplate-cli-ui-dart) | ~6.4MB | ~400MB |
|| V + Vue 3 | [boilerplate-cli-ui-v](https://github.com/javimosch/boilerplate-cli-ui-v) | ~1.2MB | ~5MB |
|| Crystal + Vue 3 | [boilerplate-cli-ui-crystal](https://github.com/javimosch/boilerplate-cli-ui-crystal) | ~3.1MB | ~50MB |
## Architecture
```
boilerplate-cli-ui-zig/
├── build.zig              # Build system
├── build.zig.zon          # Package manifest
├── src/
│   ├── main.zig           # CLI + HTTP server
│   └── ui/                # Frontend (embedded at compile time via @embedFile)
│       ├── index.html
│       ├── js/
│       │   ├── app.js
│       │   ├── components/
│       │   └── views/
│       └── css/
│           └── styles.css
├── README.md
└── .gitignore
## Key Feature: @embedFile
Frontend files are **embedded into the binary** at compile time:
```zig
const index_html = @embedFile("ui/index.html");
const app_js = @embedFile("ui/js/app.js");
`@embedFile` resolves paths relative to the `.zig` source file's directory.
Since `main.zig` is in `src/`, `@embedFile("ui/index.html")` reads `src/ui/index.html`.
**Benefits:**
- Single binary output (no runtime file dependencies)
- Compile-time embedding
- No runtime overhead — strings are just static data
## Prerequisites
```bash
# Install Zig (via snap)
sudo snap install zig --classic --edge
# Or via official installer
curl -fsSL https://ziglang.org/download/0.16.0/zig-linux-x86_64-0.16.0.tar.xz | tar xJ
export PATH=$PWD/zig-linux-x86_64-0.16.0:$PATH
## Build
# Release build (optimize for size — produces ~190KB binary)
zig build -Doptimize=ReleaseSmall
# Or debug build (for development)
zig build
# Run directly
zig build run -- start
## Usage
# Start server (foreground)
./zig-out/bin/boilerplate-cli-ui-zig start
# Start on custom port
./zig-out/bin/boilerplate-cli-ui-zig start -p 3000
# Show version
./zig-out/bin/boilerplate-cli-ui-zig version
# Show help
./zig-out/bin/boilerplate-cli-ui-zig help
## API Endpoints
| Endpoint | Description |
|----------|-------------|
| `GET /` | Web UI |
| `GET /api/status` | Server status (JSON) |
| `GET /api/health` | Health check (JSON) |
## Hashbang Routing
Routes use hashbang URLs:
- `http://localhost:8080/#/dashboard` — Dashboard view
- `http://localhost:8080/#/settings` — Settings view (with dark mode)
- `http://localhost:8080/` — Defaults to dashboard
## Frontend Stack
- **Vue 3** (CDN) — Reactive UI with hashbang routing
- **Tailwind CSS** (CDN) — Utility-first styling (with dark mode support)
- **Lucide Icons** (CDN) — Icon library
## Comparison
| Aspect | Go | Rust | C++ | Nim | **Zig** |
|--------|-----|------|-----|-----|---------|
| Binary size | ~5MB | ~150MB | ~1.1MB | ~800MB | ~493KB | ~2GB+ | ~364KB | ~50MB | **~190KB** |
| Dev speed | ⭐⭐⭐ | ⭐⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐ |
| Syntax | Go | Rust | C++ | Python-like | C-like |
| Ecosystem | Large | Medium | Large | Medium | Small |
