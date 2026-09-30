#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p vendor build/tools
if [ ! -d vendor/libebur128/.git ]; then
  git clone https://github.com/jiixyj/libebur128.git vendor/libebur128
fi
git -C vendor/libebur128 checkout --detach 67b33abe1558160ed76ada1322329b0e9e058b02
if [ ! -d vendor/vst3sdk/.git ]; then
  git clone https://github.com/steinbergmedia/vst3sdk.git vendor/vst3sdk
fi
git -C vendor/vst3sdk checkout --detach 3cdf9ca5d1f5b1b21e0a86832aa4abe55607bd96
git -C vendor/vst3sdk submodule update --init base pluginterfaces public.sdk cmake
if [ ! -x build/tools/cmake/data/bin/cmake ]; then
  python3 -m pip install --target build/tools cmake==4.4.3
fi
