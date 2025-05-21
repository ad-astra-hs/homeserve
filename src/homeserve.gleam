import gleam/erlang/process

import mist
import wisp
import wisp/wisp_mist

import homeserve/router

pub fn main() {
  echo "TODO: Background for site, staggered grid of pixelated troll signs, rotated 45deg and tiled(?)"
  echo "TODO: Add cookie for animations toggle, have webserver send a static frame if cookie is set to true."
  echo "TODO: Detach from Ad Astra, add configuration options"

  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    router.handle_request
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.bind("0.0.0.0")
    |> mist.start_http

  process.sleep_forever()
}
