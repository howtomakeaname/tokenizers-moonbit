// Optional HuggingFace Hub downloader for native/js backends.
//
// The core tokenizer package intentionally stays synchronous and all-backend.
// This package uses moonbitlang/async HTTP support, downloads tokenizer.json, and
// then delegates cache layout + parsing back to @tokenizer.

///|
pub struct HubDownloadOptions {
  /// HuggingFace-compatible base URL. Pass a mirror endpoint such as
  /// `https://hf-mirror.com` for regions where huggingface.co is slow.
  endpoint : String
  revision : String
  cache_dir : String?
  token : String?
  local_files_only : Bool
  max_redirects : Int
  /// Native-only explicit User-Agent. JavaScript/browser fetch forbids setting
  /// User-Agent manually, so the browser/runtime supplied UA is used there.
  user_agent : String?
} derive(Debug, Eq)

///|
pub fn HubDownloadOptions::new(
  endpoint? : String = "https://huggingface.co",
  revision? : String = "main",
  cache_dir? : String? = None,
  token? : String? = None,
  local_files_only? : Bool = false,
  max_redirects? : Int = 5,
  user_agent? : String? = Some(
    "unknown/None; hf_hub/0.34.4; python/3.x; tokenizers/0.21.4",
  ),
) -> HubDownloadOptions {
  {
    endpoint,
    revision,
    cache_dir,
    token,
    local_files_only,
    max_redirects,
    user_agent,
  }
}

///|
/// Return a copy using a custom HuggingFace-compatible endpoint or mirror.
/// Example: `opts.with_endpoint("https://hf-mirror.com")`.
pub fn HubDownloadOptions::with_endpoint(
  self : HubDownloadOptions,
  endpoint : String,
) -> HubDownloadOptions {
  { ..self, endpoint, }
}

///|
/// Deterministic request plan for fetching `tokenizer.json`. It combines the
/// HuggingFace-compatible URL, auth headers, local cache metadata, conditional
/// `If-None-Match`, and optional Range resume headers without performing IO.
pub struct HubRequestPlan {
  url : String
  headers : Map[String, String]
  cache_paths : @tokenizer.PretrainedCachePaths?
  resume_metadata : @tokenizer.PretrainedDownloadResumeMetadata?
  range_start : Int?
  conditional_etag : String?
} derive(Debug, Eq)

///|
/// Response metadata extracted from HEAD/GET responses. Network callers can use
/// it to decide whether to reuse the cache, refresh refs, or continue a partial
/// download.
pub struct HubResponseMetadata {
  status : Int
  resolved_revision : String?
  etag : String?
  content_length : Int?
  accept_ranges : Bool
} derive(Debug, Eq)

