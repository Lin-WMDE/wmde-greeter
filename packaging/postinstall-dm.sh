#!/bin/sh
# Ничего не включаем: юниты едут выключенными (см. PKGBUILD), только reload.
set -e
command -v systemctl >/dev/null 2>&1 && systemctl daemon-reload || true
