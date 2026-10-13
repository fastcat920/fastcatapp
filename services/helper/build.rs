fn main() {
    let version = std::env::var("TOKEN").unwrap_or_default();
    println!("cargo:rustc-env=TOKEN={}", version);
    println!("cargo:rerun-if-env-changed=TOKEN");
    let client = std::env::var("CLIENT_SHA256").unwrap_or_default();
    println!("cargo:rustc-env=CLIENT_SHA256={}", client);
    println!("cargo:rerun-if-env-changed=CLIENT_SHA256");
}
