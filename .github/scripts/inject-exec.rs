use nixy_tools::Result;
use regex::Regex;
use std::process::Command;

fn inject(content: &str, mut execute: impl FnMut(&str) -> Result<String>) -> Result<String> {
    let blocks = Regex::new(r"(?s)<!-- exec: (.+?) -->.*?<!-- endexec -->")?;
    let markers = Regex::new(r"<!-- exec: .+? -->\n?|<!-- endexec -->\n?")?;
    let mut result = String::new();
    let mut end = 0;
    for capture in blocks.captures_iter(content) {
        let whole = capture.get(0).unwrap();
        result.push_str(&content[end..whole.start()]);
        let command = capture[1].trim();
        let output = execute(command)?;
        let output = markers.replace_all(&output, "");
        result.push_str(&format!("<!-- exec: {command} -->\n{output}"));
        if !output.is_empty() && !output.ends_with('\n') {
            result.push('\n');
        }
        result.push_str("<!-- endexec -->");
        end = whole.end();
    }
    result.push_str(&content[end..]);
    Ok(result)
}

fn run() -> Result {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if args.len() == 1 && args[0] == "--help" {
        println!(
            "Usage: inject-exec FILE...\nReplace <!-- exec: COMMAND --> blocks with command output."
        );
        return Ok(());
    }
    if args.is_empty() {
        return Err("Usage: inject-exec FILE...".into());
    }
    for path in args {
        let old = std::fs::read_to_string(&path)?;
        let new = inject(&old, |command| {
            nixy_tools::checked(Command::new("sh").args(["-c", command]))
        })?;
        if new != old {
            std::fs::write(&path, new)?;
            println!("[inject-exec] updated {}", path.to_string_lossy());
        }
    }
    Ok(())
}
fn main() {
    nixy_tools::main_result(run());
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn replaces_multiple_blocks_and_strips_nested_markers() -> Result {
        let input = "a<!-- exec: one -->old<!-- endexec -->b<!-- exec: two -->x<!-- endexec -->";
        let result = inject(input, |cmd| {
            Ok(format!("<!-- exec: nested -->\n{cmd}<!-- endexec -->\n"))
        })?;
        assert_eq!(
            result,
            "a<!-- exec: one -->\none\n<!-- endexec -->b<!-- exec: two -->\ntwo\n<!-- endexec -->"
        );
        Ok(())
    }
    #[test]
    fn failure_propagates() {
        assert!(
            inject("<!-- exec: bad -->old<!-- endexec -->", |_| Err(
                "failed".into()
            ))
            .is_err()
        );
    }
}
