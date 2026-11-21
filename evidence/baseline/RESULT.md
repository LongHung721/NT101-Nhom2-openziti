# Kết quả baseline (KHÔNG có OpenZiti)

Tạo bởi scripts/10-baseline-run.sh lúc 2026-11-21 14:31:23 UTC.

## 1. nmap: các cổng kẻ tấn công thấy được
```
80/tcp open  http    syn-ack ttl 64 nginx 1.27.5
```
File đầy đủ: nmap-baseline.txt, nmap-baseline.xml

## 2. Nghe lén: nội dung đọc được trên đường truyền
```
=== Dòng request (chữ rõ) ===
GET / HTTP/1.1
POST / HTTP/1.1

=== Dòng response ===
HTTP/1.1 200 OK
HTTP/1.1 405 Not Allowed

=== Header tiết lộ thông tin ===
Host: web
Authorization: Basic ZGVtby11c2VyOkRlbW9AMTIz
User-Agent: ziti-lab-client/1.0
Server: nginx/1.27.5
Host: web
User-Agent: curl/8.14.1
Server: nginx/1.27.5

=== Nội dung form gửi đi (body) ===
username=demo-user&password=Demo@123

=== Giải mã Authorization: Basic (base64) ===
base64   : ZGVtby11c2VyOkRlbW9AMTIz
giải mã  : demo-user:Demo@123
```
File gốc để mở bằng Wireshark: baseline-http.pcap
(Wireshark: Analyze > Follow > TCP Stream để thấy toàn bộ cuộc hội thoại)

## 3. Kết luận cho baseline
- Web server lộ cổng 80 và phiên bản phần mềm cho bất kỳ ai quét được.
- Lưu lượng HTTP không mã hóa nên header và thông tin đăng nhập đọc được.
- Đây là mốc đối chứng cho kết quả sau khi bảo vệ bằng OpenZiti (Giai đoạn 5).
