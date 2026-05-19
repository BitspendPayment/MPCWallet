# ═══════════════════════════════════════════════════════════════════════════════
#  MPC Wallet — Makefile
#
#  Primary commands:
#    make e2e            Run E2E test (no Ark)
#    make e2e-ark        Run Ark E2E test
#    make software       Start regtest for software signer (no USB device, no Ark)
#    make hardware       Start regtest for hardware device (no Ark)
#    make hardware-ark   Start regtest for hardware device with Ark
#    make hw-build       Build HW Signer TrustZone firmware (Secure + NS)
#    make hw-flash       Flash HW Signer via debug probe
#    make hw-test        Smoke test HW Signer over USB HID
#    make down           Stop everything
# ═══════════════════════════════════════════════════════════════════════════════

.PHONY: e2e e2e-ark software software-ark hardware hardware-ark flash down \
	bob-up bob-down \
	ffi-build ffi-test ffi-android ffi-android-arm32 ffi-android-all \
	threshold-ffi-build ark-ffi-build enclave-ffi-build threshold-ffi-test \
	threshold-ffi-android ark-ffi-android enclave-ffi-android \
	threshold-ffi-android-32 ark-ffi-android-32 enclave-ffi-android-32 \
	cosigner-build runtime-build signer-build pico-build \
	hw-build hw-build-secure hw-build-ns hw-flash hw-flash-probe hw-test \
	regtest-up regtest-down bitcoin-init mine-loop adb-reverse \
	signer-run signer-stop runtime-run runtime-stop \
	arkd-up arkd-down arkd-init \
	proto threshold-test \
	flutter flutter-run ark-newaddress crypto-bench \
	stress-test load-test \
	signet-hardware-ark signet-down e2e-mutinynet e2e-mutinynet-ark \
	e2e-test e2e-ark-test regtest regtest-ark regtest-hardware regtest-hardware-ark regtest-hardware-ark-down \
	integration-test integration-test-ci integration-test-ci-ark

# ── Variables ─────────────────────────────────────────────────────────────────

export DATA_DIR=/tmp/mpc_wallet_stress

NDK_VERSION ?= 27.0.12077973
NDK_HOME     = $(HOME)/Android/Sdk/ndk/$(NDK_VERSION)

MUTINYNET_ASP_URL ?= http://localhost:7070
SESSIONS          ?= 10
CONCURRENCY       ?= 5
SIGNER_PORT       ?= 9090
SERVER            ?= 127.0.0.1:7074

# ═══════════════════════════════════════════════════════════════════════════════
#  PRIMARY COMMANDS
# ═══════════════════════════════════════════════════════════════════════════════

# 1) Run E2E test (no Ark) — builds server + signer, runs test, cleans up
e2e: threshold-ffi-build cosigner-build runtime-build signer-run
	@echo "Running E2E test..."
	cd e2e && dart test test/full_system_test.dart
	-pkill -f "signer-server" || true

# 2) Run Ark E2E test — starts regtest + arkd, builds everything, tests, cleans up
e2e-ark: runtime-stop signer-stop arkd-up bitcoin-init arkd-init signer-run ffi-build cosigner-build runtime-build
	@echo "Running Ark E2E test..."
	cd e2e && dart test test/ark_e2e_test.dart
	-pkill -f "signer-server" || true

# 3) Start regtest for SOFTWARE signer (no USB device required) — server in foreground
#    Identical infrastructure to `make hardware`; only difference is the banner.
#    The Rust signer-server (port 9090) is NOT started — software signer runs
#    in-app via threshold-ffi.
software: regtest-up bitcoin-init adb-reverse cosigner-build runtime-build ffi-build ffi-android
	@echo ""
	@echo "==> Software signer mode — no USB device required."
	@echo "==> Run Flutter in a separate terminal:  cd app && flutter run"
	@echo "==> In the app, pick 'Software Signer' (default) on the first screen."
	@echo "==> Server logs below (Ctrl+C to stop server + mine loop):"
	@echo ""
	@bash -c 'set -m; \
		(while true; do ./scripts/bitcoin.sh mine 2>/dev/null; sleep 10; done) & \
		MINE_PID=$$!; \
		trap "kill $$MINE_PID 2>/dev/null || true; wait $$MINE_PID 2>/dev/null || true" EXIT INT TERM; \
		export ELECTRUM_URL=127.0.0.1 ELECTRUM_PORT=50001 \
		       BITCOIN_RPC_USER=admin1 BITCOIN_RPC_PASSWORD=123; \
		cd cosigner-runtime && cargo run --release --bin cosigner-runtime -- \
			--wasm ../cosigner/target/wasm32-wasip1/release/cosigner.wasm \
			--port 7074'

