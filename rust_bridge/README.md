# rust_bridge

MEX wrappers that let MATLAB call the pure-Rust DYNAM-O kernel
(`dynamo_rs`) via a small C ABI. This is the "shippable" speed path
for `runDYNAMO` — the MATLAB Compiler (`mcc`) can bundle these MEX
files into a standalone `.app`, whereas a `py.*`-based path cannot.

On night data, the Rust backend runs ~3.5–6× faster than pure MATLAB
end-to-end while reproducing final peak counts within ±0.85% across
four overnight recordings (see [Backend parity](#backend-parity) below).

---

## Contents

| File | Purpose |
|---|---|
| `build_rust_mex.m` | Compile the four MEX wrappers for the current platform |
| `extract_tfpeaks_mex.c` | Entry point for pass-1 / pass-2 TF-peak extraction |
| `mask_spectrogram_mex.c` | Mask pass-2 spectrogram with pass-1 labels |
| `refine_peaks_mex.c` | Hann-FFT refinement of peak frequencies |
| `tfpeak_histogram_mex.c` | SO-power / SO-phase histogram accumulation |
| `extract_tfpeaks_mex.mex*` etc. | Platform-specific compiled binaries (checked in) |

---

## Prerequisites

### One-time (per platform)

1. **Rust toolchain** (≥ 1.70) — <https://rustup.rs>
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. **MATLAB C compiler** — check in MATLAB:
   ```matlab
   mex -setup C
   ```
   Follow the prompt to point at Xcode Command Line Tools (macOS),
   gcc (Linux), or MSVC / MinGW-w64 (Windows).

3. **The `dynamo_rs` source tree** must be present as a sibling of
   `DYNAM-O_dev`:
   ```
   <workspace>/
     DYNAM-O_dev/
       rust_bridge/          ← you are here
     DYNAM-O_rs/
       rust/                 ← Rust crate
   ```

---

## Build (two commands)

### Step 1. Build the Rust dynamic library

From the shell:

```bash
cd <workspace>/DYNAM-O_rs/rust
cargo build --release
```

This produces (**one file, platform-dependent**):

| Platform | Output path |
|---|---|
| Apple Silicon macOS | `target/release/libdynamo_rs.dylib` |
| Intel macOS | `target/release/libdynamo_rs.dylib` |
| Linux | `target/release/libdynamo_rs.so` |
| Windows (MSVC) | `target/release/dynamo_rs.dll` + `dynamo_rs.dll.lib` |

It also generates the C header at `rust/include/dynamo_rs.h`
(via `build.rs` using `cbindgen`).

### Step 2. Build the MEX wrappers

From MATLAB:

```matlab
cd <workspace>/DYNAM-O_dev/rust_bridge
build_rust_mex
```

This compiles four `.c` files against `dynamo_rs.h` + `libdynamo_rs`,
producing one MEX binary per source file with the extension for the
current platform:

| Platform | MEX extension | Files produced |
|---|---|---|
| Apple Silicon macOS | `.mexmaca64` | `extract_tfpeaks_mex.mexmaca64`, … |
| Intel macOS | `.mexmaci64` | `extract_tfpeaks_mex.mexmaci64`, … |
| Linux | `.mexa64` | `extract_tfpeaks_mex.mexa64`, … |
| Windows | `.mexw64` | `extract_tfpeaks_mex.mexw64`, … |

On macOS the build embeds an rpath pointing at
`DYNAM-O_rs/rust/target/release`, so the MEX file resolves the
sibling `libdynamo_rs.dylib` without any `DYLD_LIBRARY_PATH` tweaks.

### Sanity check

```matlab
extract_tfpeaks_mex(zeros(2), [0 1], [0 1], [], struct( ...
    'seg_time',30,'downsample_f',1,'downsample_t',1, ...
    'merge_thresh',11,'trim_vol',0.8, ...
    'dur_min',1,'dur_max',5,'bw_min',1,'bw_max',15, ...
    'freq_min',-inf,'freq_max',inf,'ht_db_min',-inf))
```

Expect an empty output struct (no peaks on 2×2 zeros input), not an
error.

Then a full end-to-end test:

```matlab
[stats, ~, ~, ~, ~, ~, ~, ~, ~] = runDYNAMO('night', 'backend', 'rust');
```

---

## Cross-platform distribution

MEX binaries are platform-and-extension specific. The repo carries
one compiled binary per platform × per MEX file. Current strategy:

- **Build locally** on each of {Apple Silicon, Intel, Linux, Windows}.
- **Commit all built binaries** (~34 KB each, ~1.2 MB/platform total).
- Rebuild and recommit whenever `DYNAM-O_rs/rust/src/` changes in a
  way that affects the C ABI or pipeline behaviour.

Roughly: treat the MEX binaries like pre-compiled artifacts pinned to
a specific `dynamo_rs` commit. Record the commit SHA in
`BUILT_FROM.md` after each rebuild.

### When to rebuild

- Rust source in `DYNAM-O_rs/rust/src/` changed (any `.rs` edit).
- `dynamo_rs.h` regenerated (cbindgen output differs).
- MATLAB version jumped a major release — MEX is mostly
  forward/backward compatible across releases but a R2025b → R2026a
  jump is worth a rebuild to be safe.

### When NOT to rebuild

- Only comments or docs in Rust changed — `cargo build` will skip.
- Unrelated MATLAB-side changes.

### GitHub Actions (future)

For automatic multi-platform builds, a CI matrix job with
[`matlab-actions/setup-matlab`](https://github.com/matlab-actions/setup-matlab)
can run `cargo build --release` then `build_rust_mex` on each
runner OS and upload artifacts. Not set up yet — see
`<private-path>/` for the target topology.

---

## Runtime behaviour

`runDYNAMO(..., 'backend', 'rust')` dispatches the pipeline's four
heaviest stages through these MEX wrappers. The MEX files call into
`libdynamo_rs`, which internally parallelises via `rayon` — so the
Rust backend **does not need a MATLAB `parpool`** and will skip
`setup_parallel_pool` on startup.

`runDYNAMO(..., 'backend', 'matlab')` bypasses this directory
entirely and runs pure MATLAB with a `parpool` over segments.

### Recommended input: data resampled to 100 Hz

Independently of backend choice, the pipeline runs ~2× faster end-to-end
when input data is resampled to **100 Hz**. The multitaper NFFT is
`2^nextpow2(Fs / 0.1)`, so above **Fs = 102.4 Hz** NFFT doubles and the
spectrogram spills past CPU L3 cache, taking a 2–3× memory-bandwidth
hit on every downstream stage. DYNAM-O analyzes 0–30 Hz so 100 Hz
Nyquist is more than enough — the resample is lossless for sleep
oscillations. The MATLAB **DYNAMOApp** has this enabled by default
(Resample = ON @ 100 Hz). See
[`benchmarks/README.md`](benchmarks/README.md) for the per-stage
scaling analysis.

---

## Backend parity

Verified on four overnight recordings (the bundled `example_data` plus
three Compumedics PSG nights `TS00304/TS00404/TS00504`, channel
`C4-A1`, downsampled to 100 Hz, default `quality_setting` = `'default'`).
Each subject ran end-to-end through `computeTFPeaks` once per backend.

### Peak counts at each stage

| Subject  | Backend | Pass-1 raw | Pass-1 post-filter | Pass-2 raw | **Pass-2 final** | Time |
|----------|---------|-----------:|-------------------:|-----------:|-----------------:|-----:|
| example  | matlab  | 83,380 | 69,457 | 52,914 | **49,943** | 300 s |
| example  | rust    | 88,889 | 73,237 | 52,920 | **49,826** |  48 s |
| TS00304  | matlab  | 94,167 | 79,995 | 66,041 | **63,760** | 259 s |
| TS00304  | rust    | 99,716 | 83,745 | 66,429 | **64,047** |  79 s |
| TS00404  | matlab  | 88,416 | 76,249 | 55,831 | **53,241** | 221 s |
| TS00404  | rust    | 94,022 | 80,262 | 55,450 | **52,802** |  56 s |
| TS00504  | matlab  | 87,078 | 73,916 | 54,112 | **51,387** | 266 s |
| TS00504  | rust    | 92,610 | 77,810 | 53,807 | **51,014** |  61 s |

### Rust − MATLAB delta

| Subject  | Δ pass-1 raw | Δ pass-1 post | Δ pass-2 raw | **Δ final** |
|----------|-------------:|---------------:|-------------:|------------:|
| example  | +5,509 (+6.61%) | +3,780 (+5.44%) | +6 (+0.01%) | **−117 (−0.23%)** |
| TS00304  | +5,549 (+5.89%) | +3,750 (+4.69%) | +388 (+0.59%) | **+287 (+0.45%)** |
| TS00404  | +5,606 (+6.34%) | +4,013 (+5.26%) | −381 (−0.68%) | **−439 (−0.82%)** |
| TS00504  | +5,532 (+6.35%) | +3,894 (+5.27%) | −305 (−0.56%) | **−373 (−0.73%)** |

### Interpretation

- **Pass-1 raw kernel divergence is ~+5.5–6.6%** — the two watershed
  + merge implementations resolve borderline regions differently
  because the priority-queue tie-breaking order differs (Rust uses a
  `BinaryHeap` with insertion-order ties; MATLAB iterates a
  `containers.Map`). The extras are systematically smaller and
  weaker peaks (~0.7 s × 2.5 Hz, ~10 dB) than the matched population
  (~1.0 s × 3.2 Hz, ~13 dB).
- **`filterStatsTable` absorbs ~30%** of the divergence (duration /
  bandwidth / height cutoffs reject most of the borderline extras),
  narrowing pass-1 post-filter to +4.7–5.4%.
- **Pass-2 (tighter MTS, mask-spectrogram from pass-1) absorbs nearly
  all remaining divergence** — pass-2 raw is within ±0.7%, and the
  sign of the delta varies across subjects (Rust isn't systematically
  over- or under-counting).
- **Final peak counts are within ±0.85%** across all four nights.
- **Speedup is 3.5–6.3×** end-to-end on this 4-subject set.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `dynamo_rs.h not found` | Run `cargo build --release` first. |
| `libdynamo_rs.dylib not found` (macOS) | Same — `cargo build --release` didn't produce it; check `cargo`'s output. |
| `mex: Compiler not configured` | Run `mex -setup C`, pick a supported compiler. |
| `Undefined symbol: _mexCreateMexFunction` | The MEX glue was built from `.cpp`; must use `.c` files here. `build_rust_mex.m` enforces this. |
| `dyld: Library not loaded: libdynamo_rs.dylib` at MEX call | rpath didn't get embedded (usually non-macOS) — rerun build, or fall back to `DYLD_LIBRARY_PATH=<path to dylib>`. |
| MEX returns correct first call but different results on second call | Usually means MATLAB is holding a stale dylib — restart MATLAB after a fresh `cargo build`. |

---

## Regenerating the C header

The C header `DYNAM-O_rs/rust/include/dynamo_rs.h` is produced by
`cbindgen` from Rust source. The `build.rs` script invokes cbindgen
automatically on every `cargo build`. If you need to regenerate
manually:

```bash
cd <workspace>/DYNAM-O_rs/rust
cargo run --bin cbindgen -- --output include/dynamo_rs.h
```

(The exact command may vary by crate config; consult
`DYNAM-O_rs/rust/build.rs` for the authoritative recipe.)
