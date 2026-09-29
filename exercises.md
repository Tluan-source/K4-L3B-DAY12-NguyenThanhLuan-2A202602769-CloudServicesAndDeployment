# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: viết câu trả lời ngay dưới mỗi câu hỏi (không để trống).
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Thành Luân  Mã học viên: 2A202602769

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Khi deploy lên Render, nếu quên set `AGENT_API_KEY` trên dashboard thì process
> chết ngay lúc startup với `ValidationError` (thiếu field bắt buộc). Health check
> của platform fail → mình biết ngay và vào Environment sửa. Nếu mặc định là
> `"changeme"`, app vẫn “xanh”, bot quét Internet gọi `/ask` bằng khóa mặc định
> đó, và mình chỉ phát hiện khi hóa đơn LLM tăng hoặc log đầy request lạ.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Một dòng log thật khi gọi `/ask` trên container:
> `{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T04:15:12.900567+00:00", "user_id": "sv-ex", "tokens_in": 4, "tokens_out": 42, "cost_usd": 2.58e-05}`
>
> Hai việc làm được mà `print("đã trả lời xong")` không làm được:
> (1) Lọc/tổng hợp theo field có cấu trúc — ví dụ cộng `cost_usd` theo `user_id`
> hoặc tìm mọi `ask_completed` trong khoảng thời gian nhờ `timestamp` ISO.
> (2) Đưa thẳng vào hệ thống log (Cloudflare/Render logs, Loki, ELK) vì mỗi dòng
> là một JSON hợp lệ trên một dòng, máy parse được; chuỗi văn xuôi tự do thì khó
> query ổn định.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1700 MB (`agent:single`, base `python:3.11` đầy đủ) |
| Multi-stage | 271 MB (`day12-agent:cp2-test` / image compose hiện tại, base `python:3.11-slim`) |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Chênh khoảng ~1.4 GB. Phần lớn là image base đầy đủ (`python:3.11` có nhiều
> công cụ hệ thống hơn `slim`) cộng với rác của giai đoạn cài đặt (pip cache,
> metadata build) nếu không tách stage. Multi-stage chỉ copy site-packages đã
> cài từ stage `builder` sang runtime slim, nên image cuối chỉ còn runtime cần
> thiết để chạy uvicorn.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Dockerfile hiện tại: `COPY requirements.txt` → `pip install` → sau đó mới
> `COPY app` / `COPY utils`. Sửa một ký tự trong `main.py` thì các layer
> requirements + pip install vẫn **cache**; chỉ các layer copy source (và phía
> sau) chạy lại. Nếu đưa `COPY . .` lên trước `pip install`, mỗi lần sửa code
> cũng làm mất cache pip → mỗi build cài lại toàn bộ dependency, rất chậm.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện: lỗ hổng trong app (ví dụ RCE qua input) → attacker chạy lệnh
> trong container với quyền **root** → lợi dụng mount/volume hoặc lỗi cấu hình
> runtime/escape để leo lên host với đặc quyền cao. Lệnh `USER appuser` cắt ở
> bước “process trong container là root”: dù khai thác được code, process chỉ
> chạy với user thường (uid 10001), giảm bề mặt leo thang quyền trong container.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa **20 request trong ~2 giây**. Cách làm: gửi 10 request lúc `xx:00:59`
> (hết hạn mức của phút hiện tại), sang `xx:01:01` bộ đếm reset theo phút đồng
> hồ nên gửi thêm 10 request nữa. Tổng 20 request sát nhau dù “mỗi phút chỉ 10”.
> Sliding window 60 giây không có khe hở kiểu này.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Rate limit giới hạn **số lượng** request theo thời gian (ví dụ 10/phút → 429).
> Cost guard giới hạn **số tiền** đã tiêu trong tháng (vượt budget → 402).
>
> Rate limit cho qua, cost guard chặn: user chỉ gọi 2 request/phút (dưới hạn)
> nhưng mỗi request rất đắt / đã tiêu gần hết `MONTHLY_BUDGET_USD` → 402.
>
> Cost guard cho qua, rate limit chặn: user còn nhiều ngân sách nhưng spam
> 15 request trong vài giây → các request cuối 429 dù tiền vẫn đủ.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Redis mất kết nối → cả 3 instance đều thấy probe “gộp” fail vì không ping được
> Redis → orchestrator coi cả 3 không healthy và **restart cả cụm** gần như cùng
> lúc → trong lúc Redis chưa kịp ổn định lại thì không còn instance nào phục vụ
> → sự cố Redis ngắn biến thành outage toàn bộ service. Tách `/health` (không
> phụ thuộc Redis) và `/ready` (có kiểm tra Redis) thì LB chỉ ngừng đẩy traffic
> vào instance chưa sẵn sàng, không restart cả đàn vì Redis nấc một nhịp.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Với 3 agent dùng chung Redis, mình gọi lần lượt các cổng khác nhau cùng
> `X-User-Id: sv01` thì `history_length` **tăng dần** (quan sát thực tế khoảng
> 6 → 8 → 10) vì mọi container đọc/ghi cùng key lịch sử. Nếu lưu trong dict
> Python trong RAM từng process, mỗi request rơi vào container khác sẽ thấy
> lịch sử “nhảy” hoặc reset về 0 — agent mất trí nhớ tùy instance nào nhận
> request.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lỗi ban đầu khi điền `DEPLOYMENT.md`: mình ghi Public URL là
> `redis://red-....:6379` (connection string của Redis add-on) thay vì URL HTTPS
> của web service. `pytest tests/test_cp5.py` báo không tìm thấy URL HTTPS hợp lệ
> / không gọi được service. Nguyên nhân: nhầm service Redis với web
> `day12-agent`. Cách sửa: vào Render dashboard → service **day12-agent** → copy
> `https://day12-agent-2jjo.onrender.com`, cập nhật `DEPLOYMENT.md`, kiểm tra
> `/health` và `/ready` đều 200.