# 3b) Start regtest + arkd for SOFTWARE signer (no USB device required) — Ark enabled
software-ark: cosigner-build runtime-build ffi-build ffi-android
	@echo "=== Tearing down any prior stack (volumes too, for fresh keys) ==="
	-pkill -f "target/release/cosigner-runtime" || true
	-pkill -f bob_proxy || true
	-docker compose -f docker-compose.yml -f docker-compose.ark.yml down -v 2>/dev/null || true
	-sudo rm -rf /root/.mpc_wallet/cosigner-runtime/db 2>/dev/null || true
	-sudo rm -rf /tmp/bob_ark 2>/dev/null || true
	@echo "=== Starting regtest + arkd ==="
	docker compose -f docker-compose.yml -f docker-compose.ark.yml up -d
	@echo "Waiting for services to stabilize (20s)..."
	@sleep 20
	@echo "=== Initializing Bitcoin chain ==="
	./scripts/bitcoin.sh init
	@echo "=== Initializing arkd ==="
	./scripts/arkd_init.sh --fund
	@echo "=== Waiting 10s for NBXplorer to index initial blocks ==="
	@sleep 10
	@echo "=== Setting up Bob (ark-sample counter-party) ==="
	$(MAKE) bob-up
	@echo "=== Setting up ADB reverse ==="
	-adb reverse tcp:7074 tcp:7074
	-adb reverse tcp:50001 tcp:50001
	-adb reverse tcp:7090 tcp:7090
	@echo ""
	@echo "==> Software signer mode + Ark — no USB device required."
	@echo "==> Run Flutter in a separate terminal:  cd app && flutter run"
	@echo "==> In the app, pick 'Software Signer' (default) on the first screen."
	@echo "==> Server logs below (Ctrl+C to stop server + mine loop):"
	@echo ""
	@bash -c 'set -m; \
		(while true; do ./scripts/bitcoin.sh mine 2>/dev/null; sleep 10; done) & \
		MINE_PID=$$!; \
		trap "kill $$MINE_PID 2>/dev/null || true; wait $$MINE_PID 2>/dev/null || true" EXIT INT TERM; \
		export ELECTRUM_URL=127.0.0.1 ELECTRUM_PORT=50001 \
		       BITCOIN_RPC_USER=admin1 BITCOIN_RPC_PASSWORD=123 \
		       ASP_URL=http://127.0.0.1:7070; \
		cd cosigner-runtime && cargo run --release --bin cosigner-runtime -- \
			--wasm ../cosigner/target/wasm32-wasip1/release/cosigner.wasm \
			--port 7074'

# 4) Start regtest for hardware device (no Ark) — server runs in foreground
hardware: regtest-up bitcoin-init adb-reverse cosigner-build runtime-build ffi-build ffi-android
	@echo ""
	@echo "==> Hardware signer mode — connect rp235x via USB OTG to phone."
	@echo "==> Run Flutter in a separate terminal:  cd app && flutter run"
	@echo "==> Server logs below (Ctrl+C to stop server + mine loop):"
	@echo ""
	@bash -c 'set -m; \
		(while true; do ./scripts/bitcoin.sh mine 2>/dev/null; sleep 10; done) & \
		MINE_PID=$$!; \
		trap "kill $$MINE_PID 2>/dev/null || true; wait $$MINE_PID 2>/dev/null || true" EXIT INT TERM; \
		export ELECTRUM_URL=127.0.0.1 ELECTRUM_PORT=50001 \
		       BITCOIN_RPC_USER=admin1 BITCOIN_RPC_PASSWORD=123; \
		cd cosigner-runtime && cargo run --release --bin cosigner-runtime -- \
			--wasm ../cosigner/target/wasm32-wasip1/release/cosigner.wasm \
			--port 7074'

