#!/usr/bin/env bash
# GIAI ĐOẠN 0: kiểm tra máy của bạn đã sẵn sàng chạy lab chưa.
# Dùng:  ./scripts/00-check-env.sh [--with-hello-world]
#   --with-hello-world : chạy thêm "docker run hello-world" (cần Internet)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAIL=0
ok()   { printf '  [OK]        %s\n' "$*"; }
bad()  { printf '  [LỖI]       %s\n' "$*"; FAIL=1; }
warn() { printf '  [CẢNH BÁO]  %s\n' "$*"; }

echo "== 1. Hệ điều hành =="
OS="$(uname -s)"
if [ "$OS" = "Linux" ] && grep -qi microsoft /proc/version 2>/dev/null; then
  ok "Linux chạy trong WSL2 (hợp lệ cho Windows)"
else
  ok "$OS"
fi

echo "== 2. Docker =="
if command -v docker >/dev/null 2>&1; then
  ok "Có docker: $(docker --version 2>/dev/null)"
else
  bad "Chưa cài Docker. Cài Docker Engine (Linux) hoặc Docker Desktop (Windows/macOS, bật WSL2)."
fi

if docker compose version >/dev/null 2>&1; then
  ok "Có Docker Compose v2: $(docker compose version --short 2>/dev/null || docker compose version)"
else
  bad "Thiếu 'docker compose' (v2). Lệnh 'docker-compose' kiểu cũ không dùng được cho repo này."
fi

if docker info >/dev/null 2>&1; then
  ok "Docker daemon đang chạy"
else
  bad "Không nối được Docker daemon. Hãy khởi động Docker (hoặc kiểm tra quyền: nhóm 'docker' trên Linux)."
fi

echo "== 3. Cấu hình .env =="
if [ ! -f .env ]; then
  cp .env.example .env
  ok "Chưa có .env, đã tạo từ .env.example (hãy mở ra kiểm tra)"
else
  ok "Đã có .env"
fi
WEB_HOST_PORT="$(grep -E '^WEB_HOST_PORT=' .env | head -n 1 | cut -d= -f2 | tr -d '[:space:]')"
WEB_HOST_PORT="${WEB_HOST_PORT:-8080}"

echo "== 4. Cổng và mạng =="
if (exec 3<>"/dev/tcp/127.0.0.1/${WEB_HOST_PORT}") 2>/dev/null; then
  warn "Cổng ${WEB_HOST_PORT} trên máy đang bị dùng. Đổi WEB_HOST_PORT trong .env."
else
  ok "Cổng ${WEB_HOST_PORT} còn trống"
fi

if docker info >/dev/null 2>&1; then
  CONFLICT="$(docker network ls --format '{{.Name}}' 2>/dev/null | grep -vx 'zt-baseline-net' | while read -r n; do
      docker network inspect "$n" --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null
    done | tr ' ' '\n' | grep -E '^172\.28\.' || true)"
  if [ -n "$CONFLICT" ]; then
    warn "Mạng Docker khác đang dùng dải 172.28.x.x ($CONFLICT). Đổi subnet trong docker-compose.baseline.yml và IP các container."
  else
    ok "Dải 172.28.0.0/24 không trùng mạng Docker nào"
  fi
fi

echo "== 5. Git =="
if command -v git >/dev/null 2>&1; then
  ok "Có git: $(git --version)"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ok "Thư mục này là repo Git"
  else
    warn "Chưa là repo Git. Chạy 'git init' hoặc clone repo của nhóm."
  fi
else
  bad "Chưa cài git"
fi

if [ "${1:-}" = "--with-hello-world" ]; then
  echo "== 6. docker run hello-world =="
  if docker run --rm hello-world >/dev/null 2>&1; then
    ok "docker run hello-world chạy được"
  else
    bad "docker run hello-world thất bại (kiểm tra Internet và quyền Docker)"
  fi
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "KẾT LUẬN: máy sẵn sàng. Bước tiếp theo: ./scripts/10-baseline-run.sh"
else
  echo "KẾT LUẬN: còn lỗi ở trên, hãy sửa trước khi làm tiếp."
fi
exit "$FAIL"
