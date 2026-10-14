name := 'wmde-greeter'
export APPID := 'fun.wmde.Greeter'
# Чтобы shell() работал и на Windows с Git Bash; на Linux игнорируется
set windows-shell := ["C:\\Program Files\\Git\\bin\\sh.exe", "-cu"]

rootdir := ''
prefix := '/usr'
sysconfdir := '/etc'

base-dir := absolute_path(clean(rootdir / prefix))
etc-dir := absolute_path(clean(rootdir / sysconfdir))

export INSTALL_DIR := base-dir / 'share'

cargo-target-dir := env('CARGO_TARGET_DIR', 'target')
bin-src := cargo-target-dir / 'release' / name
bin-dst := base-dir / 'bin' / name

# Systemd sysusers/tmpfiles components directories
lib-dir := base-dir / 'lib'

# WMDE keeps its packaging data in data/; upstream reads these two out of debian/,
# which was dropped along with the rest of the Debian packaging.
# sysusers.d
sysusers-src := 'data' / name + '.sysusers'
sysusers-dst := lib-dir / 'sysusers.d' / name + '.conf'
# tmpfiles.d
tmpfiles-src := 'data' / name + '.tmpfiles'
tmpfiles-dst := lib-dir / 'tmpfiles.d' / name + '.conf'

# systemd units, greetd config and the PAM stack: upstream leaves these to the
# distribution packaging, we ship them ourselves.
unit-dir := lib-dir / 'systemd' / 'system'
greeter-unit-src := 'data' / name + '.service'
greeter-unit-dst := unit-dir / name + '.service'
daemon-unit-src := 'data' / name + '-daemon.service'
daemon-unit-dst := unit-dir / name + '-daemon.service'
greetd-src := 'data' / name + '.toml'
greetd-dst := etc-dir / 'greetd' / name + '.toml'
pam-src := 'data' / name + '.pam'
pam-dst := etc-dir / 'pam.d' / name

# The picture behind both screens. Read at runtime by src/common.rs, so replacing this file
# is all it takes to change the look - no rebuild.
background-src := 'data' / 'background.jpg'
background-dst := base-dir / 'share' / name / 'background.jpg'

daemon-src := cargo-target-dir / 'release' / name + '-daemon'
daemon-dst := base-dir / 'bin' / name + '-daemon'

start-src := name + '-start.sh'
start-dst := base-dir / 'bin' / name + '-start'

dbus-src := 'dbus' / APPID + '.conf'
dbus-dst := base-dir / 'share' / 'dbus-1' / 'system.d' / APPID + '.conf'

# Default recipe which runs `just build-release`
default: build-release

# Runs `cargo clean`
clean:
    cargo clean

# `cargo clean` and removes vendored dependencies
clean-dist: clean
    rm -rf .cargo vendor vendor.tar

# Compiles with debug profile
build-debug *args:
    cargo build --all {{args}}

# Compiles with release profile
build-release *args: (build-debug '--release' args)

# Compiles release profile with vendored dependencies
build-vendored *args: vendor-extract (build-release '--frozen --offline' args)

# Runs a clippy check
check *args:
    cargo clippy --all-features {{args}} -- -W clippy::pedantic

# Runs a clippy check with JSON message format
check-json: (check '--message-format=json')

mock:
    cargo build --release --example server
    wmde-comp {{cargo-target-dir}}/release/examples/server

# Run with debug logs
run *args:
    env RUST_LOG=debug RUST_BACKTRACE=full cargo run --release {{args}}

# The two roles of this binary ship as two packages, so `just install` is split the same way.
# See the PKGBUILD: a machine that only wants the screen locker must not be made to install
# greetd and a display manager it will never enable.

# The locker role: the binary, its PAM stack and the picture. This is what a WMDE session needs.
install-locker:
    install -Dm0755 {{bin-src}} {{bin-dst}}
    install -Dm0644 {{pam-src}} {{pam-dst}}
    install -Dm0644 {{background-src}} {{background-dst}}

