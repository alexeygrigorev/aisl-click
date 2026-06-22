// aisl.click short-link redirector.
// Runtime: Lambda provided.al2023, arm64, 128MB; behind a Function URL (+ CloudFront).
//
// Add/change a link: edit REDIRECTS below, `cargo test` locally (x86_64), then push
// to deploy (arm64 via CI). 302 + cache-control: no-store -> changes are instant.

use lambda_http::{run, service_fn, Body, Error, Request, Response};

/// Short-link map: path slug -> destination URL. "" matches the root path "/".
const REDIRECTS: &[(&str, &str)] = &[
    // slug       destination
    ("", "https://aishippinglabs.com/"),
    ("munich", "https://aishippinglabs.com/workshops/full-stack-vibe-coding"),
];

/// Look up the destination for a request path (e.g. "/munich" -> the URL).
fn lookup(path: &str) -> Option<&'static str> {
    let slug = path.trim_start_matches('/').to_lowercase();
    REDIRECTS
        .iter()
        .find(|(k, _)| k.eq_ignore_ascii_case(&slug))
        .map(|(_, v)| *v)
}

async fn handle(req: Request) -> Result<Response<Body>, Error> {
    match lookup(req.uri().path()) {
        Some(url) => Ok(Response::builder()
            .status(302)
            .header("location", url)
            .header("cache-control", "no-store")
            .body(Body::Empty)
            .unwrap()),
        None => Ok(Response::builder()
            .status(404)
            .header("content-type", "text/plain; charset=utf-8")
            .body(Body::from("not found\n"))
            .unwrap()),
    }
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<(), Error> {
    run(service_fn(handle)).await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_slug_redirects() {
        assert_eq!(
            lookup("/munich"),
            Some("https://aishippinglabs.com/workshops/ai-coding-tools-compared")
        );
        // case-insensitive
        assert_eq!(
            lookup("/MUNICH"),
            Some("https://aishippinglabs.com/workshops/ai-coding-tools-compared")
        );
    }

    #[test]
    fn root_redirects() {
        assert_eq!(lookup("/"), Some("https://aishippinglabs.com/"));
    }

    #[test]
    fn unknown_is_none() {
        assert_eq!(lookup("/nope"), None);
        assert_eq!(lookup("/munich/extra"), None);
    }
}
