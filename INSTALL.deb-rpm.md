# Установка на deb/rpm-дистрибутивах без сборки из сырцов вручную

Шаблон: см. предыдущие компоненты. Автор собирает пакеты у себя локально, как сейчас `makepkg -si`.

Опорные платформы — Debian stable и Fedora: `.deb` собираем на Debian (встаёт и на Ubuntu/Mint),
`.rpm` — на Fedora (встаёт и на RHEL/openSUSE). Наоборот не гарантируется.

Тулчейн: `rust-toolchain.toml` пинит 1.93, но lockfile уже требует новее (`kdl`) —
пин сломан и для обычной сборки тоже, наши рецепты перекрывают его через
`RUSTUP_TOOLCHAIN=stable` (как системный rust в Arch). Починить пин — автору.

## Два пакета из одного репозитория

Роли бинаря разъеханы по пакетам, как в PKGBUILD: локер тянет только wayland/xkb/pam,
а greetd, юниты и конфиги живут отдельно. `just deb` / `just rpm` собирают СРАЗУ ОБА:

- `wmde-greeter` — локер: бинарь, его PAM-стек, картинка. Это всё что нужно сессии.
- `wmde-greeter-dm` — display manager: демон, старт-скрипт, D-Bus-политика,
  sysusers/tmpfiles, оба юнита, конфиг greetd. Юниты едут ВЫКЛЮЧЕННЫМИ:
  включается руками через `systemctl enable wmde-greeter.service`.

## Собрать

```sh
# зависимости сборки: rustc stable (пин 1.93 сломан, см. ниже) cargo just clang lld pkgconf wayland pam libclang + nfpm
cargo install --locked nfpm  # или бинарник с github.com/goreleaser/nfpm/releases

just deb   # -> target/wmde-greeter_*.deb + target/wmde-greeter-dm_*.deb
just rpm   # -> target/wmde-greeter-*.rpm + target/wmde-greeter-dm-*.rpm
```

Версия — `1.10.0.<commits>.g<sha>`, как `pkgver()` в `PKGBUILD`.
По умолчанию сборка под чистый `x86-64`. Опционально под `x86-64-v3` (как в Arch-репозитории):

```sh
WMDE_CPU=x86-64-v3 just deb
```

## Исходники рядом

Обычная сборка требует соседние чек-ауты (path-зависимости Cargo):

```
work/
  wmde-greeter/                <- этот репозиторий (ветка wmde)
  libcosmic/                   <- git clone -b wmde https://github.com/Lin-WMDE/libcosmic.git
  wmde-bg/                     <- git clone -b wmde https://github.com/Lin-WMDE/wmde-bg.git
  wmde-comp/                   <- git clone -b wmde https://github.com/Lin-WMDE/wmde-comp.git
  wmde-applets/                <- git clone -b wmde https://github.com/Lin-WMDE/wmde-applets.git
  wmde-settings-daemon/        <- git clone -b wmde https://github.com/Lin-WMDE/wmde-settings-daemon.git
  wmde-settings/               <- git clone -b wmde https://github.com/Lin-WMDE/wmde-settings.git
  wmde-randr/                  <- git clone -b wmde https://github.com/Lin-WMDE/wmde-randr.git
  wmde-dbus-settings-bindings/ <- git clone -b wmde https://github.com/Lin-WMDE/wmde-dbus-settings-bindings.git
```

## Офлайн-сборка (без сети к git-зависимостям)

`vendor.tar` в git не лежит (см. `.gitignore`), генерим на машине с сетью один раз:

```sh
just vendor          # -> vendor.tar (реестр + git-крейты)
just deb-vendored    # сборка --frozen --offline -> target/*.deb (оба пакета)
just rpm-vendored    # аналогично -> target/*.rpm
```

На машину без сети привозим `vendor.tar` файлом.

## Поставить

```sh
# Debian/Ubuntu/Mint
sudo apt install ./target/wmde-greeter_*.deb
# и при желании отдельно:
sudo apt install ./target/wmde-greeter-dm_*.deb

# Fedora/RHEL/openSUSE
sudo dnf install ./target/wmde-greeter-*.rpm
```

Пакеты WMDE в `-dm` идут в recommends (их пока нет в репозиториях дистрибутивов).
PAM-конфиг локера и toml greetd едут как conffiles (`config|noreplace`) — правки переживут обновления.
