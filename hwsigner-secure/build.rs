use std::env;
use std::fs;
use std::path::PathBuf;

fn main() {
    let out = PathBuf::from(env::var("OUT_DIR").unwrap());

    // Copy linker scripts
    fs::copy("secure.x", out.join("memory.x")).unwrap();
    fs::copy("device.x", out.join("device.x")).unwrap();

    println!("cargo:rerun-if-changed=secure.x");
    println!("cargo:rerun-if-changed=device.x");
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rustc-link-search={}", out.display());
}