# 5) Start regtest for hardware device with Ark — server runs in foreground
hardware-ark: cosigner-build runtime-build ffi-build ffi-android
	@echo "=== Starting regtest + arkd ==="
	docker compose -f docker-compose.yml -f docker-compose.ark.yml up -d
	@echo "Waiting for services to stabilize (10s)..."
	@sleep 10
	@echo "=== Initializing Bitcoin chain ==="
	./scripts/bitcoin.sh init
	@echo "=== Initializing arkd ==="
	./scripts/arkd_init.sh --fund
	@echo "=== Setting up ADB reverse ==="
	-adb reverse tcp:7074 tcp:7074
	-adb reverse tcp:50001 tcp:50001
	@echo ""
	@echo "==> Run Flutter in a separate terminal:  cd app && flutter run"
	@echo "==> Server logs below (Ctrl+C to stop server + mine loop):"
	@echo ""
	@bash -c 'set -m; \
		(while true; do ./scripts/bitcoin.sh mine 2>/dev/null; sleep 10; done) & \
		MINE_PID=$$!; \
		trap "kill $$MINE_PID 2>/dev/null || true; wait $$MINE_PID 2>/dev/null || true" EXIT INT TERM; \
		export ELECTRUM_URL=127.0.0.1 ELECTRUM_PORT=50001 \
		       BITCOIN_RPC_USER=admin1 BITCOIN_RPC_PASSWORD=123 \
		       ASP_URL=http://127.0.0.1:7070; \
		cd cosigner-runtime && cargo run --release --bin cosigner-runtime -- \
			--wasm ../cosigner/target/wasm32-wasip1/release/cosigner.wasm \
			--port 7074'

# 5) Stop everything (server, signer, mine loop, Docker)
down:
	@echo "Stopping all services..."
	-pkill -f "target/release/cosigner-runtime" || true
	-pkill -f "signer-server" || true
	-pkill -f "bitcoin.sh mine" || true
	-pkill -f "bob_proxy" || true
	-sudo fuser -k 7074/tcp 2>/dev/null || true
	-sudo fuser -k 7090/tcp 2>/dev/null || true
	-docker compose -f docker-compose.yml -f docker-compose.ark.yml down 2>/dev/null || true
	sudo rm -rf /root/.mpc_wallet/cosigner-runtime/db 2>/dev/null || true
	sudo rm -rf $(DATA_DIR) 2>/dev/null || true
	@echo "All stopped."

# Bring up Bob — ark-sample wallet that acts as counter-party for the Flutter
# integration test. Requires arkd already running (call after arkd-init).
bob-up:
	@./scripts/bob_setup.sh
	@echo "==> Starting bob_proxy on :7090..."
	-pkill -f bob_proxy || true
	@nohup python3 scripts/bob_proxy.py > /tmp/bob_proxy.log 2>&1 &
	@sleep 1
	@curl -sf http://127.0.0.1:7090/ark-address | head -c 200 && echo

bob-down:
	-pkill -f bob_proxy || true
	-sudo fuser -k 7090/tcp 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
#  HW SIGNER (TrustZone — Secure + Non-Secure worlds)
# ═══════════════════════════════════════════════════════════════════════════════

# Build Secure world (rp235x-hal, crypto, SAU — generates target/veneers.o)
hw-build-secure:
	@echo "Building HW Signer Secure world..."
	cd hwsigner-secure && cargo +nightly build --release

# Build Non-Secure world (Embassy, USB HID — links veneers.o from Secure build)
hw-build-ns: hw-build-secure
	@echo "Building HW Signer Non-Secure world..."
	cd hwsigner && cargo clean && cargo +nightly build --release

# Build both worlds
hw-build: hw-build-ns

