# Makefile for Flutter Project Automation

.PHONY: all help clean get upgrade generate watch analyze format format-check fix-dry-run lint test coverage test-all devices emulators run attach build-apk build-apk-arm64 build-apk-x64 build-bundle

# Default target
all: help

## Help: Display available commands
help:
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

## Basic Setup
clean: ## Run flutter clean
	flutter clean

get: ## Run flutter pub get
	flutter pub get

upgrade: ## Run flutter pub upgrade
	flutter pub upgrade

## Code Generation
generate: ## Run build_runner build
	flutter pub run build_runner build --delete-conflicting-outputs

watch: ## Run build_runner watch
	flutter pub run build_runner watch --delete-conflicting-outputs

## Quality and Linting
analyze: ## Run flutter analyze
	flutter analyze

format: ## Run dart format
	dart format .

format-check: ## Run dart format check
	dart format --set-exit-if-changed .

fix-dry-run: ## Run dart fix dry-run
	dart fix --dry-run

lint: analyze format-check fix-dry-run ## Run all quality checks (analyze, format-check, fix-dry-run)

## Testing and Coverage
test: ## Run flutter tests
	flutter test

coverage: ## Run tests with coverage and generate HTML report
	flutter test --coverage
	./tool/check_coverage.py

test-all: lint test ## Run lint and then tests

## Device and Emulator
devices: ## List connected devices
	flutter devices

emulators: ## List available emulators
	flutter emulators

run: ## Run the app
	flutter run -d emulator-5554

attach: ## Attach to a running app
	flutter attach

## Build
build-apk: ## Build APK for all architectures
	flutter build apk

build-apk-arm64: ## Build APK for android-arm64
	flutter build apk --target-platform android-arm64

build-apk-x64: ## Build APK for android-x64
	flutter build apk --target-platform android-x64

build-bundle: ## Build Android App Bundle
	flutter build appbundle
