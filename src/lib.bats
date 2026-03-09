(* event -- DOM event listener management *)

#include "share/atspre_staload.hats"

#use array as A
#use wasm.bats-packages.dev/bridge as B

staload BE = "wasm.bats-packages.dev/bridge/src/event.sats"
staload BS = "wasm.bats-packages.dev/bridge/src/stash.sats"

#pub fun listen
  {li:agz}{ni:pos}{lb:agz}{n:pos}
  (node_id: !$A.borrow(byte, li, ni), id_len: int ni,
   event_type: !$A.borrow(byte, lb, n), type_len: int n,
   listener_id: int,
   callback: (int) -<cloref1> int): void

#pub fun unlisten
  (listener_id: int): void

#pub fun prevent_default(): void

#pub fun get_payload
  {n:pos | n <= 1048576}
  (len: int n): [l:agz] $A.arr(byte, l, n)

implement listen{li}{ni}{lb}{n}
  (node_id, id_len, event_type, type_len, listener_id, callback) =
  $BE.listen(node_id, id_len, event_type, type_len, listener_id, callback)

implement unlisten(listener_id) = $BE.unlisten(listener_id)

implement prevent_default() = $BE.prevent_default()

implement get_payload{n}(len) =
  $BS.stash_read($BS.stash_get_int(1), len)

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

(* ============================================================
   Click/pointer event helpers
   Payload format: [f64 LE clientX:8][f64 LE clientY:8][u16 LE targetIdLen:2]
   Total: 18 bytes
   The target ID string is in stash slot 2.
   Returns @(x, y, target_id_len) with x/y as integers.
   ============================================================ *)

#pub fn click_payload {l:agz}{n:pos | n >= 18}
  (payload: !$A.arr(byte, l, n), payload_len: int n): @(int, int, int)

(* Extract integer from IEEE 754 float64 LE at offset.
   Handles positive values 0..4096 which covers pixel coordinates. *)
fn _f64_to_int {l:agz}{n:pos}
  (arr: !$A.arr(byte, l, n), off: int, max: int n): int = let
  val b5 = byte2int0($A.get<byte>(arr, $AR.checked_idx(off + 5, max)))
  val b6 = byte2int0($A.get<byte>(arr, $AR.checked_idx(off + 6, max)))
  val b7 = byte2int0($A.get<byte>(arr, $AR.checked_idx(off + 7, max)))
  val exp_raw = $AR.bor_int_int($AR.bsl_int_int($AR.band_int_int(b7, 127), 4),
                                $AR.bsr_int_int(b6, 4))
in
  if $AR.eq_int_int(exp_raw, 0) then 0
  else let
    val exp = exp_raw - 1023
  in
    if exp < 0 then 0
    else if exp > 12 then 4096
    else let
      val mant_high = $AR.bor_int_int($AR.bsl_int_int($AR.band_int_int(b6, 15), 8), b5)
      val top13 = $AR.bor_int_int($AR.bsl_int_int(1, 12), mant_high)
    in $AR.bsr_int_int(top13, 12 - exp) end
  end
end

fn _u16_le {l:agz}{n:pos}
  (arr: !$A.arr(byte, l, n), off: int, max: int n): int = let
  val b0 = byte2int0($A.get<byte>(arr, $AR.checked_idx(off, max)))
  val b1 = byte2int0($A.get<byte>(arr, $AR.checked_idx(off + 1, max)))
in
  $AR.bor_int_int(b0, $AR.bsl_int_int(b1, 8))
end

implement click_payload {l}{n} (payload, payload_len) = let
  val x = _f64_to_int(payload, 0, payload_len)
  val y = _f64_to_int(payload, 8, payload_len)
  val target_id_len = _u16_le(payload, 16, payload_len)
in @(x, y, target_id_len) end
