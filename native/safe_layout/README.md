# Stateless presentation layout query

This independent GDExtension adds only `RoundCardSafeLayoutMath : RefCounted`.
It owns no nodes, simulation state, RNG, persistent geometry, cache or file I/O.
The existing `feedback_math` and `geometry_math` modules are unchanged.

```gdscript
GDExtensionManager.load_extension("res://native/safe_layout/safe_layout.gdextension")
var math: RefCounted = ClassDB.instantiate("RoundCardSafeLayoutMath")
var result: Vector2i = math.find_first(candidates, peers, delays, clock, duration)
```

- `candidates`: Array of complete swept `Rect2` values, in caller order.
- `peers`: Array of `[Rect2, float start, float end]` rows, with every relevant peer.
- `delays`: `PackedFloat64Array` in caller order. The helper does not sort.
- `clock`, `duration`: float64 scalars; duration must be finite and nonnegative.
- Return: `(candidate_index, delay_index)`; `(-1,-1)` means no safe candidate;
  `(-2,-2)` means invalid inner input. Invalid top-level argument types use the
  normal GDExtension argument error. The caller retains its GDScript fallback.

Search order is delay first, then candidate. Rect2 uses the standard Godot
float32-vector build and `intersects(false)` semantics: touching edges do not
overlap. A spatial overlap blocks unless `end + .05 < peer.start` or
`start > peer.end + .05`, using float64 time and strict comparisons.
All input rows and times are validated before searching; no row cap is applied.
Inputs are borrowed synchronously, never retained or modified. Each call frees
its temporary decoded arrays before returning. A standard float32-vector Godot
build is required; custom double-vector builds are outside this module's ABI.

`find_first_indexed(candidates, shared_peers, delays, clock, duration,
exclude_index)` adds an int64 sixth parameter. `-1` means no exclusion; otherwise
the index must be in the shared peer array. Its occupancy loop skips that peer
and peer Rect2 values without area. It still fully validates every row, including
excluded/empty rows, before searching. Invalid exclusion returns `(-2,-2)`.
This lets World pass its existing transaction array without constructing a
filtered temporary array per query. The original `find_first` function body and
its empty-Rect2 semantics remain unchanged.

World remains responsible for full swept footprints, bounds, mouse keepout,
candidate generation/order, peer selection/exclusion, delay lattice and UI
waiting/read clocks. This helper cannot create space when every candidate is
blocked. It does not clip, hide, merge, drop or change the timing of any reward.

Run `./build.ps1` with the existing official Zig 0.14.1 compiler. It writes only
this directory's DLL/PDB/import library, using `-O3 -fno-fast-math
-ffp-contract=off`. No external SDK or download is required. The ABI header and
MIT license are copied unchanged from `native/feedback_math`.

Exact query and CPU evidence is in
`verification/quality18/native-prototype/`: 2400 seeded cases, border/time/order
cases, malformed/COW/stateless input checks, and 90/180-peer high-density tests.
Those CPU microbenchmarks measure the query only, not World snapshot generation
or final game FPS. The isolated prototype remains ignored by project scanning.
