import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/io
import glisten/socket.{type ListenSocket, type Socket}
import glisten/socket/options.{ActiveMode, Passive}
import glisten/tcp

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

fn serve(socket: Socket) -> Nil {
  case tcp.receive(socket, 0) {
    Ok(msg) -> {
      echo #("got a msg", bit_array.to_string(msg))
      let _ = tcp.send(socket, bytes_tree.from_bit_array(msg))
      io.println("succ recv msg")
      serve(socket)
    }
    Error(_) -> {
      let _ = tcp.close(socket)
      io.println("err recv msg")
    }
  }
}
