# Shim over mise.toml, which owns tool versions and tasks. This exists so
# `make <tab>` works and so the repo is usable without reading mise docs.
#
#   make verify     what's installed, what's missing   <- start here
#   make try        launch sandboxed, without touching your config
#   make link       install as your Neovim config
#
# Everything derives from `languages` in lua/settings.lua.

MISE := $(shell command -v mise 2>/dev/null)
NVIM := $(shell command -v nvim 2>/dev/null)

.DEFAULT_GOAL := help
.PHONY: help verify try link shell-integration install update pin health lsp lint fmt clean

help:
	@printf '\n  \033[1mNeovim configuration\033[0m\n'
	@printf '  %s\n\n' "$$(sed -n '3p' README.md 2>/dev/null || echo 'nine plugins, no framework')"
	@printf '  \033[1mgetting started\033[0m\n'
	@printf '    make verify             check which tools your languages need\n'
	@printf '    make install            install them (needs mise)\n'
	@printf '    make try                launch sandboxed via NVIM_APPNAME\n'
	@printf '    make link               install as ~/.config/nvim\n'
	@printf '    make shell-integration  fish/zsh/bash $$NVIM handling\n\n'
	@printf '  \033[1mmaintenance\033[0m\n'
	@printf '    make update             update plugins + lockfile\n'
	@printf '    make pin                roll plugins back to the lockfile\n'
	@printf '    make health             :checkhealth\n'
	@printf '    make lsp                which servers attached\n'
	@printf '    make lint               syntax + style\n'
	@printf '    make fmt                stylua\n'
	@printf '    make clean              wipe installed plugins\n\n'
	@printf '  Edit \033[1mlua/settings.lua\033[0m to change languages, leader, theme.\n\n'

# verify needs only nvim, not mise — it's the first thing a newcomer runs.
verify:
ifndef NVIM
	@printf '\033[31mnvim not found.\033[0m Install Neovim 0.12+ first:\n'
	@printf '    brew install neovim\n'
	@printf '    https://github.com/neovim/neovim/releases\n'
	@exit 1
endif
	@nvim -l scripts/verify.lua

try:
ifndef NVIM
	@printf '\033[31mnvim not found.\033[0m\n'; exit 1
endif
	@rm -f "$(HOME)/.config/nvim-test"
	@mkdir -p "$(HOME)/.config"
	@ln -sfn "$(CURDIR)" "$(HOME)/.config/nvim-test"
	@printf '\033[1msandboxed\033[0m as NVIM_APPNAME=nvim-test\n'
	@printf '  config: ~/.config/nvim-test -> %s\n' "$(CURDIR)"
	@printf '  data:   ~/.local/share/nvim-test (separate from your real one)\n\n'
	@NVIM_APPNAME=nvim-test nvim

link:
	@target="$(HOME)/.config/nvim"; \
	if [ -L "$$target" ]; then rm "$$target"; \
	elif [ -e "$$target" ]; then \
	  backup="$$target.bak.$$(date +%Y%m%d%H%M%S)"; \
	  printf 'moving %s -> %s\n' "$$target" "$$backup"; mv "$$target" "$$backup"; \
	  if [ -d "$(HOME)/.local/share/nvim" ]; then \
	    dbackup="$(HOME)/.local/share/nvim.bak.$$(date +%Y%m%d%H%M%S)"; \
	    printf 'moving ~/.local/share/nvim -> %s (old plugins)\n' "$$dbackup"; \
	    mv "$(HOME)/.local/share/nvim" "$$dbackup"; \
	  fi; \
	fi; \
	mkdir -p "$(HOME)/.config"; ln -sfn "$(CURDIR)" "$$target"; \
	printf '%s -> %s\n' "$$target" "$(CURDIR)"

shell-integration:
	@printf '\n\033[1mfish\033[0m\n'
	@printf '    mkdir -p ~/.config/fish/conf.d\n'
	@printf '    ln -sfn %s/shell/nvim.fish ~/.config/fish/conf.d/nvim.fish\n\n' "$(CURDIR)"
	@printf '\033[1mzsh / bash\033[0m\n'
	@printf "    echo 'source %s/shell/nvim.sh' >> ~/.zshrc\n\n" "$(CURDIR)"
	@printf 'Both make $$EDITOR open files in the parent Neovim instead of\n'
	@printf 'nesting a new one. See the shell section of the README.\n\n'

install update pin health lsp lint fmt clean: guard-mise
	@mise run $@

guard-mise:
ifndef MISE
	@printf '\033[31mmise not found.\033[0m\n\n'
	@printf 'Install it:      brew install mise\n'
	@printf 'Or install the tools yourself — `make verify` prints the exact\n'
	@printf 'command for each one that is missing.\n\n'
	@exit 1
endif
