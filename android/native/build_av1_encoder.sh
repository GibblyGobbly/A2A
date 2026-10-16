#!/usr/bin/env bash
# Builds the on-device AV1 encoder: a small static FFmpeg command-line binary
# with SVT-AV1 for arm64-v8a. The bundled ffmpeg-kit build has no AV1 encoder,
# and most phones (including Snapdragon 8 Elite) have no hardware AV1 encoder,
# so AV1 is encoded on the CPU with SVT-AV1, which uses every core.
#
# Output: android/app/src/main/jniLibs/arm64-v8a/libffmpeg_av1.so
# (named lib*.so so Android installs it into the app's native library
# directory, the only app location where executables may run).
#
# Usage: android/native/build_av1_encoder.sh [work_dir]
# Requires: Android NDK (ANDROID_NDK_HOME or $ANDROID_HOME/ndk/<version>), cmake, ninja, make, git.
set -euo pipefail

SVT_TAG=v4.2.0
FFMPEG_TAG=n9.0.2
API=24

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${1:-$ROOT/build/av1_encoder}"
OUT="$ROOT/android/app/src/main/jniLibs/arm64-v8a/libffmpeg_av1.so"

NDK="${ANDROID_NDK_HOME:-$(ls -d "${ANDROID_HOME:-$HOME/Android/Sdk}"/ndk/* | sort -V | tail -1)}"
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
CC="$TOOLCHAIN/bin/aarch64-linux-android$API-clang"
CXX="$TOOLCHAIN/bin/aarch64-linux-android$API-clang++"
PREFIX="$WORK/prefix"
JOBS="$(nproc)"

mkdir -p "$WORK" "$PREFIX"
cd "$WORK"

[ -d SVT-AV1 ] || git clone --depth 1 --branch "$SVT_TAG" https://gitlab.com/AOMediaCodec/SVT-AV1.git
[ -d FFmpeg ] || git clone --depth 1 --branch "$FFMPEG_TAG" https://github.com/FFmpeg/FFmpeg.git

# SVT-AV1: static library with NEON kernels, no apps or tests.
cmake -S SVT-AV1 -B svt-build -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_APPS=OFF -DBUILD_TESTING=OFF -DBUILD_DEC=OFF \
  -DCOMPILE_C_ONLY=OFF
cmake --build svt-build -j "$JOBS"
cmake --install svt-build

# FFmpeg: only what the AV1 path needs. Inputs are common phone and web
# formats; output is AV1 + AAC in MP4.
cd FFmpeg
PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig" ./configure \
  --prefix="$PREFIX" \
  --target-os=android --arch=aarch64 --cpu=armv8-a --enable-cross-compile \
  --cc="$CC" --cxx="$CXX" \
  --ar="$TOOLCHAIN/bin/llvm-ar" --nm="$TOOLCHAIN/bin/llvm-nm" \
  --ranlib="$TOOLCHAIN/bin/llvm-ranlib" --strip="$TOOLCHAIN/bin/llvm-strip" \
  --pkg-config=pkg-config --pkg-config-flags=--static \
  --extra-ldflags="-static-libstdc++" --extra-libs="-lc++_static -lc++abi -lm" \
  --enable-pic --enable-static --disable-shared \
  --disable-debug --disable-doc --disable-ffplay --disable-ffprobe \
  --disable-autodetect --disable-network --disable-everything \
  --enable-gpl --enable-libsvtav1 \
  --enable-protocol=file,pipe \
  --enable-demuxer=mov,matroska,avi,flv,mpegts,gif,image2 \
  --enable-decoder=h264,hevc,vp8,vp9,mpeg4,h263,mjpeg,gif,png,aac,aac_latm,mp3,mp3float,opus,vorbis,flac,ac3,eac3,alac,amrnb,amrwb,pcm_s16le,pcm_s24le,pcm_f32le \
  --enable-parser=h264,hevc,vp8,vp9,mpeg4video,aac,aac_latm,mpegaudio,opus,vorbis,flac,ac3,av1 \
  --enable-encoder=libsvtav1,aac \
  --enable-muxer=mp4,mov \
  --enable-bsf=aac_adtstoasc,extract_extradata,av1_metadata \
  --enable-filter=scale,format,transpose,hflip,vflip,aresample,aformat,anull,null,setsar,fps,trim,atrim \
  --enable-swscale --enable-swresample
make -j "$JOBS" ffmpeg
"$TOOLCHAIN/bin/llvm-strip" -o "$OUT" ffmpeg
echo "Built $OUT ($(du -h "$OUT" | cut -f1))"
