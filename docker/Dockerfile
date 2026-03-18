FROM python:3.10-slim

ARG DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y \
    gcc libpq-dev \
    python3-dev \
    libjpeg-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/status-page

COPY requirements.txt /opt/status-page/

RUN pip install --upgrade pip wheel
RUN pip install -r requirements.txt

COPY . /opt/status-page/

EXPOSE 8000

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh


ENTRYPOINT ["/entrypoint.sh"]

CMD ["python3", "-m", "gunicorn", "--chdir", "statuspage", "--bind", "0.0.0.0:8000", "statuspage.wsgi:application"]