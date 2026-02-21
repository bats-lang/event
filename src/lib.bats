(* event -- DOM event listener management *)

#include "share/atspre_staload.hats"

#use array as A
#use wasm.bats-packages.dev/bridge as B

#pub fun listen
  {lb:agz}{n:pos}
  (node_id: int,
   event_type: !$A.borrow(byte, lb, n), type_len: int n,
   listener_id: int,
   callback: (int) -<cloref1> int): void

#pub fun unlisten
  (listener_id: int): void

#pub fun prevent_default(): void

#pub fun get_payload
  {n:pos | n <= 1048576}
  (len: int n): [l:agz] $A.arr(byte, l, n)

implement listen{lb}{n}
  (node_id, event_type, type_len, listener_id, callback) = let
  val cbp = $UNSAFE begin $UNSAFE.castvwtp0{ptr}(callback) end
  val () = $B.listener_set(listener_id, cbp)
in $B.listen(node_id, event_type, type_len, listener_id) end

implement unlisten(listener_id) = let
  val () = $B.listener_set(listener_id, the_null_ptr)
in $B.unlisten(listener_id) end

implement prevent_default() = $B.prevent_default()

implement get_payload{n}(len) =
  $B.stash_read($B.stash_get_int(1), len)
