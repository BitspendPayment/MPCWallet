# ═══════════════════════════════════════════════════════════════════════════════
#  MPC Wallet — Makefile
#
#  Primary commands:
#    make e2e            Run E2E test (no Ark)
#    make e2e-ark        Run Ark E2E test
#    make hardware       Start regtest for hardware device (no Ark)
#    make hardware-ark   Start regtest for hardware device with Ark
#    make flash          Build & flash Pico 2 firmware (UF2)
#    make down           Stop everything
# ═══════════════════════════════════════════════════════════════════════════════

.PHONY: e2e e2e-ark hardware hardware-ark flash down \
	ffi-build ffi-android threshold-ffi-build threshold-ffi-android ark-ffi-build ark-ffi-android enclave-ffi-build enclave-ffi-android \
	cosigner-build server-build signer-build pico-build \
	regtest-up regtest-down bitcoin-init mine-loop adb-reverse \
	signer-run signer-stop server-run server-stop \
	arkd-up arkd-down arkd-init \
	proto threshold-test threshold-ffi-test pico-flash-probe pico-test \
	flutter flutter-run ark-newaddress crypto-bench \
	stress-test load-test \
	signet-hardware-ark signet-down e2e-mutinynet e2e-mutinynet-ark \
	e2e-test e2e-ark-test regtest regtest-ark regtest-hardware regtest-hardware-ark regtest-hardware-ark-down pico-flash

# ── Variables ─────────────────────────────────────────────────────────────────

export DATA_DIR=/tmp/mpc_wallet_stress

NDK_VERSION ?= 27.0.12077973
NDK_HOME     = $(HOME)/Android/Sdk/ndk/$(NDK_VERSION)

MUTINYNET_ASP_URL ?= http://localhost:7070
SESSIONS          ?= 10
CONCURRENCY       ?= 5
SIGNER_PORT       ?= 9090
SERVER            ?= 127.0.0.1:50051

# ═══════════════════════════════════════════════════════════════════════════════
#  PRIMARY COMMANDS
# ═══════════════════════════════════════════════════════════════════════════════

# 1) Run E2E test (no Ark) — builds server + signer, runs test, cleans up
e2e: threshold-ffi-build cosigner-build server-build signer-run
	@echo "Running E2E test..."
	cd e2e && dart test test/full_system_test.dart
	-pkill -f "signer-server" || true

# 2) Run Ark E2E test — starts regtest + arkd, builds everything, tests, cleans up
e2e-ark: server-stop signer-stop arkd-up bitcoin-init arkd-init signer-run ffi-build cosigner-build server-build
	@echo "Running Ark E2E test..."
	cd e2e && dart test test/ark_e2e_test.dart
	-pkill -f "signer-server" || true

# 3) Start regtest for hardware device (no Ark) — server runs in foreground
hardware: regtest-up bitcoin-init adb-reverse cosigner-build server-build ffi-build ffi-android
	@echo "Starting mine loop in background..."
	@(while true; do ./scripts/bitcoin.sh mine 2>/dev/null; sleep 10; done) &
	@echo ""
	@echo "==> Run Flutter in a separate terminal:  cd ap && flutter run"
	@echo "==> Server logs below (Ctrl+C to stop):"
	@echo ""
	export ELECTRUM_URL=127.0.0.1 && \
	export ELECTRUM_PORT=50001 && \
	export BITCOIN_RPC_USER=admin1 && \
	export BITCOIN_RPC_PASSWORD=123 && \
	cd server && cargo run --release -- \
		--wasm ../cosigner/target/wasm32-wasip1/release/cosigner.wasm \
		--port 50051

