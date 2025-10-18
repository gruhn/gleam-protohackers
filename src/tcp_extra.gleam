import gleam/bit_array
import gleam/bytes_tree
import gleam/result
import gleam/string
import glisten/socket.{type Socket}
import glisten/tcp

pub fn send_line(socket: Socket, msg: String) {
  tcp.send(socket, bytes_tree.from_string(msg <> "\n"))
}

pub type ReadLineError {
  SocketReason(socket.SocketReason)
  Discarded(String)
  ConvertBitArrayToString
}

pub fn read_line(socket: Socket) -> Result(String, ReadLineError) {
  use data <- result.try(
    tcp.receive(socket, 0) |> result.map_error(SocketReason),
  )
  use str <- result.try(
    bit_array.to_string(data)
    |> result.replace_error(ConvertBitArrayToString),
  )
  case string.split(str, "\n") {
    [] -> Ok("")
    [line] -> {
      Ok(line)
    }
    [line, ..rest] -> {
      case string.join(rest, "") {
        "" -> Ok(line)
        // TODO:
        discarded_str -> {
          Error(Discarded(discarded_str))
        }
      }
    }
  }
}
