#!/usr/bin/env bash
# Chạy BÊN TRONG container sniffer/attacker (được mount tại /lab-scripts).
# Trích các dòng HTTP dạng chữ rõ từ file pcap để làm bằng chứng.
# Dùng:  extract-http.sh <file.pcap> <file-kết-quả.txt>
set -euo pipefail

PCAP="${1:?thiếu đường dẫn file pcap}"
OUT="${2:?thiếu đường dẫn file kết quả}"

# tcpdump -A in cả header IP/TCP dạng ký tự rác ở đầu dòng đầu tiên của mỗi gói,
# nên dòng request (GET/POST) không nằm ở đầu dòng: dùng grep -o, không neo ^.
DUMP="$(tcpdump -nn -A -r "$PCAP" 2>/dev/null | tr -d '\r' || true)"

{
  echo "=== Dòng request (chữ rõ) ==="
  printf '%s\n' "$DUMP" | grep -aEo '(GET|POST) [^ ]+ HTTP/1\.[01]' | awk '!seen[$0]++' || echo "(không thấy)"
  echo
  echo "=== Dòng response ==="
  printf '%s\n' "$DUMP" | grep -aEo 'HTTP/1\.[01] [0-9]{3}[^"]*' | awk '!seen[$0]++' | head -n 5 || echo "(không thấy)"
  echo
  echo "=== Header tiết lộ thông tin ==="
  printf '%s\n' "$DUMP" | grep -aEi '^(Server|User-Agent|Authorization|Host): ' || echo "(không thấy)"
  echo
  echo "=== Nội dung form gửi đi (body) ==="
  printf '%s\n' "$DUMP" | grep -aEo 'username=[^ ]*' || echo "(không thấy)"
  echo
  echo "=== Giải mã Authorization: Basic (base64) ==="
  B64="$(printf '%s\n' "$DUMP" | grep -aiE '^Authorization: Basic ' | head -n 1 | awk '{print $3}' || true)"
  if [ -n "${B64:-}" ]; then
    echo "base64   : $B64"
    echo "giải mã  : $(printf '%s' "$B64" | base64 -d 2>/dev/null || echo '(giải mã lỗi)')"
  else
    echo "(không tìm thấy header Authorization)"
  fi
} > "$OUT"

echo "Đã ghi: $OUT"