# 4) Start regtest for hardware device with Ark — server runs in foreground
hardware-ark: cosigner-build server-build ffi-build ffi-android
	@echo "=== Starting regtest + arkd ==="
	docker compose -f docker-compose.yml -f docker-compose.ark.yml up -d
	@echo "Waiting for services to stabilize (10s)..."
	@sleep 10
	@echo "=== Initializing Bitcoin chain ==="
	./scripts/bitcoin.sh init
	@echo "=== Initializing arkd ==="
	./scripts/arkd_init.sh --fund
	@echo "=== Setting up ADB reverse ==="
	-adb reverse tcp:50051 tcp:50051
	-adb reverse tcp:50001 tcp:50001
	@echo ""
	@echo "Starting mine loop in background..."
	@(while true; do ./scripts/bitcoin.sh mine 2>/dev/null; sleep 10; done) &
	@echo ""
	@echo "==> Run Flutter in a separate terminal:  cd ap && flutter run"
	@echo "==> Server logs below (Ctrl+C to stop):"
	@echo ""
	export ELECTRUM_URL=127.0.0.1 && \
	export ELECTRUM_PORT=50001 && \
	export BITCOIN_RPC_USER=admin1 && \
	export BITCOIN_RPC_PASSWORD=123 && \
	export ASP_URL=http://127.0.0.1:7070 && \
	cd server && cargo run --release -- \
		--wasm ../cosigner/target/wasm32-wasip1/release/cosigner.wasm \
		--port 50051

# 5) Build and flash Pico 2 firmware via UF2 (hold BOOTSEL + plug in USB first)
flash: pico-build
	@echo "Converting ELF to UF2..."
	cp pico-signer/target/thumbv8m.main-none-eabihf/release/pico-signer pico-signer/pico-signer.elf
	picotool uf2 convert pico-signer/pico-signer.elf pico-signer/pico-signer.uf2 --family rp2350-arm-s
	@echo ""
	@echo "==> Created pico-signer/pico-signer.uf2"
	@echo "==> Copy to the RP2350 drive:  cp pico-signer/pico-signer.uf2 /media/$$USER/RP2350/"
	@echo ""
	@if [ -d "/media/$$USER/RP2350" ]; then \
		cp pico-signer/pico-signer.uf2 /media/$$USER/RP2350/ && \
		echo "Copied! Pico will reboot with new firmware."; \
	else \
		echo "RP2350 drive not found. Hold BOOTSEL + plug in the Pico, then run:"; \
		echo "  cp pico-signer/pico-signer.uf2 /media/$$USER/RP2350/"; \
	fi

# Stop everything (server, signer, mine loop, Docker)
down:
	@echo "Stopping all services..."
	-pkill -f "target/release/server" || true
	-pkill -f "signer-server" || true
	-pkill -f "bitcoin.sh mine" || true
	-sudo fuser -k 50051/tcp 2>/dev/null || true
	-docker compose -f docker-compose.yml -f docker-compose.ark.yml down 2>/dev/null || true
	sudo rm -rf /root/.mpc_wallet/server/db 2>/dev/null || true
	sudo rm -rf $(DATA_DIR) 2>/dev/null || true
	@echo "All stopped."

# ═══════════════════════════════════════════════════════════════════════════════
#  BUILD TARGETS
# ═══════════════════════════════════════════════════════════════════════════════

# Combined FFI builds
ffi-build: threshold-ffi-build ark-ffi-build enclave-ffi-build

ffi-android: threshold-ffi-android ark-ffi-android enclave-ffi-android

# Individual FFI builds
threshold-ffi-build:
	@echo "Building threshold-ffi..."
	cd threshold-ffi && cargo build --release
	@echo "Built: threshold-ffi/target/release/libthreshold_ffi.so"

ark-ffi-build:
	@echo "Building ark-ffi..."
	cd ark-ffi && cargo build --release
	@echo "Built: ark-ffi/target/release/libark_ffi.so"

threshold-ffi-android:
	@echo "Building threshold-ffi for Android arm64..."
	export PATH="$(NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64/bin:$$PATH" && \
	cd threshold-ffi && cargo build --release --target aarch64-linux-android
	mkdir -p ap/android/app/src/main/jniLibs/arm64-v8a
	cp threshold-ffi/target/aarch64-linux-android/release/libthreshold_ffi.so \
		ap/android/app/src/main/jniLibs/arm64-v8a/
	@echo "Installed: ap/android/app/src/main/jniLibs/arm64-v8a/libthreshold_ffi.so"

ark-ffi-android:
	@echo "Building ark-ffi for Android arm64..."
	export PATH="$(NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64/bin:$$PATH" && \
	cd ark-ffi && cargo build --release --target aarch64-linux-android
	mkdir -p ap/android/app/src/main/jniLibs/arm64-v8a
	cp ark-ffi/target/aarch64-linux-android/release/libark_ffi.so \
		ap/android/app/src/main/jniLibs/arm64-v8a/
	@echo "Installed: ap/android/app/src/main/jniLibs/arm64-v8a/libark_ffi.so"