# The greeter role: everything that only matters when this is the display manager.
install-dm:
    install -Dm0755 {{start-src}} {{start-dst}}
    install -Dm0755 {{daemon-src}} {{daemon-dst}}
    install -Dm0644 {{dbus-src}} {{dbus-dst}}
    install -Dm0644 {{sysusers-src}} {{sysusers-dst}}
    install -Dm0644 {{tmpfiles-src}} {{tmpfiles-dst}}
    install -Dm0644 {{greeter-unit-src}} {{greeter-unit-dst}}
    install -Dm0644 {{daemon-unit-src}} {{daemon-unit-dst}}
    install -Dm0644 {{greetd-src}} {{greetd-dst}}

# Installs files
install: install-locker install-dm

# Uninstalls installed files
uninstall:
    rm {{start-dst}} {{bin-dst}} {{daemon-dst}} {{dbus-dst}} {{sysusers-dst}} {{tmpfiles-dst}} \
       {{greeter-unit-dst}} {{daemon-unit-dst}} {{greetd-dst}} {{pam-dst}} {{background-dst}}

# Vendor dependencies locally
vendor:
    #!/usr/bin/env sh
    mkdir -p .cargo
    cargo vendor --sync Cargo.toml | head -n -1 > .cargo/config.toml
    echo 'directory = "vendor"' >> .cargo/config.toml
    echo >> .cargo/config.toml
    echo '[env]' >> .cargo/config.toml
    if [ -z "${SOURCE_DATE_EPOCH}" ]; then
        SOURCE_DATE_EPOCH=$(git log -1 --format='%ct')
    fi
    if [ -z "${SOURCE_GIT_HASH}" ]; then
        SOURCE_GIT_HASH=$(git rev-parse HEAD)
    fi
    source_date="$(date -d "@${SOURCE_DATE_EPOCH}" "+%Y-%m-%d")"
    echo "VERGEN_GIT_COMMIT_DATE = \"${source_date}\"" >> .cargo/config.toml
    echo "VERGEN_GIT_SHA = \"${SOURCE_GIT_HASH}\"" >> .cargo/config.toml
    tar pcf vendor.tar .cargo vendor
    rm -rf .cargo vendor

# Extracts vendored dependencies
vendor-extract:
    rm -rf vendor
    tar pxf vendor.tar

# Версия пакета как pkgver() в PKGBUILD: 1.10.0.<commits>.g<sha>.
# Теги epoch-* дают только счётчик через git describe, fallback — rev-list.
wmde-version := shell('desc=$(git describe --long --tags --abbrev=7 2>/dev/null || true); if [ -n "$desc" ]; then printf "1.10.0.%s.g%s" "$(printf "%s" "$desc" | sed -E "s/.*-([0-9]+)-g[0-9a-f]+$/\\1/")" "$(git rev-parse --short=7 HEAD)"; else printf "1.10.0.%s.g%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short=7 HEAD)"; fi')
# CPU-baseline: пусто = чистый x86-64 (для deb/rpm по умолчанию), для v3: WMDE_CPU=x86-64-v3
wmde-cpu := env('WMDE_CPU', '')

# Раскладывает собранное в target/staging (тот же набор, что PKGBUILD кладёт в $pkgdir:
# just install ставит ОБЕ роли сразу, nFPM-конфиги режут стейджинг на два пакета).
package-staging staging="target/staging":
    #!/usr/bin/env bash
    set -e
    rm -rf {{staging}}
    if [ -n "{{wmde-cpu}}" ]; then export RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS }-C target-cpu={{wmde-cpu}}"; fi
    # rust-toolchain.toml пинит 1.93, но lockfile уже требует новее (kdl) —
    # пин СЛОМАН и для автора тоже, перекрываем stable (см. INSTALL)
    export RUSTUP_TOOLCHAIN=stable
    just build-release
    just rootdir="{{staging}}" prefix=/usr install
    # makepkg на Arch стрипает бинарники сам, в deb/rpm это делаем руками
    strip --strip-unneeded "{{staging}}/usr/bin/"* 2>/dev/null || true
    just package-doc "{{staging}}"

