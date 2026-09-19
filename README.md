# rtl_lib

Reusable, parameterized SystemVerilog building blocks. Written on macOS, synthesized with Quartus Prime Lite on Windows.

## Layout

```
rtl_lib/
├── combinational/  mux, decoder, priority_encoder, comparator
├── sequential/     counter, shift_register, edge_detector, pulse_stretcher
├── memory/         sync_fifo, ram_1r1w, register_file
├── cdc/            synchronizer, pulse_sync, async_fifo
├── control/        round_robin_arbiter, timer, watchdog
├── interfaces/     ready_valid, uart, spi
└── pkg/            rtl_utils_pkg   (compile first)
tb/                 testbenches
rtl_lib.f           filelist for simulators/linters (Verilator, Icarus, Verible)
rtl_lib.qip         Quartus IP include file
```

## Using in Quartus (Windows)

Clone next to (or as a submodule of) your project, then either:

- **Assignments → Settings → Files** → add `rtl_lib.qip`, or
- add to the `.qsf`: `set_global_assignment -name QIP_FILE ../rtl_lib/rtl_lib.qip`

Paths inside the `.qip` are relative to the `.qip` itself, so the clone location doesn't matter.
When adding a new module, add it to both `rtl_lib.f` and `rtl_lib.qip`.

## Editor setup (VS Code on macOS)

1. Install the recommended extensions (VS Code prompts on opening the folder, see `.vscode/extensions.json`):
   - **Verilog-HDL/SystemVerilog** (`mshr-h.veriloghdl`): highlighting, linting, language-server hookup
   - **SystemVerilog** (`eirikpre.systemverilog`): workspace indexing, go-to-definition, instantiation helpers
2. Install the command-line tools the extensions drive:
   ```sh
   brew install verilator icarus-verilog
   brew tap chipsalliance/verible && brew install verible   # verible-verilog-ls / -lint / -format
   ```
3. Reload VS Code. `.vscode/settings.json` already enables Verilator linting and the Verible language server.

Quick checks from the terminal:
```sh
verible-verilog-lint --rules_config .verible_lint.rules $(grep -v '^[/+]' rtl_lib.f)
verilator --lint-only -Wall -f rtl_lib.f
```

## Line endings

`.gitattributes` keeps everything LF in the repo so Mac/Windows diffs stay clean.
On Windows, `git config --global core.autocrlf false` is recommended.
