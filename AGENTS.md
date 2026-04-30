# Repository Guidelines

## Project Structure & Module Organization
- `app/` Flutter app UI; key areas include `app/lib/screens`, `app/lib/widgets`, and `app/lib/theme`.
- `client/` Dart client library used by the app and tooling.
- `server/` Dart gRPC server; entrypoint is `server/bin/server.dart`, core logic in `server/lib`.
- `protocol/` shared Dart protocol package; generated stubs live in `protocol/lib/src/generated`.
- `crates/` Rust support libraries (path deps): `crates/threshold` cryptography (unit tests in `crates/threshold/test`), `crates/ark` Ark protocol primitives, `crates/enclave-client` Nitro Enclave HTTP client, `crates/embassy-rp-fork` HAL fork.
- `e2e/` integration tests and Docker setup for regtest services.
- `protos/` protobuf definitions; top-level `docker-compose.yml` and `Makefile` support local regtest.

## Build, Test, and Development Commands
- `make regtest-up`: start Bitcoind + Electrs via Docker Compose.
- `make server-run`: run the MPC server with local regtest defaults (`ELECTRUM_URL=127.0.0.1`, `ELECTRUM_PORT=50001`).
- `make regtest`: convenience target for regtest services plus server; `make regtest-down` stops services.
- `make proto`: regenerate Dart gRPC stubs from `protos/mpc_wallet.proto` (requires `protoc`).
- `dart pub get`: install Dart dependencies inside each package (e.g., `server/`, `client/`).
- `cd app && flutter run`: launch the Flutter app; `cd app && flutter test` runs UI tests.
- `cd e2e && dart test`: run integration tests (expects regtest services running).

## Coding Style & Naming Conventions
- Use standard Dart/Flutter conventions: `UpperCamelCase` for types, `lowerCamelCase` for members, `snake_case` file names.
- Linting: `flutter_lints` in `app/` and `lints/recommended` in `crates/threshold/`; run `flutter analyze` or `dart analyze`.
- Format Dart code with `dart format .` after changes.

## Testing Guidelines
- Tests live under `*/test` and use the `_test.dart` suffix.
- Prefer unit tests for crypto and core logic (`crates/threshold/test`) and e2e flows in `e2e/test`.
- For end-to-end changes, bring up regtest services before running `dart test` in `e2e/`.

## Commit & Pull Request Guidelines
- Commit history mostly uses Conventional Commit prefixes (`feat:`, `fix:`, `refactor:`, `chore:`); prefer that style with a short imperative summary (e.g., `feat: add policy validation`).
- PRs should include a concise description, testing notes, and linked issues; include screenshots or recordings for Flutter UI changes.

## Security & Configuration Notes
- The server relies on `ELECTRUM_URL` and `ELECTRUM_PORT` for connectivity; keep local overrides out of versioned files.
- Treat generated artifacts in `protocol/lib/src/generated` as output from `make proto` rather than hand-edited code.
