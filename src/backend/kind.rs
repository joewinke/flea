use std::collections::HashMap;
use std::path::PathBuf;

const MIME_ROOT: &str = "/usr/share/mime";

// A per-process, per-type cache, so every type is read from disk at most once, see docs/protocol.md "rows".
pub struct Kinds {
    cache: HashMap<String, Option<String>>,
    reads: u32,
}

impl Kinds {
    pub fn new() -> Kinds {
        Kinds { cache: HashMap::new(), reads: 0 }
    }

    // Test-only: pre-seeds the cache so a test never depends on the box's own /usr/share/mime, the same reason rows.rs's dbs() uses literal strings.
    #[cfg(test)]
    pub fn from_pairs(pairs: &[(&str, Option<&str>)]) -> Kinds {
        let cache = pairs.iter().map(|(k, v)| (k.to_string(), v.map(str::to_string))).collect();
        Kinds { cache, reads: 0 }
    }

    // A human description of a MIME type, read lazily and cached for the life of the process.
    pub fn comment(&mut self, mime: &str) -> Option<String> {
        if let Some(hit) = self.cache.get(mime) {
            return hit.clone();
        }
        self.reads += 1;
        let value = read_comment(mime);
        self.cache.insert(mime.to_string(), value.clone());
        value
    }

    // What the cache-hit test asserts on, kept in shipped code on purpose: a cache with no observable hit count is a cache nobody can test.
    #[allow(dead_code)]
    pub fn reads(&self) -> u32 {
        self.reads
    }
}

// Sample input, /usr/share/mime/image/jpeg.xml: "<comment>JPEG image</comment>".
fn read_comment(mime: &str) -> Option<String> {
    let path = PathBuf::from(MIME_ROOT).join(format!("{}.xml", mime));
    let text = std::fs::read_to_string(path).ok()?;
    first_untranslated_comment(&text)
}

// The first <comment> carrying no xml:lang attribute, not the first <comment> of any kind, see docs/protocol.md "rows".
fn first_untranslated_comment(text: &str) -> Option<String> {
    let mut rest = text;
    loop {
        let start = rest.find("<comment")?;
        rest = &rest[start..];
        let tag_end = rest.find('>')?;
        let tag = &rest[..tag_end];
        rest = &rest[tag_end + 1..];
        if tag.contains("xml:lang") {
            continue;
        }
        let close = rest.find("</comment>")?;
        return Some(rest[..close].to_string());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn comment_reads_the_untranslated_string() {
        let mut db = Kinds::new();
        assert_eq!(db.comment("image/jpeg").as_deref(), Some("JPEG image"));
        // corner: a type with no XML answers None and the caller falls back to the icon name.
        assert_eq!(db.comment("application/x-nonexistent-type"), None);
    }

    #[test]
    fn a_translated_comment_first_does_not_win() {
        // msword.xml opens with zh-Hant-TW, so taking the first comment element renders Chinese here.
        let mut db = Kinds::new();
        assert_eq!(db.comment("application/msword").as_deref(), Some("Microsoft Word Document"));
    }

    #[test]
    fn a_type_with_no_untranslated_comment_answers_none() {
        // This box's x-ms-dos-executable.xml carries zero comment elements of any language.
        let mut db = Kinds::new();
        assert_eq!(db.comment("application/x-ms-dos-executable"), None);
    }

    #[test]
    fn comment_is_read_once_per_type() {
        let mut db = Kinds::new();
        let _ = db.comment("image/jpeg");
        let _ = db.comment("image/jpeg");
        assert_eq!(db.reads(), 1);
    }

    #[test]
    fn a_missing_mime_root_answers_none_not_a_panic() {
        assert_eq!(first_untranslated_comment(""), None);
        assert_eq!(first_untranslated_comment("<mime-type></mime-type>"), None);
    }

    #[test]
    fn from_pairs_never_touches_disk() {
        let mut db = Kinds::from_pairs(&[("text/plain", Some("Plain Text Document"))]);
        assert_eq!(db.comment("text/plain").as_deref(), Some("Plain Text Document"));
        // A pre-seeded entry is answered straight from the cache, so it costs no read.
        assert_eq!(db.reads(), 0);
    }
}
