# Makefile for PharmaScan
# Unified build automation for backend (TypeScript/Bun) and frontend (Flutter/Dart)
#
# Usage:
#   make build              # Build everything (backend + frontend)
#   make backend            # Build backend pipeline only
#   make frontend           # Build frontend (analyze + codegen)
#   make test               # Run all tests
#   make clean              # Clean build artifacts
#   make preflight          # Full pipeline: download + build + export + audit
#   make watch              # Watch code changes (frontend)

# =============================================================================
# Configuration
# =============================================================================

ROOT_DIR := $(shell pwd)
BACKEND_DIR := $(ROOT_DIR)/backend_pipeline
FRONTEND_DIR := $(ROOT_DIR)
FLUTTER := $(shell which flutter)
DART := $(shell which dart)

# Detect platform
UNAME_S := $(shell uname -s)
PLATFORM := unknown
ifeq ($(UNAME_S),Linux)
	PLATFORM := linux
else ifeq ($(UNAME_S),Darwin)
	PLATFORM := macos
endif

# =============================================================================
# Phony targets (non-file targets)
# =============================================================================

.PHONY: all build backend frontend test clean preflight watch help
.PHONY: backend-build backend-test frontend-build frontend-analyze frontend-codegen
.PHONY: backend-export backend-preflight
.PHONY: format analyze lint

# =============================================================================
# Default target - build everything
# =============================================================================

all: build

# =============================================================================
# Main build targets
# =============================================================================

build: frontend-build
	@echo "✅ Build complete!"

backend: backend-build
	@echo "✅ Backend complete!"

frontend: frontend-build
	@echo "✅ Frontend complete!"

# =============================================================================
# Backend targets (Bun + TypeScript)
# =============================================================================

backend-build:
	@echo "📦 Building backend pipeline..."
	cd $(BACKEND_DIR) && bun run build

backend-test:
	@echo "🧪 Running backend tests..."
	cd $(BACKEND_DIR) && bun test

backend-export:
	@echo "📋 Exporting schema and generating Dart code..."
	cd $(BACKEND_DIR) && bun run export

backend-preflight:
	@echo "🚀 Running full backend pipeline..."
	cd $(BACKEND_DIR) && bun run preflight

# =============================================================================
# Frontend targets (Flutter + Dart)
# =============================================================================

frontend-build: frontend-codegen
	@echo "📱 Frontend build complete"

frontend-codegen:
	@echo "🔧 Generating code..."
	cd $(FRONTEND_DIR) && dart run build_runner build --delete-conflicting-outputs

frontend-analyze:
	@echo "🔍 Analyzing code..."
	cd $(FRONTEND_DIR) && flutter analyze --no-pub

frontend-format:
	@echo "✨ Formatting code..."
	cd $(FRONTEND_DIR) && dart format . -l 120

frontend-lint:
	@echo "🔍 Running linter..."
	cd $(FRONTEND_DIR) && dart fix --apply

frontend-test:
	@echo "🧪 Running frontend tests..."
	cd $(FRONTEND_DIR) && flutter test

frontend-watch:
	@echo "👀 Watching for code changes..."
	cd $(FRONTEND_DIR) && flutter pub run build_runner watch -d

# =============================================================================
# Combined targets
# =============================================================================

test: backend-test frontend-test
	@echo "✅ All tests passed!"

analyze: frontend-analyze
	@echo "✅ Analysis complete!"

format: frontend-format
	@echo "✅ Code formatted!"

lint: frontend-lint
	@echo "✅ Linter fixes applied!"

# =============================================================================
# Development workflow targets
# =============================================================================

# Full development pipeline: download BDPM data, build backend, export schema
preflight:
	@echo "🚀 Running full preflight..."
	cd $(BACKEND_DIR) && bun run preflight
	@echo "✅ Preflight complete!"

# Watch for code changes during development (frontend only)
watch:
	@echo "👀 Watching for code changes..."
	cd $(FRONTEND_DIR) && flutter pub run build_runner watch -d

# =============================================================================
# Clean targets
# =============================================================================

clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf $(BACKEND_DIR)/output
	cd $(FRONTEND_DIR) && flutter clean
	cd $(BACKEND_DIR) && rm -rf .cache
	@echo "✅ Clean complete!"

clean-all: clean
	@echo "🧹 Deep cleaning..."
	cd $(FRONTEND) && flutter clean && rm -rf pubspec.lock
	cd $(BACKEND_DIR) && rm -rf node_modules bun.lockb
	@echo "✅ Deep clean complete!"

# =============================================================================
# Installation targets
# =============================================================================

install-backend:
	@echo "📦 Installing backend dependencies..."
	cd $(BACKEND_DIR) && bun install

install-frontend:
	@echo "📦 Installing frontend dependencies..."
	cd $(FRONTEND_DIR) && flutter pub get

install: install-backend install-frontend
	@echo "✅ All dependencies installed!"

# =============================================================================
# Database and export targets
# =============================================================================

# Export JSON contracts only (for debugging)
export-json:
	@echo "📋 Exporting JSON contracts only..."
	cd $(BACKEND_DIR) && bun run export:json

# Sync schema to Flutter (legacy)
export-schema:
	@echo "📋 Syncing schema to Flutter..."
	cd $(BACKEND_DIR) && bun run export:schema

# =============================================================================
# Quality gates
# =============================================================================

check: format analyze lint test
	@echo "✅ All quality checks passed!"

# =============================================================================
# Platform-specific build targets
# =============================================================================

# Build Android APK
build-android:
	@echo "🤖 Building Android APK..."
	cd $(FRONTEND_DIR) && flutter build apk --release

# Build iOS
build-ios:
	@echo "🍎 Building iOS app..."
	cd $(FRONTEND_DIR) && flutter build ios --release --no-codesign

# Build for current platform
build-$(PLATFORM):
	@echo "🖥️ Building for $(PLATFORM)..."
	cd $(FRONTEND_DIR) && flutter build $(PLATFORM) --release

# =============================================================================
# Help target
# =============================================================================

help:
	@echo "PharmaScan Makefile"
	@echo ""
	@echo "Main targets:"
	@echo "  make build           - Build backend + frontend (default)"
	@echo "  make backend         - Build backend pipeline only"
	@echo "  make frontend        - Build frontend (analyze + codegen)"
	@echo ""
	@echo "Backend targets:"
	@echo "  make backend-build   - Run backend pipeline"
	@echo "  make backend-test    - Run backend tests"
	@echo "  make backend-export  - Export schema + generate Dart code"
	@echo "  make backend-preflight - Full pipeline: download + build + export + audit"
	@echo ""
	@echo "Frontend targets:"
	@echo "  make frontend-codegen - Run build_runner code generation"
	@echo "  make frontend-analyze - Run Flutter analyze"
	@echo "  make frontend-format  - Format Dart code"
	@echo "  make frontend-test    - Run Flutter tests"
	@echo "  make frontend-watch   - Watch for code changes"
	@echo ""
	@echo "Combined targets:"
	@echo "  make test            - Run all tests (backend + frontend)"
	@echo "  make analyze         - Analyze code"
	@echo "  make format          - Format code"
	@echo "  make lint            - Apply linter fixes"
	@echo "  make check           - Run all quality checks (format + analyze + lint + test)"
	@echo ""
	@echo "Development workflow:"
	@echo "  make preflight       - Full backend pipeline (download + build + export)"
	@echo "  make watch           - Watch for code changes (frontend)"
	@echo ""
	@echo "Build targets:"
	@echo "  make build-android   - Build Android APK"
	@echo "  make build-ios        - Build iOS app"
	@echo "  make build-$(PLATFORM) - Build for current platform"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean           - Clean build artifacts"
	@echo "  make clean-all       - Deep clean (including dependencies)"
	@echo "  make install         - Install all dependencies"
	@echo ""
	@echo "Export (for debugging):"
	@echo "  make export-json     - Export JSON contracts only"
	@echo "  make export-schema   - Sync schema to Flutter (legacy)"
	@echo ""
	@echo "Installation:"
	@echo "  make install-backend - Install backend dependencies (Bun)"
	@echo "  make install-frontend - Install frontend dependencies (Flutter)"
