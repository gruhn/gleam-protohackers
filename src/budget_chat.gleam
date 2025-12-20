import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/regexp
import gleam/string
import glisten/socket.{type ListenSocket, type Socket}
import glisten/socket/options.{ActiveMode, Passive}
import glisten/tcp
import tcp_extra

type Event {
  UserJoin(user_name: String, socket: Socket)
  UserLeave(user_name: String)
  Message(sender: String, body: String)
}

type Users =
  dict.Dict(String, Socket)

fn broadcast(msg: String, users: Users) {
  let user_list = users |> dict.to_list
  echo #("broadcast: ", msg, user_list)
  user_list
  |> list.each(fn(pair) {
    let #(_, socket) = pair
    tcp_extra.send_line(socket, msg)
  })
  Nil
}

fn accept_new_message(
  user: String,
  socket: Socket,
  subject: process.Subject(Event),
) {
  case tcp_extra.read_line(socket) {
    Ok(msg) -> {
      echo #("[accept_new_message] success", user, msg)
      process.send(subject, Message(user, msg))
      accept_new_message(user, socket, subject)
    }
    Error(err) -> {
      echo #(user, "[accept_new_message] error", user, err)
      process.send(subject, UserLeave(user))
      let _ = tcp.close(socket)
      Nil
    }
  }
}

fn accept_new_connection(
  listen_socket: ListenSocket,
  subject: process.Subject(Event),
) {
  case tcp.accept(listen_socket) {
    Ok(socket) -> {
      echo "[accept_new_connection] success"
      let pid = process.spawn(fn() { handle_new_connection(socket, subject) })
      let _ = tcp.controlling_process(socket, pid)
      Nil
    }
    Error(err) -> {
      echo #("[accept_new_connection] error", err)
      Nil
    }
  }
  accept_new_connection(listen_socket, subject)
}

fn is_valid_user_name(name: String) -> Bool {
  let assert Ok(re) = regexp.from_string("^[a-zA-Z0-9]+$")
  regexp.check(re, name)
}

fn handle_new_connection(socket: Socket, subject: process.Subject(Event)) -> Nil {
  let assert Ok(_) =
    tcp_extra.send_line(socket, "Welcome to budgetchat! What shall I call you?")

  case tcp_extra.read_line(socket) {
    Ok(user) -> {
      case is_valid_user_name(user) {
        True -> {
          echo "[handle_new_connection] new user: " <> user
          process.send(subject, UserJoin(user, socket))
          accept_new_message(user, socket, subject)
        }
        False -> {
          echo #("[handle_new_connection] invalid user name:", user)
          let _ = tcp.close(socket)
          Nil
        }
      }
    }
    Error(err) -> {
      echo #("[handle_new_connection] error:", err)
      let _ = tcp.close(socket)
      Nil
    }
  }
}

fn event_loop(users: Users, subject: process.Subject(Event)) -> Nil {
  case process.receive_forever(subject) {
    UserJoin(user_name, socket) -> {
      let msg = "* " <> user_name <> " has entered the room"
      broadcast(msg, users)

      let members = users |> dict.keys |> string.join(", ")
      let member_msg = "* The room contains: " <> members
      let _ = tcp_extra.send_line(socket, member_msg)

      event_loop(users |> dict.insert(user_name, socket), subject)
    }
    UserLeave(user_name) -> {
      let rest_users = users |> dict.delete(user_name)
      let msg = "* " <> user_name <> " has left the room"
      broadcast(msg, rest_users)
      event_loop(rest_users, subject)
    }
    Message(sender, body) -> {
      let msg = "[" <> sender <> "] " <> body
      process.sleep(1000)
      broadcast(msg, users |> dict.delete(sender))
      event_loop(users, subject)
    }
  }
}

pub fn main() {
  let assert Ok(listen_socket) =
    tcp.listen(8081, [
      ActiveMode(Passive),
    ])
  echo "TCP server started on port 8081"

  let subject: process.Subject(Event) = process.new_subject()
  process.spawn(fn() { accept_new_connection(listen_socket, subject) })
  event_loop(dict.new(), subject)
}
