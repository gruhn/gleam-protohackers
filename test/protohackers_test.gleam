import gleam/bit_array
import gleam/bytes_tree
import gleeunit
import prime_time.{create_response, is_prime}

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn is_prime_test() {
  assert is_prime(-20) == False
  assert is_prime(0) == False
  assert is_prime(1) == False
  assert is_prime(2) == True
  assert is_prime(3) == True
  assert is_prime(4) == False
  assert is_prime(5) == True
}

// gleeunit test functions end in `_test`
pub fn create_response_test() {
  create_response(True)
  |> bytes_tree.to_bit_array
  |> bit_array.to_string
  |> echo
}
