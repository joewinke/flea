use std::collections::HashMap;

pub struct Aliases {
    to_canonical: HashMap<String, String>,
}

const ALIASES: &str = "/usr/share/mime/aliases";

impl Aliases {
    pub fn load() -> Aliases {
        match std::fs::read_to_string(ALIASES) {
            Ok(text) => Aliases::from_str(&text),
            Err(_) => Aliases::from_str(""),
        }
    }

    // Sample input, /usr/share/mime/aliases: "image/heic image/heif", the alias first, then its canonical name.
    pub fn from_str(text: &str) -> Aliases {
        let mut to_canonical = HashMap::new();
        // corner: a blank, comment or spaceless line is skipped; see AGENTS.md "MIME aliases".
        for line in text.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            if let Some((alias, canonical)) = line.split_once(' ') {
                let alias = alias.trim();
                let canonical = canonical.trim();
                if !alias.is_empty() && !canonical.is_empty() {
                    to_canonical.insert(alias.to_string(), canonical.to_string());
                }
            }
        }
        Aliases { to_canonical }
    }

    // Returns a borrow of the input when there is no alias, so a caller pays no allocation per row.
    pub fn canonical<'a>(&'a self, mime: &'a str) -> &'a str {
        match self.to_canonical.get(mime) {
            Some(c) => c,
            None => mime,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn a() -> Aliases {
        Aliases::load()
    }

    #[test]
    fn an_alias_resolves_to_its_canonical_name() {
        let a = a();
        assert_eq!(a.canonical("image/heic"), "image/heif");
        assert_eq!(a.canonical("video/x-matroska"), "video/matroska");
    }

    #[test]
    fn a_canonical_name_is_returned_unchanged() {
        let a = a();
        assert_eq!(a.canonical("image/heif"), "image/heif");
        assert_eq!(a.canonical("video/matroska"), "video/matroska");
    }

    #[test]
    fn an_unknown_type_is_returned_unchanged() {
        let a = a();
        assert_eq!(a.canonical("nonsense/nothing"), "nonsense/nothing");
        assert_eq!(a.canonical(""), "");
    }

    #[test]
    fn the_two_sides_of_a_pair_compare_equal_through_canonical() {
        let a = a();
        assert_eq!(a.canonical("image/heic"), a.canonical("image/heif"));
        assert_eq!(a.canonical("video/x-matroska"), a.canonical("video/matroska"));
    }

    #[test]
    fn a_missing_file_is_empty_not_a_panic() {
        let a = Aliases::from_str("");
        assert_eq!(a.canonical("image/heic"), "image/heic");
    }

    #[test]
    fn a_malformed_line_is_skipped_not_a_panic() {
        let a = Aliases::from_str("noSpaceHere\n\nimage/heic image/heif\n  \n");
        assert_eq!(a.canonical("image/heic"), "image/heif");
        assert_eq!(a.canonical("noSpaceHere"), "noSpaceHere");
    }
}
