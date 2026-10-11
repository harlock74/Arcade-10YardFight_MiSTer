# Vendored upstream sources

Stage 1 pins all imported source rather than relying on moving branches.

| Local path | Upstream | Commit | Imported content | Licence |
|---|---|---|---|---|
| `sys/` and root `LICENSE` | `MiSTer-devel/Template_MiSTer` | `3ea1134cf05d62c2b1db30362277a823d739ced2` | Framework lineage and port definitions; 23/57 `sys/` files match after newline normalization, 34 differ | Mixed GPL-2.0-or-later, GPL-3.0-or-later, LGPL-3.0-or-later, TEMLIB and headerless files; see the component classifications in `../NOTICE.md`. Pinned Template root `LICENSE` is GPLv2 text and its README identifies `sys/` as framework to include; together they support package-level GPL-2.0 treatment for 26 headerless framework/support files, subject to file-specific/Intel terms. Current project root `LICENSE` is a scoped owner grant, not a blanket dependency override. |
| `rtl/T80/` | `MiSTer-devel/Arcade-TraverseUSA_MiSTer` | `b119f658d6ab0259ca9dcc57d085d73aa0300b87` | T80 version 350/0242 wrappers as used by the reference core | BSD-3-Clause-style terms retained in source headers |

The M58 implementation does not copy Traverse USA game logic. Stage 8 imports the following additional building blocks from the same pinned Traverse USA commit:

| Local path | Upstream path | Licence | Local delta |
|---|---|---|---|
| `rtl/audio/cpu68.vhd` | `rtl/cpu68.vhd` | GNU GPL, John E. Kent; original header preserved | Clear cancelled opcode to internal NOP at interrupt vector entry; independently checked real-ROM regression |
| `rtl/audio/YM2149.vhd` | `rtl/YM2149.vhd` | MikeJ redistribution terms preserved in header | Unused optional volume-table branch/generic/signals removed; active linear mixer, PSG logic and I/O preserved by simulation comparison |

The optional `rtl/audio/vol_table_array.vhd` (Paulo Simoes measured table data) was present in the accepted source but is **omitted from this experimental publication candidate**. Both `m52_large_ports.vhd` AY instances used the default linear mixer; neither selected the optional table. The old table remains recoverable from the accepted Git checkpoint, not from this source candidate. This does not change the documented original analogue-mix approximation.

Line endings are normalized to LF on import. No ROM bytes are included in these HDL files. `moon_patrol_sound_board.vhd` was inspected as a reference; it is not copied wholesale because its map, ports, IRQ and single-MSM implementation are incompatible. The new decoder uses the common adaptive ADPCM equations/step sequence cross-checked against MAME `msm5205.cpp` (Aaron Giles, BSD-3-Clause), with corrected bounds and separate channel state. The detailed source-to-circuit comparison is retained in development and is not bundled here; the implementation attribution above and component notices in `../NOTICE.md` remain applicable.

Additional pinned **documentation/reference examples**, not sources imported
into this core: [Apple-II_MiSTer](https://github.com/MiSTer-devel/Apple-II_MiSTer/tree/cb2485544c1407565566bd2e00e1f21f520253e6)
`cb2485544c1407565566bd2e00e1f21f520253e6` (installation/controls
documentation) and
[Arcade-SkullXBones_MiSTer](https://github.com/MiSTer-devel/Arcade-SkullXBones_MiSTer/tree/73fdc2408c69ee6db26394ce1d346745d440cf0c)
`73fdc2408c69ee6db26394ce1d346745d440cf0c` (README/NOTICE and
third-party-attribution structure). Their use of the MiSTer framework, and
the Template's instructions to include `sys/`, do **not** supply a documented
exception to Quartus 17 §20 or resolve this project's GPL/Intel-IP
combined-work question. The local `sys/` pin above remains the provenance
reference for copied framework files, with file-specific notices preserved.
