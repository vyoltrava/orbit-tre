use std::io;
use std::os::unix::process::CommandExt;
use std::process::{Command, Stdio};

// Запуск приложения: setsid + fork + execvp, не блокируя GUI.
pub fn launch(exec_cmd: &str) -> Result<(), io::Error> {
    let mut sh = Command::new("sh");
    sh.arg("-c").arg(exec_cmd);
    sh.stdin(Stdio::null());
    sh.stdout(Stdio::null());
    sh.stderr(Stdio::null());
    unsafe {
        sh.pre_exec(|| {
            if libc::setsid() < 0 {
                Err(io::Error::last_os_error())
            } else {
                Ok(())
            }
        });
    }
    sh.spawn().map(|_| ())
}

pub fn launch_detached(exec_cmd: &str, working_dir: Option<&str>) -> Result<(), io::Error> {
    let mut sh = Command::new("sh");
    sh.arg("-c").arg(exec_cmd);
    sh.stdin(Stdio::null());
    sh.stdout(Stdio::null());
    sh.stderr(Stdio::null());
    if let Some(dir) = working_dir {
        sh.current_dir(dir);
    }
    unsafe {
        sh.pre_exec(|| {
            if libc::setsid() < 0 {
                Err(io::Error::last_os_error())
            } else {
                Ok(())
            }
        });
    }
    sh.spawn().map(|_| ())
}
