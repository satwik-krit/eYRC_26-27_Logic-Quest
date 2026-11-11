# Task 3A — Preferred portal-verified implementation

**Selected source:** C143  
**Snapshot date:** 7 November 2026 (portal feedback)  
**Project handoff evidence cutoff:** 9 November 2026, after C164 feedback

## Authoritative portal result

| Measure | C143 result |
|---|---:|
| Total | **49.31 / 50** |
| Path planning | **20 / 20** |
| Decryption | **20 / 20** |
| Portal data memory | **33 bytes** (9.31 / 10) |
| Portal instruction image | **3,888 / 4,096 bytes** (informational, not scored) |

C143 is the preferred reference among seven protected portal-confirmed co-bests: **C143, C149, C157, C159, C160, C161 and C163**. All seven tie at 49.31/50 and 33 data-memory bytes. C143 is selected because its reported instruction image is the smallest of the group; this does **not** make its scored result better than the other six and does not prove global optimality.

C164 is not the best: its 9 November 2026 portal result was 49.15/50 with 41 data-memory bytes. Do not replace C143 with C164 or with an unbuilt experiment.

## Exact C143 artifact fingerprints

| Artifact | SHA-256 |
|---|---|
| `Path_Planner_Dec.c` | `a755b4d118ae36efffe1322b4bd740e65a5cced06e774a24a039f3d972c1dce4` |
| C143 `program.hex` | `5925afe15f2eb1b7e7f4fd749af7529252cac80f698230247a95d0c5f467fbf0` |
| C143 `program.lss` | `db981961cc35940b02529021d916ef9d0ad2582108c4e7c45854ee8c4e6ec16f` |
| Exact portal submission ZIP | `eda75ef9192e5492810e548f48fad0e613ad805040d0185dd6029151afa7bbca` |

The committed `code/c_programs/Path_Planner_Dec.c` is the exact protected C143 source (its Git blob ID is `4afd47a8e1bb7533d9e20cf049716c5b625ed80f`). The existing official helper scripts were left byte-for-byte unchanged.

## Validation evidence

The protected C143 evidence records:

- Official fixed tests: 8/8.
- Exhaustive ordered source/destination pairs: 1,296/1,296 shortest paths.
- Encrypted full-main cases: 432/432.
- Restart follow-ups: 216/216.
- HEX/LSS decoded instruction correspondence: 950/950.
- RV32I forbidden-opcode and 4 KiB image checks: passed in the recorded GCC 14.2.0/Picolibc audit.

The exact protected C143 source and build artifacts were independently hash-checked in the handoff. The official `test.sh` was also rerun from the extracted C143 portal package and passed 8/8.

## Rebuild the generated CPU artifacts

After checking out this source, run the official scripts from WSL Ubuntu, in this order:

```bash
cd Task_3/Task_3A/code/c_programs
bash test.sh
bash generatehex.sh
```

The `generatehex.sh` script writes `program.hex` and `program.lss` into `Task_3/Task_3A/code/`. The generated files must be checked against the C143 SHA-256 fingerprints above before being treated as byte-identical to the protected portal artifacts. This Git update changes the source only; it does not claim that newly generated HEX/LSS files have been committed.

## Important compliance note

C143 inherits the standalone `edge_ws` function's `noinline` attribute. The literal wording of Task 3A Table 9 prohibits attributes that change how a function is built, with examples including `naked` and `section`. The available portal score is evidence of the evaluator's result for C143, **not** an explicit official waiver or definitive interpretation of that wording. Keep this issue visible; do not claim it has been formally resolved.

## Preservation

C143 is a protected immutable best. Do not edit or regenerate its historical source, HEX, LSS, portal ZIP, or workspace in place. Future experiments must use a separate copy and must not replace this reference unless actual portal feedback demonstrates a lower data-memory result with both functional scores preserved.