# Sign Secure world firmware (ECDSA secp256k1 + SHA-256)
hw-sign: hw-build
	@echo "Signing Secure world firmware..."
	cp hwsigner-secure/target/thumbv8m.main-none-eabihf/release/hwsigner-secure \
		hwsigner-secure/hwsigner-secure.elf
	picotool seal --sign --hash \
		hwsigner-secure/hwsigner-secure.elf \
		hwsigner-secure/hwsigner-secure-signed.elf \
		keys/ec_private_key.pem \
		keys/otp.json \
		--major 0 --minor 1
	@echo "Signed: hwsigner-secure/hwsigner-secure-signed.elf"

# Flash both worlds via debug probe (requires SWD probe connected)
hw-flash-probe: hw-sign
	@echo "Flashing via debug probe..."
	cp hwsigner/target/thumbv8m.main-none-eabihf/release/hwsigner hwsigner/hwsigner.elf
	probe-rs download --chip RP2350 hwsigner-secure/hwsigner-secure-signed.elf
	probe-rs download --chip RP2350 hwsigner/hwsigner.elf
	probe-rs reset --chip RP2350
	@echo "Flashed and reset!"

# Flash both worlds via BOOTSEL USB (hold BOOTSEL + plug in first)
hw-flash: hw-sign
	@echo "Flashing via picotool (device must be in BOOTSEL mode)..."
	cp hwsigner/target/thumbv8m.main-none-eabihf/release/hwsigner hwsigner/hwsigner.elf
	picotool load hwsigner-secure/hwsigner-secure-signed.elf --ignore-partitions --family rp2350-arm-s -v
	picotool load hwsigner/hwsigner.elf --ignore-partitions --family rp2350-arm-s -v
	picotool reboot
	@echo "Flashed and rebooted!"

# Smoke test HW Signer over USB HID (no phone needed)
hw-test:
	@echo "Testing HW Signer over USB HID..."
	scripts/.venv/bin/python3 scripts/test_hwsigner.py $(ARGS)

# ═══════════════════════════════════════════════════════════════════════════════
#  BUILD TARGETS
# ═══════════════════════════════════════════════════════════════════════════════

# Merged FFI: ark + threshold + enclave bindings build into one libmpcwallet_ffi.so
ffi-build:
	@echo "Building merged FFI (ark + threshold + enclave)..."
	cargo build --release --manifest-path ffi/Cargo.toml
	@echo "Built: ffi/target/release/libmpcwallet_ffi.so"

ffi-android: ## Build merged FFI for Android arm64
	@echo "Building merged FFI for Android arm64..."
	export PATH="$(NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64/bin:$$PATH" && \
	cargo build --release --manifest-path ffi/Cargo.toml --target aarch64-linux-android
	mkdir -p app/android/app/src/main/jniLibs/arm64-v8a
	cp ffi/target/aarch64-linux-android/release/libmpcwallet_ffi.so \
		app/android/app/src/main/jniLibs/arm64-v8a/
	@echo "Installed: app/android/app/src/main/jniLibs/arm64-v8a/libmpcwallet_ffi.so"

ffi-android-arm32: ## Build merged FFI for Android arm32 (armv7)
	@echo "Building merged FFI for Android arm32..."
	export PATH="$(NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64/bin:$$PATH" && \
	export CC_armv7_linux_androideabi=armv7a-linux-androideabi21-clang && \
	export AR_armv7_linux_androideabi=llvm-ar && \
	cargo build --release --manifest-path ffi/Cargo.toml --target armv7-linux-androideabi
	mkdir -p app/android/app/src/main/jniLibs/armeabi-v7a
	cp ffi/target/armv7-linux-androideabi/release/libmpcwallet_ffi.so \
		app/android/app/src/main/jniLibs/armeabi-v7a/
	@echo "Installed: app/android/app/src/main/jniLibs/armeabi-v7a/libmpcwallet_ffi.so"

ffi-android-x86_64: ## Build merged FFI for Android x86_64 (emulator on Intel/AMD hosts)
	@echo "Building merged FFI for Android x86_64..."
	export PATH="$(NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64/bin:$$PATH" && \
	cargo build --release --manifest-path ffi/Cargo.toml --target x86_64-linux-android
	mkdir -p app/android/app/src/main/jniLibs/x86_64
	cp ffi/target/x86_64-linux-android/release/libmpcwallet_ffi.so \
		app/android/app/src/main/jniLibs/x86_64/
	@echo "Installed: app/android/app/src/main/jniLibs/x86_64/libmpcwallet_ffi.so"

