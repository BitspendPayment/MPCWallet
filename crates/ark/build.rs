fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Generate prost message types under `signing` (the wasm guest needs them); generate
    // the tonic client only under `client` (host transport).
    #[cfg(feature = "signing")]
    {
        tonic_build::configure()
            .build_client(cfg!(feature = "client"))
            .build_server(false)
            .compile_protos(
                &["proto/ark/v1/service.proto", "proto/ark/v1/indexer.proto"],
                &["proto"],
            )?;
    }
    Ok(())
}
