# boilerplate-cli-ui-zig

Zig CLI with embedded web UI. Single binary, **190KB** — the smallest of all versions!

Part of [SuperCLI](https://github.com/javimosch/supercli) — build CLI/UI plugins fast for 2026.

**Other versions**: [Go+Vue](https://github.com/javimosch/boilerplate-cli-ui-go-v2-vue) | [Rust+Vue](https://github.com/javimosch/boilerplate-cli-ui-rust) | [C++](https://github.com/javimosch/boilerplate-cli-ui-cpp) | [.NET](https://github.com/javimosch/boilerplate-cli-ui-dotnet) | [Node](https://github.com/javimosch/boilerplate-cli-ui-node) | [Python](https://github.com/javimosch/boilerplate-cli-ui-python) | [Nim](https://github.com/javimosch/boilerplate-cli-ui-nim)

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
```

## Key Feature: @embedFile

Frontend files are **embedded into the binary** at compile time:

```zig
const index_html = @embedFile("ui/index.html");
const app_js = @embedFile("ui/js/app.js");
```

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
```

## Build

```bash
# Release build (optimize for size — produces ~190KB binary)
zig build -Doptimize=ReleaseSmall

# Or debug build (for development)
zig build

# Run directly
zig build run -- start
```

## Usage

```bash
# Start server (foreground)
./zig-out/bin/boilerplate-cli-ui-zig start

# Start on custom port
./zig-out/bin/boilerplate-cli-ui-zig start -p 3000

# Show version
./zig-out/bin/boilerplate-cli-ui-zig version

# Show help
./zig-out/bin/boilerplate-cli-ui-zig help
```

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
| Binary size | ~5MB | ~1.1MB | ~493KB | ~364KB | **~190KB** |
| Dev speed | ⭐⭐⭐ | ⭐⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐ |
| Syntax | Go | Rust | C++ | Python-like | C-like |
| Ecosystem | Large | Medium | Large | Medium | Small |
