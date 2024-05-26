public func withRetry<R>(
  maxAttempts: Int,
  initialDelay: Duration,
  retryInterval: Duration,
  body: () async throws -> R
) async throws -> R {
  try await Task.sleep(for: initialDelay)

  var attempt = 0
  while true {
    attempt += 1
    do {
      return try await body()
    } catch {
      if attempt < maxAttempts {
        print("attempt \(attempt)/\(maxAttempts) failed: \(error), retrying in \(retryInterval)...")

        try await Task.sleep(for: retryInterval)
        continue
      }

      throw error
    }
  }
}
