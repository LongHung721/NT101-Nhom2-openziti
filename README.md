# ziti-lab: Đồ án OpenZiti / Zero-Trust trên Docker

Lab học tập cho môn An toàn mạng máy tính: dựng mạng overlay OpenZiti trên Docker và chứng minh bằng kiểm thử tấn công rằng dịch vụ nội bộ có thể "tối" (dark service) và chỉ identity được cấp quyền mới truy cập được.

> **Chỉ chạy các công cụ tấn công (nmap, tcpdump...) trong lab do nhóm tự dựng**, không nhắm vào mạng của trường hay của người khác.

## Trạng thái các giai đoạn

| Giai đoạn | Nội dung | Trạng thái |
|---|---|---|
| 0 | Chuẩn bị: repo, quy ước, kiểm tra môi trường | Có trong repo này |
| 1 | Baseline: web + Kali, chưa có Ziti | Có trong repo này |
| 2 | Dựng controller, router, ZAC | Có trong repo này |
| 3-4 | Policy, đưa client/server vào overlay | Chưa làm |
| 5 | Kiểm thử tấn công có Ziti | Chưa làm |

## Cấu trúc thư mục

```
ziti-lab/
├── README.md
├── .env.example                  # mẫu cấu hình (copy thành .env)
├── .gitignore                    # chặn .env, *.jwt, identity
├── docker-compose.baseline.yml   # Giai đoạn 1
├── docker-compose.ziti.yml       # Giai đoạn 2: controller, router, ZAC
├── images/
│   ├── kali/Dockerfile           # máy tấn công / nghe lén
│   └── client/Dockerfile         # máy người dùng hợp lệ
├── baseline/web/index.html       # trang web giả lập
├── scripts/
│   ├── 00-check-env.sh           # kiểm tra máy (Giai đoạn 0)
│   ├── 10-baseline-run.sh        # chạy baseline + thu bằng chứng (Giai đoạn 1)
│   └── container/extract-http.sh # chạy trong container, trích nội dung từ pcap
└── evidence/
    ├── baseline/                 # bằng chứng không có Ziti
    └── ziti/                     # bằng chứng có Ziti (Giai đoạn 5)
```

## Giai đoạn 0: Chuẩn bị

Yêu cầu: Docker Engine hoặc Docker Desktop, Docker Compose v2 (lệnh `docker compose`), git, khoảng 4 GB RAM trống. Windows nên dùng WSL2 và chạy lệnh trong WSL.

```bash
# Người đầu tiên tạo repo và đẩy lên GitHub/GitLab:
cd ziti-lab && git init -b main && git add . && git commit -m "Giai đoạn 0-1: khung repo và lab baseline"

# Các thành viên còn lại:
git clone <địa-chỉ-repo> && cd ziti-lab

# Mỗi người, trên máy của mình:
chmod +x scripts/*.sh scripts/container/*.sh
./scripts/00-check-env.sh --with-hello-world
```

Checklist nhóm (mỗi người tự tick):

- [ ] `./scripts/00-check-env.sh` báo "máy sẵn sàng"
- [ ] `docker run hello-world` chạy được
- [ ] Clone được repo, có file `.env` của riêng mình (không commit)
- [ ] Cả nhóm đã thống nhất các phiên bản `ZITI_VERSION` và `ZAC_VERSION` trong `.env`
- [ ] Đã đọc phần Quy ước đặt tên bên dưới

## Giai đoạn 1: Baseline (không Ziti)

```bash
./scripts/10-baseline-run.sh
```

Script sẽ: dựng lab → nmap quét web → nghe lén lưu lượng khi người dùng truy cập → trích nội dung chữ rõ → ghi `evidence/baseline/RESULT.md`.

Sơ đồ:

```
 mạng zt-baseline-net (172.28.0.0/24)
 ┌─────────────────────────────────────────────────────────┐
 │  attacker (.20) ── nmap ──►  web (.10)  ◄── client (.30)│
 │                              ▲ cổng 80 MỞ               │
 │                              │ chung network namespace  │
 │                           sniffer (tcpdump)             │
 └─────────────────────────────────────────────────────────┘
```

Vì sao có `sniffer`: trên Docker bridge, một container thường không thấy lưu lượng giữa hai container khác. Sniffer dùng chung network namespace với `web` để mô phỏng kẻ nghe lén ở giữa đường (switch/router/Wi-Fi bị chiếm quyền).

Bằng chứng cần chụp cho báo cáo:

1. Nội dung `nmap-baseline.txt`: thấy cổng 80 mở, nhận diện được nginx.
2. Mở `evidence/baseline/baseline-http.pcap` bằng Wireshark, chụp màn hình khi **Follow TCP Stream** thấy header và thông tin đăng nhập ở dạng chữ rõ.
3. `environment.txt`: phiên bản công cụ đã dùng.

