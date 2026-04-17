fn main() -> Result<(), Box<dyn std::error::Error>> {
    #[cfg(feature = "client")]
    {
        tonic_build::configure()
            .build_server(false)
            .compile_protos(
                &["proto/ark/v1/service.proto", "proto/ark/v1/indexer.proto"],
                &["proto"],
            )?;
    }
    Ok(())
}
