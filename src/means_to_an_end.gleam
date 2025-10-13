import gleam/bytes_tree
import gleam/erlang/process
import gleam/io
import gleam/list
import glisten/socket.{type ListenSocket, type Socket}
import glisten/socket/options.{ActiveMode, Passive}
import glisten/tcp

pub fn main() {
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
  process.spawn(fn() { serve(socket, []) })
  accept_loop(listener)
}

fn serve(socket: Socket, session: Session) -> Nil {
  case tcp.receive(socket, 0) {
    Ok(bit_array) -> {
      case parse_message(bit_array) {
        I(insert_msg) -> {
          serve(socket, insert_session(insert_msg, session))
        }
        Q(query_msg) -> {
          let mean = query_session(query_msg, session)
          let _ = tcp.send(socket, bytes_tree.from_bit_array(<<mean:size(32)>>))
          serve(socket, session)
        }
      }
    }
    Error(_) -> {
      let _ = tcp.close(socket)
      io.println("err recv msg")
    }
  }
}

type InsertMsg {
  Insert(time: Int, price: Int)
}

type QueryMsg {
  Query(min_time: Int, max_time: Int)
}

type Message {
  I(InsertMsg)
  Q(QueryMsg)
}

fn parse_message(bit_array: BitArray) -> Message {
  case bit_array {
    <<char:int-size(8), first:big-size(32), second:big-size(32)>> -> {
      case char {
        73 -> I(Insert(first, second))
        81 -> Q(Query(first, second))
        _ -> panic
      }
    }
    _ -> panic
  }
}

type Session =
  List(InsertMsg)

fn insert_session(msg: InsertMsg, session: Session) -> Session {
  [msg, ..session]
}

fn mean(items: List(Int)) -> Int {
  let sum = list.fold(items, 0, fn(a, b) { a + b })
  sum / list.length(items)
}

fn query_session(msg: QueryMsg, session: Session) -> Int {
  session
  |> list.filter(fn(entry) {
    msg.min_time <= entry.time && entry.time <= msg.max_time
  })
  |> list.map(fn(entry) { entry.price })
  |> mean
}
