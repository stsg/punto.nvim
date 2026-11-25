# Changelog

## 0.1.0 - 2026-11-25

### Added

- conversion between `en(qwerty)` and `ru(winkeys)`, `ru(phonetic)`,
  `ru(phonetic_winkeys)`;
- normal mode: convert the last word under or before the cursor;
- visual mode: charwise, linewise and blockwise selections;
- automatic direction detection plus explicit `to_ru` / `to_en`;
- `:PuntoSwitch [auto|to_ru|to_en]` with range support;
- default `<Leader>sw` mappings for normal and visual modes;
- custom layouts via `require("punto").register_layout()`;
- single-step undo and one buffer write per conversion;
- `:checkhealth punto`;
- zero-dependency headless test suite.
