// SPDX-License-Identifier: GPL-3.0-only

use i18n_embed::fluent::{FluentLanguageLoader, fluent_language_loader};
use i18n_embed::{DefaultLocalizer, LanguageLoader, Localizer};
use rust_embed::RustEmbed;
use std::sync::OnceLock;

#[derive(RustEmbed)]
#[folder = "i18n/"]
struct Localizations;

pub static LANGUAGE_LOADER: OnceLock<FluentLanguageLoader> = OnceLock::new();

/// WMDE: the gettext domain that translates the layout names of xkeyboard-config.
const XKB_TEXT_DOMAIN: &str = "xkeyboard-config";

#[macro_export]
macro_rules! fl {
    ($message_id:literal) => {{
        i18n_embed_fl::fl!($crate::localize::LANGUAGE_LOADER.get().unwrap(), $message_id)
    }};

    ($message_id:literal, $($args:expr),*) => {{
        i18n_embed_fl::fl!($crate::localize::LANGUAGE_LOADER.get().unwrap(), $message_id, $($args), *)
    }};
}

// Get the `Localizer` to be used for localizing this library.
pub fn localizer() -> Box<dyn Localizer> {
    LANGUAGE_LOADER.get_or_init(|| {
        let loader: FluentLanguageLoader = fluent_language_loader!();

        loader
            .load_fallback_language(&Localizations)
            .expect("Error while loading fallback language");

        loader
    });

    Box::from(DefaultLocalizer::new(
        LANGUAGE_LOADER.get().unwrap(),
        &Localizations,
    ))
}

pub fn localize() {
    let localizer = localizer();
    let requested_languages = i18n_embed::DesktopLanguageRequester::requested_languages();

    if let Err(error) = localizer.select(&requested_languages) {
        eprintln!("Error while loading language for App List {}", error);
    }

    bind_layout_names();
}

/// WMDE: the layout names come out of the catalog as UTF-8 whatever the character type of the
/// process, so Cyrillic is never transliterated.
fn bind_layout_names() {
    if let Err(why) = gettextrs::bind_textdomain_codeset(XKB_TEXT_DOMAIN, "UTF-8") {
        tracing::warn!("could not set the codeset of {XKB_TEXT_DOMAIN}: {why}");
    }
}

/// WMDE: a layout description in the language of the session. xkeyboard-config names layouts
/// in English and ships a gettext catalog for them, the one the keyboard page of Settings
/// reads. The catalog is read under a locale set for this call only: a process-wide setlocale
/// would also translate glibc's own messages for the log and the PAM prompts of the locker,
/// which the greeter, running PAM inside greetd, would still show in English.
pub fn layout_description(description: &str) -> String {
    // SAFETY: the locale object is created from the environment, installed for this thread
    // only, and the previous locale is restored before the object is freed.
    unsafe {
        let locale = libc::newlocale(
            libc::LC_MESSAGES_MASK | libc::LC_CTYPE_MASK,
            c"".as_ptr(),
            std::ptr::null_mut(),
        );
        if locale.is_null() {
            return description.to_owned();
        }
        let previous = libc::uselocale(locale);
        let translated = gettextrs::dgettext(XKB_TEXT_DOMAIN, description);
        libc::uselocale(previous);
        libc::freelocale(locale);
        translated
    }
}