enclave-ffi-build:
	@echo "Building enclave-ffi..."
	cd enclave-ffi && cargo build --release
	@echo "Built: enclave-ffi/target/release/libenclave_ffi.so"

enclave-ffi-android:
	@echo "Building enclave-ffi for Android arm64..."
	export PATH="$(NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64/bin:$$PATH" && \
	cd enclave-ffi && cargo build --release --target aarch64-linux-android
	mkdir -p ap/android/app/src/main/jniLibs/arm64-v8a
	cp enclave-ffi/target/aarch64-linux-android/release/libenclave_ffi.so \
		ap/android/app/src/main/jniLibs/arm64-v8a/
	@echo "Installed: ap/android/app/src/main/jniLibs/arm64-v8a/libenclave_ffi.so"

# Server & cosigner
cosigner-build:
	@echo "Building cosigner WASM component..."
	cd cosigner && cargo component build --release
	@echo "Built: cosigner/target/wasm32-wasip1/release/cosigner.wasm"

server-build:
	@echo "Building server..."
	cd server && cargo build --release

signer-build:
	@echo "Building Hardware Signer Test Server..."
	-sudo chown -R $(USER):$(USER) e2e/signer-server/target 2>/dev/null || true
	cd e2e/signer-server && cargo build --release

pico-build:
	@echo "Building Pico Signer firmware..."
	cd pico-signer && cargo build --release

# ═══════════════════════════════════════════════════════════════════════════════
#  INFRASTRUCTURE
# ═══════════════════════════════════════════════════════════════════════════════

regtest-up:
	@echo "Starting Regtest environment..."
	docker compose up -d
	@echo "Waiting for services to stabilize..."
	@sleep 5

bitcoin-init:
	./scripts/bitcoin.sh init

mine-loop:
	@echo "Mining a block every 10s (Ctrl+C to stop)..."
	@while true; do ./scripts/bitcoin.sh mine; sleep 10; done

adb-reverse:
	@echo "Setting up ADB reverse port forwarding..."
	-adb reverse tcp:50051 tcp:50051
	-adb reverse tcp:50001 tcp:50001
	@echo "Forwarding active: phone 127.0.0.1:50051 -> PC gRPC server"
	@echo "Forwarding active: phone 127.0.0.1:50001 -> PC Electrs"

signer-run: signer-build
	@echo "Starting Hardware Signer Test Server on port 9090..."
	cd e2e/signer-server && cargo run --release -- --port 9090 &
	@sleep 2

signer-stop:
	@echo "Stopping Hardware Signer Test Server..."
	-sudo pkill -9 -f "signer-server" || true
	-sudo pkill -9 signer-server || true
	@sleep 1

server-run: cosigner-build server-build
	@echo "Starting MPC Wallet Server on port 50051..."
	export ELECTRUM_URL=127.0.0.1 && \
	export ELECTRUM_PORT=50001 && \
	export BITCOIN_RPC_USER=admin1 && \
	export BITCOIN_RPC_PASSWORD=123 && \
	cd server && cargo run --release --bin server -- \
		--wasm ../cosigner/target/wasm32-wasip1/release/cosigner.wasm \
		--port 50051 &
	@sleep 2
	@echo "MPC Wallet Server running in background."

server-stop:
	@echo "Stopping MPC Wallet Server..."
	-sudo fuser -k 50051/tcp || true
	-sudo pkill -9 -f "target/release/server" || true
	-sudo pkill -9 -f "server --wasm" || true
	-sudo pkill -9 server || true
	sudo rm -rf $(DATA_DIR) || true
	@sleep 2

arkd-up:
	@echo "Starting regtest + arkd (ASP) services..."
	docker compose -f docker-compose.yml -f docker-compose.ark.yml up -d
	@echo "Waiting for arkd to start (30s)..."
	@sleep 30

arkd-down:
	@echo "Stopping arkd services..."
	docker compose -f docker-compose.yml -f docker-compose.ark.yml down

arkd-init:
	@echo "Initializing arkd wallet..."
	./scripts/arkd_init.sh --fund

