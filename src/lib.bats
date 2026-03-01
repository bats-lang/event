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
  val () = $B.listener_set_closure(listener_id, callback)
in $B.listen(node_id, event_type, type_len, listener_id) end

implement unlisten(listener_id) = let
  val () = $B.listener_clear(listener_id)
in $B.unlisten(listener_id) end

implement prevent_default() = $B.prevent_default()

implement get_payload{n}(len) =
  $B.stash_read($B.stash_get_int(1), len)

(* ============================================================
   Keyboard event helpers
   Payload format: [key_len:1][key_bytes:N][modifiers:1]
   Modifiers: shift=1, ctrl=2, alt=4, meta=8
   ============================================================ *)

#pub stadef MOD_SHIFT = 1
#pub stadef MOD_CTRL = 2
#pub stadef MOD_ALT = 4
#pub stadef MOD_META = 8

(* Get key string length from keyboard event payload *)
#pub fn key_len {l:agz}{n:pos}
  (payload: !$A.arr(byte, l, n), payload_len: int n): int

(* Copy key string bytes into dest array. Returns bytes copied. *)
#pub fn key_copy {l:agz}{n:pos}{ld:agz}{nd:pos}
  (payload: !$A.arr(byte, l, n), payload_len: int n,
   dest: !$A.arr(byte, ld, nd), dest_max: int nd): int

(* Get modifier bitmask from keyboard event payload *)
#pub fn key_modifiers {l:agz}{n:pos}
  (payload: !$A.arr(byte, l, n), payload_len: int n): int

#use arith as AR

implement key_len{l}{n}(payload, payload_len) =
  if payload_len <= 0 then 0
  else byte2int0($A.get<byte>(payload, 0))

implement key_copy{l}{n}{ld}{nd}(payload, payload_len, dest, dest_max) = let
  val kl = key_len(payload, payload_len)
  val copy_len = (if kl > dest_max then dest_max else kl): int
  fun loop {la:agz}{na:pos}{lb:agz}{nb:pos}{fuel:nat} .<fuel>.
    (src: !$A.arr(byte, la, na), dst: !$A.arr(byte, lb, nb),
     i: int, lim: int, fuel: int fuel): void =
    if fuel <= 0 then ()
    else if i >= lim then ()
    else let
      val () = $A.set<byte>(dst, $AR.checked_idx(i, dest_max),
        $A.get<byte>(src, $AR.checked_idx(i + 1, payload_len)))
    in loop(src, dst, i + 1, lim, fuel - 1) end
in loop(payload, dest, 0, copy_len, $AR.checked_nat(copy_len + 1)); copy_len end

implement key_modifiers{l}{n}(payload, payload_len) = let
  val kl = key_len(payload, payload_len)
  val mod_off = kl + 1
in
  if mod_off >= payload_len then 0
  else byte2int0($A.get<byte>(payload, $AR.checked_idx(mod_off, payload_len)))
end
