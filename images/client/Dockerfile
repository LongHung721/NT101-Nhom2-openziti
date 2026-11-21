# Máy "người dùng hợp lệ" của lab: chỉ cần curl để tạo lưu lượng HTTP.
ARG ALPINE_VERSION=3.20
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache curl ca-certificates

CMD ["sleep", "infinity"]
