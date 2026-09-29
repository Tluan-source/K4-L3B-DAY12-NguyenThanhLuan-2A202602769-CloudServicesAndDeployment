# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Nguyễn Thành Luân |
| Mã học viên | 2A202602769 |
| Repo | https://github.com/Tluan-source/K4-L3B-DAY12-NguyenThanhLuan-2A202602769-CloudServicesAndDeployment.git |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-agent-2jjo.onrender.com |
| Platform | Render |
| Ngày deploy | 29/09/2026 |

> Public URL là địa chỉ HTTPS của web service `day12-agent`, không phải
> connection string Redis (`redis://...`).

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán (log: Uvicorn listen `0.0.0.0:10000`) |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard Render, không nằm trong repo |
| `REDIS_URL` | ✅ | gắn từ Redis service `day12-redis` qua Blueprint `render.yaml` |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

```bash
URL=https://day12-agent-2jjo.onrender.com

# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i $URL/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i $URL/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST $URL/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST $URL/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST $URL/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Output thu được từ service live ngày 29/09/2026:

```
# 1. GET /health
HTTP/1.1 200
content-type: application/json
server: cloudflare

{"status": "ok", "service": "day12-agent", "version": "1.0.0"}

# 2. GET /ready
HTTP/1.1 200
content-type: application/json
server: cloudflare

{"status": "ready", "redis": true}

# 3. POST /ask (no API key)
HTTP/1.1 401
content-type: application/json
server: cloudflare

{"detail": "invalid or missing API key"}

# 4. POST /ask (with API key)
HTTP/1.1 200
content-type: application/json
server: cloudflare

{"answer": "Ngắn gọn: Deploy la gi phụ thuộc vào ba yếu tố — cấu hình qua biến môi trường, health check để orchestrator biết trạng thái, và giới hạn tài nguyên.", "user_id": "sv-test", "history_length": 0, "cost_usd": 2.265e-05, "tokens": {"in": 3, "out": 37}}

# 5. Rate limit x15 (same user sv-test, limit 10/phút)
200 200 200 200 200 200 200 200 200 429 429 429 429 429 429
```

Giải thích ngắn: `/ready` có `"redis": true` → đã nối Redis trên Render.
Rate limit: các request đầu 200, từ request vượt hạn mức trả 429.

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service `day12-agent` trên Render
- `screenshots/health.png` — trình duyệt mở `https://day12-agent-2jjo.onrender.com/health` ra 200

> Hai file ảnh cần bạn tự chụp từ dashboard/trình duyệt rồi bỏ vào `screenshots/`
> (không commit secret trên ảnh).
