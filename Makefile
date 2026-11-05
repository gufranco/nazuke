SHELL := /bin/sh
PREFIX ?= $(HOME)/.local
SCRIPTS := bin/nazuke lib/*.sh scripts/*.sh .github/scripts/*.sh test/*.sh test/*.bash test/*.bats test/bin/gum screens/*.sh

.PHONY: help fmt lint test test-all test-linux coverage corpus check screens install

help:
	@echo "targets:"
	@echo "  fmt         format every script with shfmt -i 2"
	@echo "  lint        shfmt, shellcheck -o all and mandoc at zero findings"
	@echo "  test        bats suites under the system sh"
	@echo "  test-all    bats suites under every installed shell"
	@echo "  test-linux  the same suites in an Ubuntu container"
	@echo "  coverage    bashcov on this Mac and in the Ubuntu container, merged, gate 100%"
	@echo "  corpus      rename every folder of NAZUKE_CORPUS, a file of paths, and check the names"
	@echo "  check       lint and test"
	@echo "  screens     record the README screens from the real tool with VHS, on macOS"
	@echo "  install     install the tool, man page and completions under PREFIX (default ~/.local)"

fmt:
	shfmt -i 2 -w $(SCRIPTS)

lint:
	shfmt -i 2 -d $(SCRIPTS)
	shellcheck -x -s sh -o all bin/nazuke lib/*.sh scripts/*.sh .github/scripts/*.sh test/call.sh test/run-matrix.sh test/linux-container.sh test/bin/gum screens/*.sh
	sh scripts/check-names.sh
	shellcheck -x -o all test/*.bash test/*.bats
	shellcheck -s bash -o all completions/nazuke.bash
	mandoc -T lint man/nazuke.1

test:
	NAZUKE_TEST_SHELLS=sh sh test/run-matrix.sh

test-all:
	sh test/run-matrix.sh

test-linux:
	sh test/linux-container.sh sh test/run-matrix.sh

coverage:
	sh scripts/coverage.sh 0 && cp -f coverage/.resultset.json coverage-macos.json
	sh test/linux-container.sh sh scripts/linux-coverage.sh
	python3 scripts/coverage-gate.py '/(bin/nazuke|lib/[a-z]+\.sh)\Z' 100 coverage-macos.json coverage-linux.json

corpus:
	python3 scripts/corpus-check.py --words "$${NAZUKE_CORPUS_WORDS:-games}" $${NAZUKE_CORPUS_RECORD:+--record} "$${NAZUKE_CORPUS:?set NAZUKE_CORPUS to a file of paths, one per line}"

screens:
	sh screens/record.sh

check: lint test

install:
	mkdir -p "$(PREFIX)/share/nazuke" "$(PREFIX)/bin" "$(PREFIX)/share/man/man1" "$(PREFIX)/share/bash-completion/completions" "$(PREFIX)/share/zsh/site-functions" "$(PREFIX)/share/fish/vendor_completions.d"
	cp -R bin lib share "$(PREFIX)/share/nazuke/"
	cp -f man/nazuke.1 "$(PREFIX)/share/man/man1/nazuke.1"
	cp -f completions/nazuke.bash "$(PREFIX)/share/bash-completion/completions/nazuke"
	cp -f completions/_nazuke "$(PREFIX)/share/zsh/site-functions/_nazuke"
	cp -f completions/nazuke.fish "$(PREFIX)/share/fish/vendor_completions.d/nazuke.fish"
	printf '#!/bin/sh\nexec "%s/share/nazuke/bin/nazuke" "$$@"\n' "$(PREFIX)" > "$(PREFIX)/bin/nazuke"
	chmod 755 "$(PREFIX)/bin/nazuke"
