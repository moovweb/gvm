# Makefile for gvm.
#
# There is no configure step and nothing to generate: install.sh knows the file
# list, and this delegates to it. The targets exist because `make install` is
# what people type, not because make is required - install.sh works on its own.
#
#   make test              run the test suite
#   make install           install into ~/.gvm
#   make install PREFIX=~/go/gvm
#   make uninstall PREFIX=~/go/gvm
#   make lint              syntax-check every shell script
#   make help              list the targets

PREFIX ?= $(HOME)/.gvm
SHELL := /bin/bash
INSTALL := ./install.sh
SHELL_SOURCES := $(shell find bin scripts -type f 2> /dev/null) install.sh

.DEFAULT_GOAL := help
.PHONY: help test check install uninstall lint clean

help:
	@echo "gvm $(shell tr -d '\n' < VERSION 2> /dev/null)"
	@echo
	@echo "Targets:"
	@echo "  test        Run the test suite (tests/run.sh)"
	@echo "  lint        Syntax-check every shell script"
	@echo "  install     Install into PREFIX (default: $(PREFIX))"
	@echo "  uninstall   Remove gvm from PREFIX"
	@echo "  clean       Remove test leftovers"
	@echo
	@echo "Variables:"
	@echo "  PREFIX      Installation directory (default: $(PREFIX))"
	@echo
	@echo "Pass extra options through, e.g.:"
	@echo "  make install EXTRA_ARGS=--no-profile"

test check:
	@bash tests/run.sh

lint:
	@failed=0; \
	for file in $(SHELL_SOURCES); do \
		case "$$file" in \
			*.awk) continue ;; \
		esac; \
		if ! bash -n "$$file" 2> /dev/null; then \
			echo "syntax error: $$file"; \
			bash -n "$$file" || true; \
			failed=1; \
		fi; \
	done; \
	if [ "$$failed" = "0" ]; then echo "all scripts parse"; else exit 1; fi

install:
	@PREFIX=$(PREFIX) bash $(INSTALL) --prefix "$(PREFIX)" $(EXTRA_ARGS)

uninstall:
	@PREFIX=$(PREFIX) bash $(INSTALL) --prefix "$(PREFIX)" --uninstall $(EXTRA_ARGS)

clean:
	@rm -rf tests/.tmp
	@echo "nothing else to clean; installed Go versions live in $(PREFIX)/gos"
