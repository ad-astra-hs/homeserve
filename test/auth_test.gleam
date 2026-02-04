import gleeunit/should

import homeserve/pages/admin/auth

// ---- Token Verification Tests ----

pub fn verify_plaintext_token_test() {
  // Plaintext tokens should work for backward compatibility
  auth.verify_token("my-secret-token", "my-secret-token")
  |> should.be_true
}

pub fn verify_plaintext_token_wrong_test() {
  // Wrong plaintext token should fail
  auth.verify_token("wrong-token", "my-secret-token")
  |> should.be_false
}

pub fn verify_bcrypt_token_test() {
  // Hash a token and verify it works
  let token = "test-token-123"
  let hash = auth.hash_token(token)

  // Verify the hash format (bcrypt hashes start with $2)
  should.be_true(string.starts_with(hash, "$2"))

  // Verify the token against the hash
  auth.verify_token(token, hash)
  |> should.be_true
}

pub fn verify_bcrypt_token_wrong_test() {
  // Wrong token against hash should fail
  let token = "correct-token"
  let hash = auth.hash_token(token)

  auth.verify_token("wrong-token", hash)
  |> should.be_false
}

pub fn hash_token_is_consistent_test() {
  // Hashing the same token twice should produce different hashes
  // (due to bcrypt salt), but both should verify correctly
  let token = "my-token"
  let hash1 = auth.hash_token(token)
  let hash2 = auth.hash_token(token)

  // Hashes should be different (different salts)
  hash1 |> should.not_equal(hash2)

  // But both should verify correctly
  auth.verify_token(token, hash1) |> should.be_true
  auth.verify_token(token, hash2) |> should.be_true
}

// Helper import
import gleam/string