Dọn dẹp: `docker compose -f docker-compose.baseline.yml down` (thêm `--rmi local` nếu muốn xóa cả image đã build).

## Giai đoạn 2: Controller, router và ZAC

Trong WSL/Linux, tạo `.env` từ mẫu nếu chưa có và đặt một mật khẩu admin riêng:

```bash
if [ ! -f .env ]; then cp .env.example .env; fi
# Mở .env, thay ZITI_PWD bằng mật khẩu mạnh; cả nhóm dùng cùng ZITI_VERSION.
docker compose -f docker-compose.ziti.yml pull
docker compose -f docker-compose.ziti.yml up -d
docker compose -f docker-compose.ziti.yml ps
```

Compose tải image OpenZiti quickstart (`ZITI_VERSION`) và ZAC (`ZAC_VERSION`) theo phiên bản ghim trong `.env`; controller và edge router được khởi tạo tự động, còn `controller-init` là container chạy một lần để thiết lập access-control mặc định. Mẫu hiện tại ghim OpenZiti `2.0.8` và ZAC `4.8.0`; nhóm có thể cùng đổi sang cặp phiên bản khác đã xác nhận tương thích.

- ZAC: <https://localhost:8443>
- Controller Edge API: `https://localhost:1280`
- Router edge listener: `localhost:3022`; bind listener: `localhost:10080`

Các cổng host chỉ bind vào `127.0.0.1`, không mở ra mạng LAN. Trình duyệt có thể cảnh báo chứng chỉ tự ký trong lab. Dữ liệu trạng thái lưu ở Docker volume `zt-ziti-data` và tồn tại qua lần khởi động lại.

Kiểm tra log nếu dịch vụ chưa sẵn sàng:

```bash
docker compose -f docker-compose.ziti.yml logs -f controller router zac
```

Dừng các container nhưng giữ dữ liệu:

```bash
docker compose -f docker-compose.ziti.yml down
```

Không xóa volume trừ khi muốn reset lab: `docker compose -f docker-compose.ziti.yml down -v`.

## Quy ước đặt tên (cả nhóm dùng chung)

| Loại | Tên | Ghi chú |
|---|---|---|
| Tiền tố container | `zt-` | vd `zt-attacker` |
| Container baseline | `zt-baseline-web`, `zt-attacker`, `zt-sniffer`, `zt-client` | Giai đoạn 1 |
| Container Ziti | `zt-controller`, `zt-router`, `zt-console`, `zt-web`, `zt-web-tunneler`, `zt-client-01`, `zt-client-02` | Giai đoạn 2-4 |
| Docker network | `zt-baseline-net` (baseline); `zt-ctrl-net`, `zt-app-net`, `zt-attacker-net` (dự kiến) | attacker **không** nằm trong `zt-app-net` |
| Identity | `client-01` (attribute `clients`), `client-02` (không attribute), `web-server` (attribute `servers`) | |
| Service | `web-service` | config: `web.intercept`, `web.host` |
| Địa chỉ intercept | `web.ziti` cổng 80 | |
| Policy | `web-dial`, `web-bind`, `all-routers`, `all-svc` | |
| Thư mục bằng chứng | `evidence/baseline/`, `evidence/ziti/` | commit cả pcap và ảnh |

## Lưu ý bảo mật cho repo

- **Không commit**: `.env`, file `*.jwt`, file identity `*.json` (đã chặn trong `.gitignore`).
- Thông tin đăng nhập `demo-user / Demo@123` trong script là **giả**, chỉ để minh họa việc bị nghe lén.
- Image Kali là bản rolling nên không ghim được theo số phiên bản. Phiên bản công cụ được ghi vào `evidence/baseline/environment.txt`.

## Xử lý lỗi thường gặp

| Triệu chứng | Cách xử lý |
|---|---|
| `Cannot connect to the Docker daemon` | Khởi động Docker; trên Linux thêm user vào nhóm `docker` |
| `address already in use` ở cổng 8080 | Đổi `WEB_HOST_PORT` trong `.env` |
| `Pool overlaps with other one` | Dải 172.28.0.0/24 trùng mạng khác: đổi subnet và các IP trong `docker-compose.baseline.yml` |
| nmap báo `requires root privileges` | Container phải có `cap_add: NET_RAW` (đã cấu hình), kiểm tra bạn dùng đúng file compose |
| File trong `evidence/` thuộc root | Script đã `chown`; nếu vẫn lỗi: `sudo chown -R $USER evidence` |
| Build Kali lỗi mạng khi `apt-get` | Kiểm tra Internet/proxy rồi chạy lại `docker compose -f docker-compose.baseline.yml build --no-cache attacker` |
