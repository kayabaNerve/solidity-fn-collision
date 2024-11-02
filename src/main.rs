use create2crunch::Config;
use std::env;
use std::process;

fn main() {
    let config = Config::new(env::args()).unwrap_or_else(|err| {
        eprintln!("Failed parsing arguments: {err}");
        process::exit(1);
    });

    for i in 0 .. u8::MAX {
      if let Err(e) = create2crunch::gpu(config.clone(), i) {
        eprintln!("GPU application error: {e}");
        process::exit(1);
      }
  }
}
