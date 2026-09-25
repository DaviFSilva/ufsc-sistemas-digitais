# Usage:
#   make              # build + simulate lab from .ci-lab
#   make LAB=name     # build a specific lab
#   make select LAB=name
#   make list
#   make clean

.PHONY: all build run select list which clean help

CI_LAB_FILE := .ci-lab
LABS_DIR    := labs
BUILD_SCRIPT := ./scripts/build-lab.sh

# LAB from command line, else contents of .ci-lab
LAB ?= $(shell tr -d '[:space:]' < $(CI_LAB_FILE) 2>/dev/null)

all: build

help:
	@echo "Targets:"
	@echo "  make / make build   Build and simulate the selected lab"
	@echo "  make LAB=<name>     Build a specific lab (does not change .ci-lab)"
	@echo "  make select LAB=<name>  Set .ci-lab to <name>"
	@echo "  make which          Show the lab selected in .ci-lab"
	@echo "  make list           List labs under $(LABS_DIR)/"
	@echo "  make clean          Remove GHDL build dirs"
	@echo "  make clean LAB=<name>   Clean one lab only"

which:
	@if [ -z "$(LAB)" ]; then echo "error: no lab selected (.ci-lab empty?)" >&2; exit 1; fi
	@echo "$(LAB)"

list:
	@ls -1 $(LABS_DIR) 2>/dev/null || echo "(no labs yet)"

select:
	@if [ -z "$(LAB)" ]; then echo "usage: make select LAB=<name>" >&2; exit 1; fi
	@if [ ! -d "$(LABS_DIR)/$(LAB)" ]; then echo "error: $(LABS_DIR)/$(LAB) not found" >&2; exit 1; fi
	@printf '%s\n' "$(LAB)" > $(CI_LAB_FILE)
	@echo "selected: $(LAB)"

build run:
	@if [ -z "$(LAB)" ]; then echo "error: no lab selected; set .ci-lab or use LAB=<name>" >&2; exit 1; fi
	@$(BUILD_SCRIPT) "$(LAB)"

clean:
ifeq ($(origin LAB),command line)
	rm -rf $(LABS_DIR)/$(LAB)/build
else
	rm -rf $(LABS_DIR)/*/build
endif
