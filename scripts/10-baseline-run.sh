#!/usr/bin/env bash
# GIAI ĐOẠN 1: dựng lab baseline (không Ziti), tấn công thử và lưu bằng chứng.
# Dùng:  ./scripts/10-baseline-run.sh
# Kết quả nằm trong evidence/baseline/
# Chỉ chạy trong lab do nhóm tự dựng.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

COMPOSE=(docker compose -f docker-compose.baseline.yml)
OUT_HOST="evidence/baseline"
OUT_CTR="/evidence/baseline"
WEB_IP="172.28.0.10"

# Thông tin đăng nhập GIẢ, chỉ dùng trong lab để minh họa việc bị nghe lén.
DEMO_USER="demo-user"
DEMO_PASS="Demo@123"

step() { printf '\n==> %s\n' "$*"; }

mkdir -p "$OUT_HOST"

step "1/6 Dựng lab (lần đầu build image Kali sẽ mất vài phút)"
"${COMPOSE[@]}" up -d --build

step "2/6 Ghi lại phiên bản môi trường"
{
  echo "Thời điểm (UTC): $(date -u '+%Y-%m-%d %H:%M:%S')"
  docker --version
  docker compose version
  echo "--- nmap trong container attacker ---"
  "${COMPOSE[@]}" exec -T attacker nmap --version | head -n 2
  echo "--- tcpdump trong container sniffer ---"
  "${COMPOSE[@]}" exec -T sniffer tcpdump --version 2>&1 | head -n 1
  echo "--- image đang dùng ---"
  docker inspect --format '{{.Name}}: {{.Config.Image}}' zt-baseline-web zt-attacker zt-sniffer zt-client
} > "$OUT_HOST/environment.txt" 2>&1
echo "đã ghi $OUT_HOST/environment.txt"

step "3/6 nmap quét toàn bộ cổng của web (từ container attacker)"
"${COMPOSE[@]}" exec -T attacker \
  nmap -sS -sV -p- -T4 --reason -n \
       -oN "$OUT_CTR/nmap-baseline.txt" -oX "$OUT_CTR/nmap-baseline.xml" "$WEB_IP"

step "4/6 Nghe lén lưu lượng HTTP trong lúc người dùng truy cập"
"${COMPOSE[@]}" exec -T sniffer sh -c \
  "rm -f $OUT_CTR/baseline-http.pcap; timeout 20 tcpdump -i eth0 -n -U -w $OUT_CTR/baseline-http.pcap 'tcp port 80' 2>/dev/null" &
SNIFF_PID=$!
sleep 3

# GET có Basic Auth, rồi POST form. POST vào nginx tĩnh trả 405: bình thường,
# vì mục đích chỉ là có dữ liệu chạy trên đường truyền.
"${COMPOSE[@]}" exec -T client sh -c "
  curl -sS -u '${DEMO_USER}:${DEMO_PASS}' -A 'ziti-lab-client/1.0' -o /dev/null \
       -w 'GET  /  -> HTTP %{http_code}\n' http://web/
  curl -sS -X POST -d 'username=${DEMO_USER}&password=${DEMO_PASS}' -o /dev/null \
       -w 'POST /  -> HTTP %{http_code}\n' http://web/
" | tee "$OUT_HOST/client-requests.txt"

wait "$SNIFF_PID" || true     # timeout kết thúc tcpdump nên mã thoát 124 là bình thường

step "5/6 Trích nội dung chữ rõ từ file pcap"
"${COMPOSE[@]}" exec -T sniffer /lab-scripts/extract-http.sh \
  "$OUT_CTR/baseline-http.pcap" "$OUT_CTR/http-plaintext-extract.txt"

# Trả quyền sở hữu file về user hiện tại (file do root trong container tạo ra)
"${COMPOSE[@]}" exec -T sniffer chown -R "$(id -u):$(id -g)" "$OUT_CTR" || true

step "6/6 Tổng hợp RESULT.md"
open_ports="$(grep -E '^[0-9]+/tcp' "$OUT_HOST/nmap-baseline.txt" || echo '(không có cổng mở)')"
extract="$(cat "$OUT_HOST/http-plaintext-extract.txt")"
cat > "$OUT_HOST/RESULT.md" <<EOF
# Kết quả baseline (KHÔNG có OpenZiti)

Tạo bởi scripts/10-baseline-run.sh lúc $(date -u '+%Y-%m-%d %H:%M:%S') UTC.

## 1. nmap: các cổng kẻ tấn công thấy được
\`\`\`
${open_ports}
\`\`\`
File đầy đủ: nmap-baseline.txt, nmap-baseline.xml

## 2. Nghe lén: nội dung đọc được trên đường truyền
\`\`\`
${extract}
\`\`\`
File gốc để mở bằng Wireshark: baseline-http.pcap
(Wireshark: Analyze > Follow > TCP Stream để thấy toàn bộ cuộc hội thoại)

## 3. Kết luận cho baseline
- Web server lộ cổng 80 và phiên bản phần mềm cho bất kỳ ai quét được.
- Lưu lượng HTTP không mã hóa nên header và thông tin đăng nhập đọc được.
- Đây là mốc đối chứng cho kết quả sau khi bảo vệ bằng OpenZiti (Giai đoạn 5).
EOF

echo
echo "Xong. Xem evidence/baseline/RESULT.md, và mở baseline-http.pcap bằng Wireshark để chụp ảnh."
echo "Dọn dẹp:  docker compose -f docker-compose.baseline.yml down"