ffi-android-all: ffi-android ffi-android-arm32 ffi-android-x86_64   # arm64 + arm32 + x86_64

ffi-test:
	@echo "Running merged FFI tests..."
	cargo test --release --manifest-path ffi/Cargo.toml

# DEPRECATED aliases — point at the merged ffi-build/ffi-android. Kept for one
# release cycle so muscle memory and any out-of-tree scripts keep working.
threshold-ffi-build ark-ffi-build enclave-ffi-build: ffi-build
threshold-ffi-android ark-ffi-android enclave-ffi-android: ffi-android
threshold-ffi-android-32 ark-ffi-android-32 enclave-ffi-android-32: ffi-android-arm32
threshold-ffi-test: ffi-test

# Server & cosigner
cosigner-build:
	@echo "Building cosigner WASM component..."
	cd cosigner && cargo component build --release
	@echo "Built: cosigner/target/wasm32-wasip1/release/cosigner.wasm"

runtime-build:
	@echo "Building server..."
	cd cosigner-runtime && cargo build --release

signer-build:
	@echo "Building Hardware Signer Test Server..."
	-sudo chown -R $(USER):$(USER) e2e/signer-server/target 2>/dev/null || true
	cd e2e/signer-server && cargo build --release

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
	-adb reverse tcp:7074 tcp:7074
	-adb reverse tcp:50001 tcp:50001
	@echo "Forwarding active: phone 127.0.0.1:7074 -> PC REST server"
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

runtime-run: cosigner-build runtime-build
	@echo "Starting MPC Wallet Server on port 7074..."
	export ELECTRUM_URL=127.0.0.1 && \
	export ELECTRUM_PORT=50001 && \
	export BITCOIN_RPC_USER=admin1 && \
	export BITCOIN_RPC_PASSWORD=123 && \
	cd cosigner-runtime && cargo run --release --bin cosigner-runtime -- \
		--wasm ../cosigner/target/wasm32-wasip1/release/cosigner.wasm \
		--port 7074 &
	@sleep 2
	@echo "MPC Wallet Server running in background."

runtime-stop:
	@echo "Stopping MPC Wallet Server..."
	-sudo fuser -k 7074/tcp || true
	-sudo pkill -9 -f "target/release/cosigner-runtime" || true
	-sudo pkill -9 -f "cosigner-runtime --wasm" || true
	-sudo pkill -9 cosigner-runtime || true
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
	cd crates/threshold && cargo test --features std

flutter: ffi-android
	cd app && flutter run

flutter-32: ffi-android-all
	cd app && flutter run

flutter-x86: ffi-android-x86_64
	cd app && flutter run

ark-newaddress:
	@cd e2e && dart run bin/ark_newaddress.dart

crypto-bench:
	@echo "Running Rust cryptography benchmarks..."
	cd crates/threshold && cargo bench

# ═══════════════════════════════════════════════════════════════════════════════
#  STRESS / LOAD TESTING
# ═══════════════════════════════════════════════════════════════════════════════

stress-test: runtime-stop signer-stop regtest-up bitcoin-init signer-run runtime-run
	@echo "Running Multi-User E2E Stress Test..."
	cd e2e && dart test test/multi_user_stress_test.dart
	@$(MAKE) runtime-stop
	@$(MAKE) signer-stop

load-test: runtime-stop signer-stop regtest-up bitcoin-init signer-run runtime-run
	@echo "Running Dart Load Tester (sessions=$(SESSIONS), concurrency=$(CONCURRENCY))..."
	cd e2e && dart pub get && \
		dart run bin/load_tester.dart \
			--server $(SERVER) \
			--signer-host 127.0.0.1 \
			--signer-port $(SIGNER_PORT) \
			--sessions $(SESSIONS) \
			--concurrency $(CONCURRENCY)
	@$(MAKE) runtime-stop
	@$(MAKE) signer-stop

# ═══════════════════════════════════════════════════════════════════════════════
#  SIGNET / MUTINYNET
# ═══════════════════════════════════════════════════════════════════════════════

