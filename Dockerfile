FROM debian:12.6-slim AS builder

RUN apt-get update && apt-get install -y \
    libpulse-dev libdrm-dev libglm-dev libstb-dev libegl-dev libgles-dev libvulkan-dev vulkan-validationlayers-dev \
    git xz-utils cmake sudo build-essential meson

RUN curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain stable -y
ENV PATH=/root/.cargo/bin:$PATH

WORKDIR /sources

RUN git clone https://gitlab.com/qemu-project/qemu.git
WORKDIR /sources/qemu
RUN git checkout v9.0.1
RUN mkdir -p build/deps/prefix
WORKDIR /sources/qemu/build/deps

# Development prefix tree
ENV PREFIX=/sources/qemu/build/deps/prefix
ENV CMAKE_INSTALL_PREFIX=$PREFIX
ENV PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib/x86_64-linux-gnu/pkgconfig"

RUN git clone https://android.googlesource.com/platform/hardware/google/aemu
WORKDIR aemu
RUN git checkout v0.1.2-aemu-release
RUN cmake -DAEMU_COMMON_GEN_PKGCONFIG=ON \
    -DAEMU_COMMON_BUILD_CONFIG=gfxstream \
    -DENABLE_VKCEREAL_TESTS=OFF \
    --install-prefix "$PREFIX" \
    -B build
RUN cmake --build build -j
RUN cmake --install build --prefix "$CMAKE_INSTALL_PREFIX"
WORKDIR /sources/qemu/build/deps

RUN git clone https://android.googlesource.com/platform/hardware/google/gfxstream.git
WORKDIR gfxstream
RUN git checkout v0.1.2-gfxstream-release
RUN meson setup -Ddefault_library=static --prefix "$PREFIX" build/
RUN meson install -C build
WORKDIR /sources/qemu/build/deps


RUN git clone https://chromium.googlesource.com/crosvm/crosvm.git
WORKDIR crosvm
RUN git checkout v0.1.3-rutabaga-release
RUN ./tools/install-deps
WORKDIR rutabaga_gfx/ffi/
RUN make
RUN make prefix="$PREFIX" install

WORKDIR /sources/qemu/build
ENV CFLAGS="-I$PREFIX/include -L$PREFIX/lib"
RUN ../configure --enable-system --enable-tools --enable-vhost-user --enable-slirp --enable-kvm --enable-debug --target-list=x86_64-softmmu --enable-rutabaga-gfx
RUN make -j$(nproc)
