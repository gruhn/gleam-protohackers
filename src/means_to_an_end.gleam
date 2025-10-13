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
  case tcp.receive(socket, 9) {
    Ok(bit_array) -> {
      echo #("serve ok:", bit_array)
      case parse_message(bit_array) {
        Ok(I(insert_msg)) -> {
          serve(socket, insert_session(insert_msg, session))
        }
        Ok(Q(query_msg)) -> {
          let mean = query_session(query_msg, session)
          let resp = bytes_tree.from_bit_array(<<mean:size(32)>>)
          echo #("serve resp:", resp)
          let _ = tcp.send(socket, resp)
          serve(socket, session)
        }
        Error(_) -> {
          echo #("parse error")
          let _ = tcp.close(socket)
          Nil
        }
      }
    }
    Error(err) -> {
      echo #("serve error:", err)
      let _ = tcp.close(socket)
      Nil
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

fn parse_message(bit_array: BitArray) -> Result(Message, Nil) {
  case bit_array {
    <<char:int-size(8), first:signed-big-size(32), second:signed-big-size(32)>> -> {
      case char {
        73 -> Ok(I(Insert(first, second)))
        81 -> Ok(Q(Query(first, second)))
        _ -> {
          echo #("parse char:", char)
          Error(Nil)
        }
      }
    }
    _ -> {
      echo #("parse array:", bit_array)
      Error(Nil)
    }
  }
}

type Session =
  List(InsertMsg)

fn insert_session(msg: InsertMsg, session: Session) -> Session {
  echo #("insert_session", msg)
  [msg, ..session]
}

fn mean(items: List(Int)) -> Int {
  let sum = list.fold(items, 0, fn(a, b) { a + b })
  sum / list.length(items)
}

fn query_session(msg: QueryMsg, session: Session) -> Int {
  echo #("query_session", msg)
  session
  |> list.filter(fn(entry) {
    msg.min_time <= entry.time && entry.time <= msg.max_time
  })
  |> list.map(fn(entry) { entry.price })
  |> mean
}
