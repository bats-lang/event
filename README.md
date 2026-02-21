# event

DOM event listener bridge. Register typed listeners on DOM nodes; the host
delivers payloads as byte arrays when events fire. Listener IDs are chosen by
the caller and must be unique.

## API

```
#use wasm.bats-packages.dev/event as E
#use array as A

(* Register a listener on a DOM node.
   callback is invoked with the listener_id and payload length. *)
$E.listen{lb:agz}{n:nat}
  (node_id: int,
   event_type: !A.borrow(byte, lb, n), type_len: int n,
   listener_id: int,
   callback: (int, int) -<cloptr1> void) : void

(* Remove a listener by ID *)
$E.unlisten(listener_id: int) : void

(* Prevent default behavior — must be called synchronously
   inside the listener callback *)
$E.prevent_default() : void

(* Retrieve the event payload bytes.
   Call inside a listener callback; returns a fresh array. *)
$E.get_payload{len:pos}(len: int len) : [l:agz] A.arr(byte, l, len)
```

## Dependencies

- **array**
