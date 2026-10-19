# Maintainer: WMDE <https://wmde.fun>
# Contributor: System76 <info@system76.com> (original cosmic-greeter)
#
# Builds our fork Lin-WMDE/wmde-greeter (branch wmde). One binary with two roles,
# chosen by the effective user (src/main.rs): as the system user wmde-greeter it is
# the greetd greeter, as anyone else it is the ext-session-lock client.
#
# Split into two packages along that same line, because the roles have very different
# costs. A WMDE session needs the LOCKER, so wmde-session depends on `wmde-greeter` -
# and that package pulls nothing but wayland, xkbcommon and pam. The display manager
# lives in `wmde-greeter-dm`: greetd, the root daemon, the system user, the units.
# Nobody depends on it. Someone running WMDE under GDM or SDDM gets a working lock
# screen and is never made to install a second display manager.
#
# Installing wmde-greeter-dm still does not make it THE display manager: the unit ships
# disabled, and `systemctl enable wmde-greeter.service` is what claims the
# display-manager.service alias. systemd refuses to take that alias from an enabled GDM
# without --force, so the two can coexist.
pkgbase=wmde-greeter
pkgname=('wmde-greeter' 'wmde-greeter-dm')
pkgver=0.1.0
pkgrel=1
arch=('x86_64')
url="https://wmde.fun"
license=('GPL-3.0-only')
makedepends=('rust' 'cargo' 'just' 'git' 'clang' 'lld' 'pkgconf' 'wayland' 'libxkbcommon' 'pam')
source=("$pkgbase::git+https://github.com/Lin-WMDE/wmde-greeter.git#branch=wmde")
sha256sums=('SKIP')

pkgver() {
  cd "$srcdir/$pkgbase"
  # WMDE version: <COSMIC major.minor>.<WMDE release>.<commits since the nearest tag>.g<short>.
  local desc
  desc=$(git describe --long --tags --abbrev=7 2>/dev/null || true)
  if [ -n "$desc" ]; then
    printf '1.10.3.%s.g%s' "$(printf '%s' "$desc" | sed -E 's/.*-([0-9]+)-g[0-9a-f]+$/\1/')" "$(git rev-parse --short=7 HEAD)"
  else
    printf '1.10.3.%s.g%s' "$(git rev-list --count HEAD)" "$(git rev-parse --short=7 HEAD)"
  fi
}

build() {
  cd "$srcdir/$pkgbase"
  # x86-64-v3 (AVX2/BMI2) baseline for the WMDE repo; runs on Haswell+ (and the VM).
  export RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS }-C target-cpu=x86-64-v3"
  just build-release
}

package_wmde-greeter() {
  pkgdesc="WMDE screen locker (fork of cosmic-greeter)"
  # No greetd and no wmde-comp here: the locker is a plain Wayland client of whatever
  # compositor already runs the session, it execs nothing and it does not talk to the
  # greeter daemon.
  depends=('glibc' 'gcc-libs' 'wayland' 'libxkbcommon' 'pam')
  optdepends=('wmde-greeter-dm: use WMDE as the display manager too')
  backup=('etc/pam.d/wmde-greeter')
  cd "$srcdir/$pkgbase"
  # installs /usr/bin/wmde-greeter, /etc/pam.d/wmde-greeter and the background picture
  just rootdir="$pkgdir" prefix=/usr install-locker
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  install -Dm644 data/background.jpg.license \
    "$pkgdir/usr/share/licenses/$pkgname/background.jpg.license"
}

package_wmde-greeter-dm() {
  pkgdesc="WMDE greeter for greetd - owns fun.wmde.Greeter"
  # wmde-greeter-start execs `wmde-comp wmde-greeter`, greetd drives the whole thing.
  # wmde-greetd, not Arch's greetd: wmde-greeter.toml sets session_vt, which only it has.
  depends=("wmde-greeter=$pkgver-$pkgrel" 'glibc' 'gcc-libs' 'wmde-greetd' 'wmde-comp'
           'wmde-icons-base')
  optdepends=('wmde-randr: remember per-output layout at the greeter'
              'networkmanager: network status on the greeter'
              'upower: battery status on the greeter')
  backup=('etc/greetd/wmde-greeter.toml')
  cd "$srcdir/$pkgbase"
  # installs the daemon, the start script, the D-Bus policy, sysusers/tmpfiles, both
  # systemd units and /etc/greetd/wmde-greeter.toml
  just rootdir="$pkgdir" prefix=/usr install-dm
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