# doc для deb/rpm: копирайт + changelog.yaml (nFPM сам разложит changelog
# в changelog.Debian.gz для deb и в %changelog для rpm).
# Doc-каталога два (по числу пакетов), готовит один рецепт.
package-doc staging="target/staging":
    #!/usr/bin/env bash
    set -e
    for doc in wmde-greeter wmde-greeter-dm; do \
        mkdir -p "{{staging}}/usr/share/doc/$doc"; \
        cp packaging/copyright "{{staging}}/usr/share/doc/$doc/copyright"; \
        chmod 644 "{{staging}}/usr/share/doc/$doc/copyright"; \
    done
    printf -- '- semver: %s\n  date: %s\n  packager: WMDE <wmde@wmde.fun>\n  urgency: low\n  distribution: unstable\n  deb:\n    urgency: low\n    distributions:\n      - unstable\n  changes:\n    - note: Automated build via nFPM (see INSTALL.deb-rpm.md).\n' "{{wmde-version}}-1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > target/changelog.yaml

# Стейджинг из вендора: сборка без сети к git-зависимостям.
# vendor.tar генерим один раз при наличии сети (`just vendor`), сам тарболл
# в git не коммитится (см. .gitignore), на офлайн-машину его привозим файлом.
package-staging-vendored staging="target/staging":
    #!/usr/bin/env bash
    set -e
    rm -rf {{staging}}
    if [ ! -f vendor.tar ]; then just vendor; fi
    if [ -n "{{wmde-cpu}}" ]; then export RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS }-C target-cpu={{wmde-cpu}}"; fi
    export RUSTUP_TOOLCHAIN=stable
    just build-vendored # сам распакует vendor.tar и соберёт --frozen --offline
    just rootdir="{{staging}}" prefix=/usr install
    strip --strip-unneeded "{{staging}}/usr/bin/"* 2>/dev/null || true
    just package-doc "{{staging}}"
    rm -rf vendor .cargo

# Собирает .deb через nFPM (нужен nfpm в PATH): СРАЗУ ОБА пакета, локер и DM.
deb:
    #!/usr/bin/env bash
    set -e
    just package-staging
    export WMDE_VERSION="{{wmde-version}}"
    nfpm package --config packaging/nfpm-greeter.yaml --packager deb --target target/
    nfpm package --config packaging/nfpm-dm.yaml --packager deb --target target/

# Собирает .rpm через nFPM (нужен nfpm в PATH): СРАЗУ ОБА пакета, локер и DM.
rpm:
    #!/usr/bin/env bash
    set -e
    just package-staging
    export WMDE_VERSION="{{wmde-version}}"
    nfpm package --config packaging/nfpm-greeter.yaml --packager rpm --target target/
    nfpm package --config packaging/nfpm-dm.yaml --packager rpm --target target/

# .deb из вендора (офлайн-сборка): оба пакета.
deb-vendored:
    #!/usr/bin/env bash
    set -e
    just package-staging-vendored
    export WMDE_VERSION="{{wmde-version}}"
    nfpm package --config packaging/nfpm-greeter.yaml --packager deb --target target/
    nfpm package --config packaging/nfpm-dm.yaml --packager deb --target target/

# .rpm из вендора (офлайн-сборка): оба пакета.
rpm-vendored:
    #!/usr/bin/env bash
    set -e
    just package-staging-vendored
    export WMDE_VERSION="{{wmde-version}}"
    nfpm package --config packaging/nfpm-greeter.yaml --packager rpm --target target/
    nfpm package --config packaging/nfpm-dm.yaml --packager rpm --target target/
