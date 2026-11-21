# Máy "kẻ tấn công" và "người nghe lén" cho lab. Chỉ dùng trong lab của nhóm.
# Lưu ý: kali-rolling là bản cuốn chiếu nên không ghim được phiên bản theo số.
# Ghi lại phiên bản công cụ vào evidence/baseline/environment.txt (script tự làm).
FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      nmap tcpdump curl openssl ca-certificates \
      iputils-ping dnsutils iproute2 netcat-openbsd \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /evidence
CMD ["sleep", "infinity"]
