FROM python:3.12-slim

RUN pip install --no-cache-dir \
    flake8==7.1.1 \
    black==24.10.0 \
    isort==5.13.2 \
    mypy==1.13.0 \
    pytest==8.3.3

COPY Gauntlets/ /gauntlet/
RUN chmod +x /gauntlet/python_gauntlet.sh

WORKDIR /workspace