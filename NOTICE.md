# NOTICE — prepared public source/release package

This notice records **provenance**, not a licence grant or public-release
clearance. Original source headers remain intact. The companion
The component notes here, existing upstream-source document and retained source
headers preserve attribution, applicable terms or uncertainty, source provenance
and local changes for the components included here.
Where a header is silent, the component classification below records that; it does not invent an author
or treat a repository root licence as an automatic file-level exception.

## Third-party code retained

- **MiSTer framework:** `sys/` has verified content/provenance comparison
  against [Template_MiSTer](https://github.com/MiSTer-devel/Template_MiSTer/tree/3ea1134cf05d62c2b1db30362277a823d739ced2)
  revision `3ea1134cf05d62c2b1db30362277a823d739ced2`; this is **not**
  proof of the exact historical import revision. File headers name
  Till Harbaum, Alexey Melnikov/Sorgelig, Ludvig Strigeus, Mike Simone,
  bellwood420, TEMLIB and other contributors where applicable. Terms are
  mixed: explicit GPL-2.0-or-later, GPL-3.0-or-later and LGPL-3.0-or-later
  files, TEMLIB's own permissive notice (`sys/ascal.vhd`), and files with no
  precise file-level grant. For the 26 headerless framework/support files,
  the pinned Template's GPLv2 root `LICENSE`, its README identifying `sys/`
  as the framework to include in cores, and content matching the pinned
  `sys/` files support a **package-level GPL-2.0 grant** for those files.
  This is not a per-file header, does not override specific notices or
  Intel IP terms, and does not identify the exact historical import revision.
  The recorded framework comparison found 23 identical and 34 byte-different `sys/` files after
  line-ending normalization. Of the 34, 31 have no demonstrated project
  functional edit: 26 differ only in whitespace and five only in a trailing
  blank line. The other three have documented Stage 9 edits in project Git
  (`hq2x.sv`, `sys_top.v`, `video_mixer.sv`). The Template pin is a
  **comparison revision**, not proof of the exact import revision or the
  author of whitespace normalization. The classifications below preserve the distinction.
  Complete-file notice review found a second GPL-2.0-or-later header in
  `sys/arcade_video.v` around line 150; both source notices remain verbatim.
  `hq2x.sv`, `video_cleaner.sv`, `video_freak.sv` and `video_mixer.sv`
  identify a GPL-family grant but refer to `COPYING`, which is absent from
  the pinned Template tree. Its root `LICENSE` contains GPLv2 text, while
  the Template README calls `sys/` framework code and tells core authors to
  copy it. Those are package-context facts, not proof that every silent
  source file has a particular licence version. The matrix distinguishes
  explicit file grants from the supported package-level treatment of the
  26 headerless framework files and the narrower `COPYING`-reference issue.
- **T80:** `rtl/T80/*.vhd` and `rtl/T80/T80.qip` derive from
  [Arcade-TraverseUSA_MiSTer](https://github.com/MiSTer-devel/Arcade-TraverseUSA_MiSTer/tree/b119f658d6ab0259ca9dcc57d085d73aa0300b87)
  at `b119f658d6ab0259ca9dcc57d085d73aa0300b87`. Daniel Wallner's
  source/synthesized-form conditions and disclaimer, plus MikeJ/Sorgelig and
  other credits where named, are retained in the VHDL headers. A
  synthesized-form documentation copy is at `LICENSES/T80-source-synthesized.txt`;
  the per-file headers remain authoritative for variant credits. `T80as.vhd`
  differs from the pinned Traverse copy only in whitespace; project history
  shows no post-import edit. Do not replace its custom BSD-3-Clause-style text with
  a generic GPL label.
- **YM2149:** `rtl/audio/YM2149.vhd`, same Traverse pin, originated with
  MikeJ. Its source/synthesized-form conditions and disclaimer remain in its
  header and reproduced for the binary's documentation at
  `LICENSES/YM2149-source-synthesized.txt`. The experimental edit removed the inactive optional Paulo Simoes
  volume-table branch/generic/signals and `vol_table_array.vhd`; the two
  actual AY instances still select the pre-existing linear mixer. No
  redistribution permission for the omitted table is claimed.
- **CPU68:** `rtl/audio/cpu68.vhd`, same Traverse pin, credits author John E.
  Kent/OpenCores and inherited revision contributors **Jared Boone** (2019
  cycle-accuracy states) and **Gyorgy Szombathelyi** (2020 formatting,
  reset/NMI interrupt-mask and Irem sound-board changes). These credits are
  retained at source lines 16 and 62–70. Its exact header says **“This core adheres to the GNU public
  license”**; it does *not* specify a version or use the exact words “General
  Public License.” The local interrupt-entry correction is documented and
  retains the header. The proposed compliance reading is that this is an
  operative GNU GPL grant with no specified version, allowing GPL version 3
  selection under GPLv2 §9 / GPLv3 §14. That is an **interpretation**, not
  an explicit upstream GPL-3.0-or-later notice. The operative scope remains
  a disclosed interpretation limit under the owner's publication policy.
  The **local** interrupt-entry correction is separate from those inherited
  contributions. The original OpenCores System68
  project listing identifies the core but leaves its Licence field blank;
  its general licensing page supplies no System68-specific grant. An original
  release archive with a covering `COPYING`, `LICENSE` or package notice was
  not established. Missing version alone is not the blocker **if** the grant
  is GPL.

The project-specific `rtl/audio/m52_*.vhd` sound board, MSM decoder, ports
and clock logic are local implementation work cross-checked against
schematics/MAME behavior. `m52_msm5205.vhd` explicitly credits the MAME
[`msm5205.cpp`](https://github.com/mamedev/mame/blob/master/src/devices/sound/msm5205.cpp)
arithmetic (Aaron Giles and Buffoni Mirko credited there, BSD-3-Clause) and
Dar's [Moon Patrol core](https://github.com/MiSTer-devel/Arcade-MoonPatrol_MiSTer)
step-table precedent; neither complete
source file is distributed. Numerical table provenance is not a claim that
the entire decoder was copied. The project high-score logic in
`rtl/m58_hiscore*.sv` adapted protocol/ownership and packet patterns from
the owner's separate The Pit implementation at `4786dd005dc4ebc7307fc289a9b7d8cd48c13d9b`;
it is not a verbatim The Pit module copy and its game addresses/packet format
were developed for 10-Yard Fight. The three `rtl/pll*`
clock-wrapper/QIP inputs first appear in Stage 1 commit `c8e773a` with no
subsequent edits. The pinned Template does contain counterparts: its
generated `rtl/pll.v`, `rtl/pll.qip` and `rtl/pll/pll_0002.v` target 20 MHz,
while the shorter local versions request 36.864 MHz and directly instantiate
Intel `altera_pll`. Template calls these per-core settings, rather than
`sys/` framework. The different clock configuration is project-specific;
the precise origin of the rewritten wrapper/manifest expression remains
unproved. The Intel IP and any derived generated content retain their own
terms; an initial project commit is not proof of whole-file owner authorship.

## Intel/Altera generated inputs

All **13 previously identified** ordinary PLL/reconfiguration inputs remain:
`sys/pll_hdmi.v`, `sys/pll_hdmi.qip`,
`sys/pll_hdmi/pll_hdmi_0002.v`, `sys/pll_hdmi/pll_hdmi_0002.qip`;
`sys/pll_audio.v`, `sys/pll_audio.qip`,
`sys/pll_audio/pll_audio_0002.v`, `sys/pll_audio/pll_audio_0002.qip`;
`sys/pll_cfg.qip`, `sys/pll_cfg/pll_cfg.v`,
`sys/pll_cfg/pll_cfg_hdmi.v`,
`sys/pll_cfg/altera_pll_reconfig_top.v`, and
`sys/pll_cfg/altera_pll_reconfig_core.v`.
`pll_cfg_hdmi.v` is a trimmed Intel derivative directly used by
`sys_top`. The trim and its explanatory comment are already present in the
pinned Template, Apple-II and SkullXBones framework sources. Project Git
contains no subsequent edit to this file; the trim is **inherited**, not
attributed to this project's owner. The supplied Quartus Prime 17.0 Web Download Agreement
(`C:\intelFPGA_lite\17.0\licenses\license.txt`, user-reported path;
SHA-256 `cec323b41fee8867f597d4b032c2c8949066e4badde398d5c893de546c2f8732`)
supports §2.5 source modification/redistribution of these evidenced
ordinary IP components **only for Altera-device programming**, with §5
proprietary notices preserved. The complete agreement is held **privately**,
not relicensed or included in this candidate. No file-specific override was
found for these 13. Separately, §20/GPL-LGPL combined-work compatibility of
the configured source and any RBF remains unresolved. A README exclusion,
separate filenames or regeneration is not a solution by itself.

## Project-controlled scope and reference texts

The owner has **selected and granted GPL-3.0-or-later** for copyrightable
contributions they control. Root `LICENSE` defines the supported scope:
original `rtl/m58_*` and `rtl/audio/m52_*` work; original simulation,
test/tool scripts and project documentation/MRA expression; project-authored
portions of `Arcade-10YardFight.sv`; and only demonstrated copyrightable
project edits to `sys/hq2x.sv`, `sys/sys_top.v`, `sys/video_mixer.sv` and
`rtl/audio/cpu68.vhd`. It does not grant rights over inherited portions.
The whitespace-only import difference in `rtl/T80/T80as.vhd`, origin
uncertainty for the three `rtl/pll*` files, and template-derived project configuration are
not promoted to owner-controlled whole files. File-level classifications
remain documented here and in the retained source headers.

The former root `LICENSE` was byte-identical Template GPLv2 text. It is
preserved verbatim in `LICENSES/GPL-2.0.txt`; the current root `LICENSE` is
the scoped owner statement, not a blanket relicensing of dependencies.
`LICENSES/GPL-3.0.txt` provides the full text for the owner grant and
third-party GPLv3 notices; `LICENSES/LGPL-3.0.txt` covers LGPLv3 notices.
LGPLv3 refers to GPLv3.
Custom T80/YM2149/TEMLIB terms remain in the source headers; the Intel
agreement remains private. Preserve all notices in source and any eventual
synthesized-form documentation.

Pinned *comparison examples*, not copied source or licence exceptions:
[Apple-II_MiSTer](https://github.com/MiSTer-devel/Apple-II_MiSTer/tree/cb2485544c1407565566bd2e00e1f21f520253e6)
at `cb2485544c1407565566bd2e00e1f21f520253e6` documents MiSTer
installation/controls;
[Arcade-SkullXBones_MiSTer](https://github.com/MiSTer-devel/Arcade-SkullXBones_MiSTer/tree/73fdc2408c69ee6db26394ce1d346745d440cf0c)
at `73fdc2408c69ee6db26394ce1d346745d440cf0c` provides an example
README/NOTICE separation and file-level dependency attribution. Neither
repository's publication, nor the Template's instructions to use `sys/`,
establishes an Intel-IP/GPL exception for this core.

No ROMs, Irem manual, personal NVM or private compiler reports belong to the
standalone candidate. The public `10YardFight_20261004.rbf` is byte-identical
to the hardware-tested `10YardFight_261004.rbf`. The renamed public MRA passed
static loader, control, DIP and NVRAM checks but has not separately launched on
MiSTer. Hardware testing observed initials entry and creation of an
experimental NVM; restoration after relaunch remains unverified. The release
README identifies the exact files, hashes and outstanding hardware checklist.
The private development agreement and assessment remain
outside the standalone export. The owner selected component-by-component
distribution practice with preserved terms and disclosed §20/CPU68 limits;
this is **not** legal clearance or an exception. This is the prepared public
source/release package; no upload has been performed.

## Framework classification details

The 26 headerless framework/support paths with the previously evidenced Template package-level GPL-2.0 treatment are `sys/build_id.tcl`, `sys/emu_ports.vh`, `sys/f2sdram_safe_terminator.sv`, `sys/gamma_corr.sv`, `sys/i2c.v`, `sys/i2s.v`, `sys/math.sv`, `sys/mcp23009.sv`, `sys/mt32pi.sv`, `sys/osd.v`, `sys/pll.13.qip`, `sys/pll_audio.13.qip`, `sys/pll_hdmi.13.qip`, `sys/pll_hdmi_adj.vhd`, `sys/pll_q13.qip`, `sys/pll_q17.qip`, `sys/scanlines.v`, `sys/shadowmask.sv`, `sys/sigma_delta_dac.v`, `sys/sys.qip`, `sys/sys.tcl`, `sys/sys_analog.tcl`, `sys/sys_dual_sdram.tcl`, `sys/sys_top.sdc`, `sys/sysmem.sv`, `sys/vga_out.sv`. Their individual authorship and precise file-level grant are not invented; this package-context assessment does not override source notices or Intel terms. The `sys/` comparison pin remains `3ea1134cf05d62c2b1db30362277a823d739ced2`, not an established historical import revision.

Explicit GPL-2.0-or-later headers apply to `sys/alsa.sv`, `sys/arcade_video.v`, `sys/audio_out.sv`, `sys/iir_filter.v`, `sys/ltc2308.sv`, `sys/spdif.v`, `sys/video_freezer.sv`, `sys/yc_out.sv` and `sys/sys_top.v`; GPL-3.0-or-later headers apply to `sys/ddr_svc.sv`, `sys/hps_io.sv` and `sys/scandoubler.v`; `sys/sd_card.sv` is LGPL-3.0-or-later. The four GPL-family/COPYING version uncertainties and TEMLIB notice remain as described above. Named authors and copyright statements remain in the unchanged files; the SPDIF source identifies Ultra-Embedded.com, Copyright 2012.

The `rtl/T80/T80.qip` file is inherited Traverse build metadata without a separate file-level notice; no independent permission or whole-file owner grant is inferred from its presence. The retained licence texts are reference texts, not a blanket attribution of unrelated files. Other previously recorded source differences are whitespace, line endings or trailing blank lines unless the specific local changes above are identified.
