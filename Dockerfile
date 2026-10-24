# 基础镜像默认跟随 soulter/astrbot:latest；
# CI 会将其覆盖为锁定文件中的 digest：
#   稳定通道 .upstream/latest.lock
#   nightly 通道 .upstream/nightly-latest.lock
# （由 .github/workflows/sync-upstream.yml 自动更新）
ARG BASE_IMAGE=soulter/astrbot:latest
FROM ${BASE_IMAGE}

USER root

COPY astrbot-extra-requirements.txt /tmp/astrbot-extra-requirements.txt

RUN python -m pip install --no-cache-dir --prefer-binary -U pip \
    && python -m pip install --no-cache-dir --prefer-binary -r /tmp/astrbot-extra-requirements.txt \
    && rm -f /tmp/astrbot-extra-requirements.txt
