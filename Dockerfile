# CP2 — Production Dockerfile (multi-stage)
#
# builder  : cài dependency (có thể nặng, bị bỏ sau khi build)
# runtime  : chỉ nhận kết quả pip + source → image nhỏ, non-root

# ── Stage 1: builder ──────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime ─────────────────────────────────────────
FROM python:3.11-slim AS runtime

WORKDIR /app

# Chỉ mang site-packages đã cài từ builder (không mang pip cache / compiler)
COPY --from=builder /install /usr/local

# Tạo user thường — không chạy container bằng root
RUN useradd --create-home --uid 10001 appuser

# Source sau pip install → sửa code không làm mất cache layer dependency
COPY app ./app
COPY utils ./utils

USER appuser

ENV PORT=8000
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

# 0.0.0.0 = nhận traffic từ ngoài container; ${PORT:-8000} = cloud tự gán cổng
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
