NVIM ?= nvim

.PHONY: test lint

test:
	$(NVIM) --headless -u tests/minimal_init.lua -i NONE -n -l tests/run.lua

lint:
	stylua --check .
