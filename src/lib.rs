#![warn(unused_crate_dependencies, unreachable_pub)]
#![deny(unused_must_use, rust_2018_idioms)]

use ocl::{Buffer, Context, Device, MemFlags, Platform, ProQue, Program, Queue};
use std::fmt::Write as _;

static KERNEL_SRC: &str = include_str!("./kernels/keccak256.cl");

#[derive(Clone)]
pub struct Config {
    pub target: [u8; 4],
    pub function_start: String,
    pub function_end: String,
    pub gpu_device: u8,
}

/// Validate the provided arguments and construct the Config struct.
impl Config {
    pub fn new(mut args: std::env::Args) -> Result<Self, &'static str> {
        // get args, skipping first arg (program name)
        args.next();

        let Some(target_string) = args.next() else {
            return Err("didn't get a target argument");
        };

        let Some(function_string) = args.next() else {
            return Err("didn't get a function argument");
        };
        let mut function_string = function_string.split("00000000");
        let function_start = function_string.next().unwrap().to_string();
        let Some(function_end) = function_string.next() else {
          return Err("function didn't contain 00000000 in its name, before its arguments");
        };
        if function_string.next().is_some() {
          return Err("function contained 00000000 multiple times");
        }

        let Some(gpu_device_string) = args.next() else {
            return Err("didn't get a GPU argument")
        };

        // convert main arguments from hex string to vector of bytes
        let Ok(target_vec) = hex::decode(target_string) else {
            return Err("could not decode target argument");
        };

        // convert from vector to fixed array
        let Ok(target) = target_vec.try_into() else {
            return Err("invalid length for target argument");
        };

        // convert gpu arguments to u8 values
        let Ok(gpu_device) = gpu_device_string.parse::<u8>() else {
            return Err("invalid gpu device value");
        };

        Ok(Self {
            target,
            function_start,
            function_end: function_end.to_string(),
            gpu_device,
        })
    }
}

pub fn gpu(config: Config, nonce: u8) -> ocl::Result<()> {
    println!("Starting work on {nonce}");

    // set up a platform to use
    let platform = Platform::new(ocl::core::default_platform()?);

    // set up the device to use
    let device = Device::by_idx_wrap(platform, config.gpu_device as usize)?;

    // set up the context to use
    let context = Context::builder()
        .platform(platform)
        .devices(device)
        .build()?;

    // set up the program to use
    let program = Program::builder()
        .devices(device)
        .src(mk_kernel_src(&config, nonce))
        .build(&context)?;

    // set up the queue to use
    let queue = Queue::new(&context, device, None)?;

    // set up the "proqueue" (or amalgamation of various elements) to use
    let ocl_pq = ProQue::new(context, queue, program, Some(2u32.pow(24)));

    // establish a buffer for nonces that result in desired addresses
    let mut solutions: Vec<u64> = vec![0; 1];
    let solutions_buffer = Buffer::builder()
        .queue(ocl_pq.queue().clone())
        .flags(MemFlags::new().write_only())
        .len(1)
        .copy_host_slice(&solutions)
        .build()?;

    // build the kernel and define the type of each buffer
    let kern = ocl_pq
        .kernel_builder("hashMessage")
        .global_work_size(2u32.pow(24))
        .arg_named("solutions", None::<&Buffer<u64>>)
        .build()?;

    // set each buffer
    kern.set_arg("solutions", &solutions_buffer)?;

    // enqueue the kernel
    unsafe { kern.enq()? };

    // read the solutions from the device
    solutions_buffer.read(&mut solutions).enq()?;

    for &solution in &solutions {
      // 1/2**32 chance of a false negative
      if solutions[0] == 0 {
          continue;
      }

      dbg!(solution);
    }

    Ok(())
}

/// Creates the OpenCL kernel source code by populating the template with the
/// values from the Config object.
fn mk_kernel_src(config: &Config, nonce: u8) -> String {
    let mut src = String::with_capacity(4096 + KERNEL_SRC.len());

    let mut sponge = vec![];
    sponge.extend(config.function_start.as_bytes());
    sponge.extend(hex::encode(&[nonce]).to_uppercase().as_bytes());
    let nonce_start_pos = sponge.len();
    sponge.extend("000000".as_bytes());
    sponge.extend(config.function_end.as_bytes());
    sponge.push(1); // Pad start
    while sponge.len() < 136 {
      sponge.push(0);
    }
    sponge[135] = 0x80; // Pad end
    for (i, x) in sponge.iter().enumerate() {
      writeln!(src, "#define S_{} {}u", i, x).unwrap();
    }

    for (i, x) in config.target.iter().enumerate() {
      writeln!(src, "#define T_{} {}u", i, x).unwrap();
    }
    writeln!(src, "#define NONCE_START_POS {}u", nonce_start_pos).unwrap();

    src.push_str(KERNEL_SRC);

    src
}
