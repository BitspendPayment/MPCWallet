fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Client-facing wallet API
    // Add serde derives so protobuf types can be used with axum JSON handlers.
    tonic_build::configure()
        .type_attribute(".", "#[derive(serde::Serialize, serde::Deserialize)]")
        .compile_protos(&["proto/mpc_wallet.proto"], &["proto"])?;
    Ok(())
}