///|
pub fn plan_tokenizer_json_request(
  model_id : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> HubRequestPlan {
  let url = tokenizer_json_url(options.endpoint, model_id, options.revision)
  let headers = build_headers(options)
  let paths = @tokenizer.Tokenizer::from_pretrained_cache_paths(
    model_id,
    revision=options.revision,
    cache_dir=options.cache_dir,
  )
  let resume_meta = @tokenizer.Tokenizer::from_pretrained_download_resume_metadata(
    model_id,
    revision=options.revision,
    cache_dir=options.cache_dir,
  )
  let cached = @tokenizer.Tokenizer::from_pretrained_cache_metadata(
    model_id,
    revision=options.revision,
    cache_dir=options.cache_dir,
  )
  let mut conditional_etag : String? = None
  match cached {
    Some(meta) =>
      match meta.etag {
        Some(etag) => if !etag.is_empty() {
          headers["If-None-Match"] = etag
          conditional_etag = Some(etag)
        }
        None => ()
      }
    None => ()
  }
  let mut range_start : Int? = None
  match resume_meta {
    Some(meta) => if meta.downloaded_size > 0 {
      headers["Range"] = "bytes=" + meta.downloaded_size.to_string() + "-"
      match meta.etag {
        Some(etag) => if !etag.is_empty() { headers["If-Range"] = etag }
        None => ()
      }
      range_start = Some(meta.downloaded_size)
    }
    None => ()
  }
  {
    url,
    headers,
    cache_paths: paths,
    resume_metadata: resume_meta,
    range_start,
    conditional_etag,
  }
}

///|
pub fn HubResponseMetadata::from_headers(
  status : Int,
  headers : Map[String, String],
) -> HubResponseMetadata {
  let content_length = match header(headers, "content-length") {
    Some(v) => parse_non_negative_int(v)
    None => None
  }
  let accept_ranges = match header(headers, "accept-ranges") {
    Some(v) => v.to_lower() == "bytes"
    None => false
  }
  {
    status,
    resolved_revision: header(headers, "x-repo-commit"),
    etag: header(headers, "etag"),
    content_length,
    accept_ranges,
  }
}

///|
/// Load a tokenizer from a local path/cache first, otherwise download
/// `tokenizer.json` from HuggingFace Hub (or a compatible endpoint), persist it
/// into the HF-style cache layout, and parse it with the core tokenizer loader.
///
/// Supported on native/js backends via `moonbitlang/async/http`. Wasm users can
/// keep using `@tokenizer.from_pretrained` against a pre-populated cache, or let
/// their host application fetch JSON and pass it to
/// `@tokenizer.from_pretrained_downloaded`.
pub async fn from_pretrained(
  model_id : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> @tokenizer.Tokenizer raise @types.TokenizerError {
  try
    @tokenizer.Tokenizer::from_pretrained_cached(
      model_id,
      revision=options.revision,
      cache_dir=options.cache_dir,
    )
  catch {
    _ => ()
  } noraise {
    tok => return tok
  }
  if options.local_files_only {
    raise @types.ParseError(
      "from_pretrained local cache miss and local_files_only=true: \{model_id}",
    )
  }
  let result = download_tokenizer_json(model_id, options~)
  @tokenizer.Tokenizer::from_pretrained_downloaded(
    model_id,
    result.content,
    revision=options.revision,
    resolved_revision=result.resolved_revision,
    cache_dir=options.cache_dir,
    etag=result.etag,
  )
}

///|
pub struct HubDownloadResult {
  content : String
  resolved_revision : String?
  etag : String?
  final_url : String
  status : Int
} derive(Debug, Eq)

///|
pub async fn download_tokenizer_json(
  model_id : String,
  options? : HubDownloadOptions = HubDownloadOptions::new(),
) -> HubDownloadResult raise @types.TokenizerError {
  let plan = plan_tokenizer_json_request(model_id, options~)
  async_download_with_redirects(
    plan.url,
    headers=plan.headers,
    max_redirects=options.max_redirects,
  )
}

///|
pub fn tokenizer_json_url(
  endpoint : String,
  model_id : String,
  revision : String,
) -> String {
  trim_trailing_slash(endpoint) +
  "/" +
  model_id +
  "/resolve/" +
  revision +
  "/tokenizer.json"
}

///|
async fn async_download_with_redirects(
  url : String,
  headers~ : Map[String, String],
  max_redirects~ : Int,
) -> HubDownloadResult raise @types.TokenizerError {
  let mut current = url
  let mut remaining = max_redirects
  while true {
    let (response, body) = @http.get(current, headers~) catch {
      _ => raise @types.ParseError("Hub download failed: \{current}")
    }
    if is_redirect(response.code) {
      if remaining <= 0 {
        raise @types.ParseError("Hub download exceeded redirect limit: \{url}")
      }
      match header(response.headers, "location") {
        Some(next) => {
          current = resolve_redirect(current, next)
          remaining = remaining - 1
          continue
        }
        None =>
          raise @types.ParseError(
            "Hub redirect missing Location header: \{current}",
          )
      }
    }
    if response.code < 200 || response.code >= 300 {
      raise @types.ParseError(
        "Hub download failed with HTTP \{response.code}: \{current}",
      )
    }
    let content = body.text() catch {
      _ =>
        raise @types.ParseError(
          "Hub response body is not valid UTF-8: \{current}",
        )
    }
    let meta = HubResponseMetadata::from_headers(response.code, response.headers)
    return {
      content,
      resolved_revision: meta.resolved_revision,
      etag: meta.etag,
      final_url: current,
      status: response.code,
    }
  }
  raise @types.ParseError("unreachable Hub download loop")
}

///|
fn build_headers(options : HubDownloadOptions) -> Map[String, String] {
  // Keep close to HuggingFace Hub/tokenizers client requests: a tokenizers- and
  // hf_hub-flavoured User-Agent (native only), broad Accept, and optional bearer
  // token. Do not add library-specific identifiers here; the intent is to match
  // HuggingFace client traffic as closely as possible. Avoid Host/Content-Length/
  // Connection/Accept-Encoding because the HTTP runtime owns them and JS fetch
  // forbids several of these headers.
  let out : Map[String, String] = { "Accept": "*/*" }
  if user_agent_header_allowed() {
    match options.user_agent {
      Some(ua) => if !ua.is_empty() { out["User-Agent"] = ua }
      None => ()
    }
  }
  let token = match options.token {
    Some(t) => Some(t)
    None => @sys.get_env_var("HF_TOKEN")
  }
  match token {
    Some(t) => if !t.is_empty() { out["Authorization"] = "Bearer " + t }
    None => ()
  }
  out
}

///|
#cfg(target="js")
fn user_agent_header_allowed() -> Bool {
  false
}

///|
#cfg(not(target="js"))
fn user_agent_header_allowed() -> Bool {
  true
}

///|
fn header(headers : Map[String, String], name : String) -> String? {
  match headers.get(name) {
    Some(v) => return Some(v)
    None => ()
  }
  headers.get(name.to_lower())
}

///|
fn parse_non_negative_int(s : String) -> Int? {
  let chars = s.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut out = 0
  for c in chars {
    let u = c.to_int()
    if u < '0'.to_int() || u > '9'.to_int() {
      return None
    }
    out = out * 10 + (u - '0'.to_int())
  }
  Some(out)
}

///|
fn is_redirect(code : Int) -> Bool {
  code == 301 || code == 302 || code == 303 || code == 307 || code == 308
}

///|
fn resolve_redirect(base : String, location : String) -> String {
  if location.has_prefix("http://") || location.has_prefix("https://") {
    location
  } else if location.has_prefix("/") {
    origin(base) + location
  } else {
    parent_url(base) + "/" + location
  }
}

///|
fn origin(url : String) -> String {
  let chars = url.to_array()
  let mut slash_count = 0
  for i, c in chars {
    if c == '/' {
      slash_count = slash_count + 1
      if slash_count == 3 {
        return string_slice(chars, 0, i)
      }
    }
  }
  url
}

///|
fn parent_url(url : String) -> String {
  let chars = url.to_array()
  let mut last = -1
  for i, c in chars {
    if c == '/' {
      last = i
    }
  }
  if last <= 0 {
    url
  } else {
    string_slice(chars, 0, last)
  }
}

///|
fn trim_trailing_slash(s : String) -> String {
  let chars = s.to_array()
  let mut stop = chars.length()
  while stop > 0 && chars[stop - 1] == '/' {
    stop = stop - 1
  }
  string_slice(chars, 0, stop)
}

///|
fn string_slice(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}
