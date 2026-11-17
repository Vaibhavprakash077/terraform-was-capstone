FROM python:3.14-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /srv/app

COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt
COPY __init__.py ./app/__init__.py

RUN groupadd --gid 10001 app \
    && useradd --no-create-home --uid 10001 --gid app --shell /usr/sbin/nologin app
USER 10001:10001

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--access-logfile", "-", "--no-control-socket", "app:app"]
