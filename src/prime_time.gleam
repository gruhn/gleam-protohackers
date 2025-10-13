import gleam/bit_array
import gleam/bytes_tree.{type BytesTree}
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/json
import gleam/set.{type Set}
import glisten/socket.{type ListenSocket, type Socket}
import glisten/socket/options.{ActiveMode, Passive}
import glisten/tcp

fn set_any(s: Set(item), pred: fn(item) -> Bool) -> Bool {
  set.fold(s, False, fn(acc, item) { acc || pred(item) })
}

fn divides(x: Int, y: Int) {
  int.modulo(y, x) == Ok(0)
}

fn any_divides(xs: Set(Int), y) {
  set_any(xs, fn(x) { divides(x, y) })
}

pub fn is_prime(num: Int) -> Bool {
  num >= 2 && !any_divides(candidate_divisors(num, 2, set.new()), num)
}

fn candidate_divisors(num: Int, start: Int, primes: Set(Int)) -> Set(Int) {
  case start * start > num {
    True -> primes
    False ->
      case any_divides(primes, start) {
        True -> candidate_divisors(num, start + 1, primes)
        False -> candidate_divisors(num, start + 1, set.insert(primes, start))
      }
  }
}

pub fn main() -> Nil {
  case
    tcp.listen(8081, [
      ActiveMode(Passive),
    ])
  {
    Ok(listener) -> {
      io.println("TCP server started on port 8081")
      accept_loop(listener)
    }
    Error(_) -> {
      io.println("Failed to start server")
    }
  }
}

fn accept_loop(listener: ListenSocket) -> Nil {
  let assert Ok(socket) = tcp.accept(listener)
  process.spawn(fn() { serve(socket) })
  accept_loop(listener)
}

fn parse_request(input: BitArray) -> Result(Int, json.DecodeError) {
  let decoder = {
    use method <- decode.field("method", decode.string)
    use number <- decode.field("number", decode.int)
    case method == "isPrime" {
      True -> decode.success(number)
      False -> decode.failure(0, "invalid method: " <> method)
    }
  }
  json.parse_bits(input, decoder)
}

pub fn create_response(answer: Bool) -> BytesTree {
  json.object([
    #("method", json.string("isPrime")),
    #("prime", json.bool(answer)),
  ])
  |> json.to_string
  |> fn(s) { s <> "\n" }
  |> bytes_tree.from_string
}

fn serve(socket: Socket) -> Nil {
  case tcp.receive(socket, 0) {
    Ok(msg) -> {
      echo #("got a msg", bit_array.to_string(msg))
      case parse_request(msg) {
        Ok(num) -> {
          let _ = tcp.send(socket, create_response(is_prime(num)))
          io.println("succ recv msg")
          // serve(socket)
        }
        Error(err) -> {
          echo err
          let _ = tcp.close(socket)
          io.println("invalid msg")
        }
      }
    }
    Error(_) -> {
      let _ = tcp.close(socket)
      io.println("err recv msg")
    }
  }
}