signet-hardware-ark: cosigner-build runtime-build ffi-build ffi-android
	@echo "=== Setting up ADB reverse ==="
	-adb reverse tcp:7074 tcp:7074
	@echo ""
	@echo "==> Run Flutter in a separate terminal:  cd app && flutter run"
	@echo "==> Server logs below (Ctrl+C to stop):"
	@echo ""
	export ELECTRUM_URL=electrum.mutinynet.com && \
	export ELECTRUM_PORT=50001 && \
	export BITCOIN_NETWORK=signet && \
	export ASP_URL=$(MUTINYNET_ASP_URL) && \
	cd cosigner-runtime && cargo run --release --bin cosigner-runtime -- \
		--wasm ../cosigner/target/wasm32-wasip1/release/cosigner.wasm \
		--port 7074

signet-down:
	@echo "Stopping MPC server..."
	-pkill -f "target/release/cosigner-runtime" || true
	@echo "Stopped."

e2e-mutinynet: threshold-ffi-build cosigner-build runtime-build signer-run
	@echo "Running MutinyNet E2E test..."
	cd e2e && dart test test/mutinynet_e2e_test.dart --timeout 600s
	-pkill -f "signer-server" || true

e2e-mutinynet-ark: ffi-build cosigner-build runtime-build signer-run
	@echo "Running MutinyNet Ark E2E test..."
	cd e2e && dart test test/mutinynet_ark_e2e_test.dart --timeout 900s
	-pkill -f "signer-server" || true

# ═══════════════════════════════════════════════════════════════════════════════
#  FLUTTER INTEGRATION TESTS — UI on Android emulator against real backend
# ═══════════════════════════════════════════════════════════════════════════════

# Run integration tests against an emulator that's already running, with
# services already started elsewhere (e.g. `make software` in a separate
# terminal). Default for local dev.
integration-test:
	cd app && \
		flutter test integration_test/app_test.dart

# Full headless lifecycle (no Ark): boots regtest, builds FFI for x86_64
# emulator, starts signer + runtime, runs tests, tears down.
integration-test-ci: runtime-stop signer-stop regtest-up bitcoin-init adb-reverse \
	ffi-android-x86_64 cosigner-build runtime-build signer-run runtime-run
	@echo "Running integration tests..."
	-adb reverse tcp:18443 tcp:18443
	cd app && flutter pub get && \
		flutter test integration_test/app_test.dart
	$(MAKE) runtime-stop
	$(MAKE) signer-stop

# Integration tests with the Ark stack running. The Ark test is gated on ASP
# availability so it skips itself if arkd isn't reachable; running through
# this target makes sure it isn't.
integration-test-ci-ark: runtime-stop signer-stop arkd-up bitcoin-init arkd-init \
	signer-run ffi-android-x86_64 cosigner-build runtime-build
	@echo "Running Ark integration test..."
	-adb reverse tcp:7074 tcp:7074
	-adb reverse tcp:50001 tcp:50001
	-adb reverse tcp:18443 tcp:18443
	export ELECTRUM_URL=127.0.0.1 ELECTRUM_PORT=50001 \
		BITCOIN_RPC_USER=admin1 BITCOIN_RPC_PASSWORD=123 \
		ASP_URL=http://127.0.0.1:7070 && \
		cd cosigner-runtime && cargo run --release --bin cosigner-runtime -- \
			--wasm ../cosigner/target/wasm32-wasip1/release/cosigner.wasm \
			--port 7074 &
	@sleep 5
	cd app && flutter pub get && \
		flutter test integration_test/app_test.dart
	$(MAKE) runtime-stop
	$(MAKE) signer-stop
	$(MAKE) arkd-down

# ═══════════════════════════════════════════════════════════════════════════════
#  LEGACY ALIASES (old names still work)
# ═══════════════════════════════════════════════════════════════════════════════

e2e-test: e2e
e2e-ark-test: e2e-ark
regtest: regtest-up bitcoin-init signer-run runtime-run
regtest-ark: runtime-stop signer-stop arkd-up bitcoin-init arkd-init signer-run
regtest-down: down
regtest-hardware: hardware
regtest-hardware-ark: hardware-ark
regtest-hardware-ark-down: down
