// 3.7 Working With HTML Forms
// Page 42 - Zero to Production in Rust book

use std::net::TcpListener;
use zero2prod::run;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let listener = TcpListener::bind("127.0.0.1:8000").expect("Failed to bind random port");
    // let port = listener.local_addr().unwrap().port();
    run(listener)?.await
}
