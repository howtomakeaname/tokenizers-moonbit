// Tests for sidecar error classification. These cover the 404-vs-real-failure
// split without any network IO by exercising the pure mapping helpers.

///|
test "sidecar missing-file message detects HTTP 404 only" {
  @test.assert_eq(
    @hub.is_hub_missing_file_message(
      "Hub file download failed: HTTP 404 (missing repository, revision, or tokenizer.json file)",
    ),
    true,
  )
  @test.assert_eq(@hub.is_hub_missing_file_message("HTTP 500"), false)
  @test.assert_eq(@hub.is_hub_missing_file_message("connection reset"), false)
  // A message merely containing the digits elsewhere must not match.
  @test.assert_eq(@hub.is_hub_missing_file_message("status 4040 proxy"), false)
}

///|
test "sidecar outcome maps 404 to Missing and others to Failed" {
  let missing = @hub.sidecar_outcome_from_error(
    @types.ParseError(
      "Hub file download failed: HTTP 404 (missing repository, revision, or tokenizer.json file)",
    ),
  )
  @test.assert_eq(missing, @hub.HubSidecarOutcome::Missing)

  let failed = @hub.sidecar_outcome_from_error(
    @types.ParseError(
      "Hub file download failed: HTTP 503 (Hub service unavailable; retry later)",
    ),
  )
  match failed {
    @hub.HubSidecarOutcome::Failed(msg) =>
      @test.assert_eq(msg.contains("HTTP 503"), true)
    _ => abort("expected Failed outcome")
  }

  let auth_failed = @hub.sidecar_outcome_from_error(
    @types.ParseError(
      "Hub file download failed: HTTP 401 (private or gated repository)",
    ),
  )
  match auth_failed {
    @hub.HubSidecarOutcome::Failed(_) => ()
    _ => abort("401 must be Failed, not Missing")
  }
}

///|
test "sidecar outcome enum has all four variants" {
  // The enum is the public contract; confirm each variant constructs and
  // compares correctly through its derived Eq.
  @test.assert_eq(
    @hub.HubSidecarOutcome::AlreadyCached,
    @hub.HubSidecarOutcome::AlreadyCached,
  )
  @test.assert_eq(
    @hub.HubSidecarOutcome::Missing,
    @hub.HubSidecarOutcome::Missing,
  )
  @test.assert_eq(
    @hub.HubSidecarOutcome::Saved("/x/y.json"),
    @hub.HubSidecarOutcome::Saved("/x/y.json"),
  )
  @test.assert_eq(
    @hub.HubSidecarOutcome::Failed("boom"),
    @hub.HubSidecarOutcome::Failed("boom"),
  )
  // Distinct variants and payloads must not compare equal.
  @test.assert_not_eq(
    @hub.HubSidecarOutcome::Missing,
    @hub.HubSidecarOutcome::AlreadyCached,
  )
  @test.assert_not_eq(
    @hub.HubSidecarOutcome::Saved("/a"),
    @hub.HubSidecarOutcome::Saved("/b"),
  )
}
