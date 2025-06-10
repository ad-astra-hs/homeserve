import gleam/erlang/process

import mist
import wisp
import wisp/wisp_mist

import homeserve/router

pub fn main() {
  echo "TODO: (Awaiting assets) Background for site, staggered grid of pixelated troll signs, rotated 45deg and tiled(?)"
  echo "TODO: (Tonight, ideally) Halve the 'about' section and add something interesting like featured panels, community news, etc."
  echo "TODO: (Awaiting assignment) Top banner & Bottom banner"
  echo "TODO: (Pre-release) Actually find first contribution for the HOC..."
  echo "TODO: (Pre-release) ARIA labels for any icon-y buttons (e.g., Quirk/Anim toggles, Vol up & Vol dn)"
  echo "TODO: (Distant future) Detach from Ad Astra, add configuration options"

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