# ═══════════════════════════════════════════════════════════════════════════════
#  UTILITY
# ═══════════════════════════════════════════════════════════════════════════════

proto:
	@echo "Generating Dart gRPC stubs..."
	protoc -I protocol/protos --dart_out=grpc:protocol/lib/src/generated protocol/protos/mpc_wallet.proto

threshold-test:
	@echo "Running threshold tests..."
	cd threshold && cargo test --features std

threshold-ffi-test:
	@echo "Running threshold-ffi tests..."
	cd threshold-ffi && cargo test

pico-flash-probe: pico-build
	@echo "Flashing via debug probe..."
	cd pico-signer && cargo run --release

pico-test:
	@echo "Testing Pico Signer over USB HID..."
	scripts/.venv/bin/python3 scripts/test_pico.py $(ARGS)

flutter: ffi-android
	cd ap && flutter run

ark-newaddress:
	@cd e2e && dart run bin/ark_newaddress.dart

crypto-bench:
	@echo "Running Rust cryptography benchmarks..."
	cd threshold && cargo bench

# ═══════════════════════════════════════════════════════════════════════════════
#  STRESS / LOAD TESTING
# ═══════════════════════════════════════════════════════════════════════════════

stress-test: server-stop signer-stop regtest-up bitcoin-init signer-run server-run
	@echo "Running Multi-User E2E Stress Test..."
	cd e2e && dart test test/multi_user_stress_test.dart
	@$(MAKE) server-stop
	@$(MAKE) signer-stop

load-test: server-stop signer-stop regtest-up bitcoin-init signer-run server-run
	@echo "Running Dart Load Tester (sessions=$(SESSIONS), concurrency=$(CONCURRENCY))..."
	cd e2e && dart pub get && \
		dart run bin/load_tester.dart \
			--server $(SERVER) \
			--signer-host 127.0.0.1 \
			--signer-port $(SIGNER_PORT) \
			--sessions $(SESSIONS) \
			--concurrency $(CONCURRENCY)
	@$(MAKE) server-stop
	@$(MAKE) signer-stop

# ═══════════════════════════════════════════════════════════════════════════════
#  SIGNET / MUTINYNET
# ═══════════════════════════════════════════════════════════════════════════════

signet-hardware-ark: cosigner-build server-build ffi-build ffi-android
	@echo "=== Setting up ADB reverse ==="
	-adb reverse tcp:50051 tcp:50051
	@echo ""
	@echo "==> Run Flutter in a separate terminal:  cd ap && flutter run"
	@echo "==> Server logs below (Ctrl+C to stop):"
	@echo ""
	export ELECTRUM_URL=electrum.mutinynet.com && \
	export ELECTRUM_PORT=50001 && \
	export BITCOIN_NETWORK=signet && \
	export ASP_URL=$(MUTINYNET_ASP_URL) && \
	cd server && cargo run --release -- \
		--wasm ../cosigner/target/wasm32-wasip1/release/cosigner.wasm \
		--port 50051

signet-down:
	@echo "Stopping MPC server..."
	-pkill -f "target/release/server" || true
	@echo "Stopped."

e2e-mutinynet: threshold-ffi-build cosigner-build server-build signer-run
	@echo "Running MutinyNet E2E test..."
	cd e2e && dart test test/mutinynet_e2e_test.dart --timeout 600s
	-pkill -f "signer-server" || true

e2e-mutinynet-ark: ffi-build cosigner-build server-build signer-run
	@echo "Running MutinyNet Ark E2E test..."
	cd e2e && dart test test/mutinynet_ark_e2e_test.dart --timeout 900s
	-pkill -f "signer-server" || true

# ═══════════════════════════════════════════════════════════════════════════════
#  LEGACY ALIASES (old names still work)
# ═══════════════════════════════════════════════════════════════════════════════

e2e-test: e2e
e2e-ark-test: e2e-ark
regtest: regtest-up bitcoin-init signer-run server-run
regtest-ark: server-stop signer-stop arkd-up bitcoin-init arkd-init signer-run
regtest-down: down
regtest-hardware: hardware
regtest-hardware-ark: hardware-ark
regtest-hardware-ark-down: down
pico-flash: flash
