SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:

MAKEFLAGS += --no-builtin-rules

DOCKER_IMAGE ?= zmkfirmware/zmk-build-arm:stable
WORKSPACE ?= $(CURDIR)

BOARD_BUILD ?= xiao_ble//zmk
BOARD_ARTIFACT ?= xiao_ble-zmk
LEFT_SHIELD ?= chippy_left
RIGHT_SHIELD ?= chippy_right
ZMK_CONFIG ?= /workspace/config

LEFT_BUILD_DIR ?= build/$(LEFT_SHIELD)
RIGHT_BUILD_DIR ?= build/$(RIGHT_SHIELD)
ARTIFACTS_DIR ?= build/artifacts
LEFT_ARTIFACT ?= $(ARTIFACTS_DIR)/$(LEFT_SHIELD)-$(BOARD_ARTIFACT).uf2
RIGHT_ARTIFACT ?= $(ARTIFACTS_DIR)/$(RIGHT_SHIELD)-$(BOARD_ARTIFACT).uf2
KEYMAP_TOOL ?= keymap
KEYMAP_CONFIG ?= keymap-drawer.yaml
KEYMAP_SOURCE ?= config/chippy.keymap
KEYMAP_YAML ?= $(ARTIFACTS_DIR)/keymap.yaml
KEYMAP_SVG ?= $(ARTIFACTS_DIR)/keymap.svg
KEYMAP_ORTHO_LAYOUT ?= {split: true, rows: 3, columns: 6, thumbs: 3}

DOCKER_RUN = docker run --rm --user "$$(id -u):$$(id -g)" -e HOME=/tmp -v "$(WORKSPACE):/workspace" -w /workspace $(DOCKER_IMAGE) bash -lc
WEST_SETUP = if [ ! -d .west ]; then west init -l config; west update --fetch-opt=--filter=tree:0; fi; west zephyr-export
BUILD_ENV_SETUP = west zephyr-export

.PHONY: help init update check-keymap-drawer keymap-image build build-left build-right artifact-left artifact-right clean rebuild

help:
	@printf '%s\n' \
		'Targets:' \
		'  make init         - Prepare west workspace in Docker' \
		'  make update       - Force west update in Docker' \
		'  make keymap-image - Generate keymap SVG using keymap-drawer' \
		'  make build        - Build left and right firmware' \
		'  make build-left   - Build only left firmware' \
		'  make build-right  - Build only right firmware' \
		'  make clean        - Remove build outputs' \
		'  make rebuild      - Clean and build both sides' \
		'' \
		'Artifacts:' \
		'  build/chippy_left/zephyr/zmk.uf2' \
		'  build/chippy_right/zephyr/zmk.uf2' \
		'  build/artifacts/chippy_left-xiao_ble-zmk.uf2' \
		'  build/artifacts/chippy_right-xiao_ble-zmk.uf2' \
		'  build/artifacts/keymap.svg'

init:
	@$(DOCKER_RUN) '$(WEST_SETUP)'

update:
	@$(DOCKER_RUN) 'if [ ! -d .west ]; then west init -l config; fi; west update --fetch-opt=--filter=tree:0; west zephyr-export'

check-keymap-drawer:
	@if ! command -v "$(KEYMAP_TOOL)" >/dev/null 2>&1; then \
		printf 'Missing dependency: %s\n' "$(KEYMAP_TOOL)"; \
		printf 'Install with: pip install keymap-drawer\n'; \
		exit 1; \
	fi
	@printf 'Using %s version %s\n' "$(KEYMAP_TOOL)" "$$($(KEYMAP_TOOL) --version)"

keymap-image: check-keymap-drawer
	@mkdir -p "$(ARTIFACTS_DIR)"
	@"$(KEYMAP_TOOL)" parse -z "$(KEYMAP_SOURCE)" -o "$(KEYMAP_YAML)"
	@"$(KEYMAP_TOOL)" -c "$(KEYMAP_CONFIG)" draw --ortho-layout '$(KEYMAP_ORTHO_LAYOUT)' "$(KEYMAP_YAML)" -o "$(KEYMAP_SVG)"
	@printf 'Generated %s\n' "$(KEYMAP_SVG)"

build: build-left build-right keymap-image
	@printf '\nBuild complete.\n'
	@printf 'Left artifact:  %s\n' "$(LEFT_ARTIFACT)"
	@printf 'Right artifact: %s\n' "$(RIGHT_ARTIFACT)"
	@printf 'Keymap image:   %s\n' "$(KEYMAP_SVG)"

build-left: init artifact-left

build-right: init artifact-right

artifact-left:
	@$(DOCKER_RUN) '$(BUILD_ENV_SETUP); west -v build -p always -s zmk/app -d $(LEFT_BUILD_DIR) -b $(BOARD_BUILD) -- -DZMK_CONFIG=$(ZMK_CONFIG) -DSHIELD=$(LEFT_SHIELD)'
	@mkdir -p "$(ARTIFACTS_DIR)"
	@cp "$(LEFT_BUILD_DIR)/zephyr/zmk.uf2" "$(LEFT_ARTIFACT)"
	@printf 'Generated %s\n' "$(LEFT_ARTIFACT)"

artifact-right:
	@$(DOCKER_RUN) '$(BUILD_ENV_SETUP); west -v build -p always -s zmk/app -d $(RIGHT_BUILD_DIR) -b $(BOARD_BUILD) -- -DZMK_CONFIG=$(ZMK_CONFIG) -DSHIELD=$(RIGHT_SHIELD)'
	@mkdir -p "$(ARTIFACTS_DIR)"
	@cp "$(RIGHT_BUILD_DIR)/zephyr/zmk.uf2" "$(RIGHT_ARTIFACT)"
	@printf 'Generated %s\n' "$(RIGHT_ARTIFACT)"

clean:
	@rm -rf "$(LEFT_BUILD_DIR)" "$(RIGHT_BUILD_DIR)" "$(ARTIFACTS_DIR)"
	@printf 'Removed build outputs.\n'

rebuild: clean build
