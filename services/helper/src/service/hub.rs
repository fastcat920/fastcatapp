use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::VecDeque;
use std::fs::File;
use std::io::{BufRead, Error, Read};
use std::path::Path;
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::{io, thread};
use warp::{Filter, Reply};

pub(super) const LISTEN_PORT: u16 = 47890;
const SERVICE_NAME: &str = "fastcatHelperService";

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct StartParams {
    pub path: String,
    pub arg: String,
}

#[derive(Debug, Serialize)]
struct HelperStatus {
    version: &'static str,
    token: &'static str,
    caller_auth: &'static str,
    helper_path: Option<String>,
    service_path_matches: Option<bool>,
    core_running: bool,
    core_pid: Option<u32>,
    recent_logs: Vec<String>,
}

#[cfg(windows)]
pub(super) fn sha256_file(path: impl AsRef<Path>) -> Result<String, Error> {
    let mut file = File::open(path)?;
    sha256_reader(&mut file)
}

fn sha256_reader(file: &mut impl Read) -> Result<String, Error> {
    let mut hasher = Sha256::new();
    let mut buffer = [0; 4096];

    loop {
        let bytes_read = file.read(&mut buffer)?;
        if bytes_read == 0 {
            break;
        }
        hasher.update(&buffer[..bytes_read]);
    }

    Ok(format!("{:x}", hasher.finalize()))
}

fn open_core_for_verification(path: &str) -> Result<File, Error> {
    let mut options = std::fs::OpenOptions::new();
    options.read(true);
    #[cfg(windows)]
    {
        use std::os::windows::fs::OpenOptionsExt;
        // Hold this guard through CreateProcess: deny modifications/renames
        // between hashing and launching the privileged executable.
        options.share_mode(1); // FILE_SHARE_READ
    }
    options.open(path)
}

static LOGS: Lazy<Arc<Mutex<VecDeque<String>>>> =
    Lazy::new(|| Arc::new(Mutex::new(VecDeque::with_capacity(100))));
static PROCESS: Lazy<Arc<Mutex<Option<std::process::Child>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

fn start(start_params: StartParams) -> impl Reply {
    if start_params
        .arg
        .parse::<u16>()
        .ok()
        .filter(|port| *port > 0)
        .is_none()
    {
        return "Invalid core callback port".to_string();
    }
    let installed_core = std::env::current_exe()
        .ok()
        .and_then(|path| path.parent().map(|p| p.join("fastcatCore.exe")))
        .and_then(|path| path.canonicalize().ok());
    if installed_core.is_none()
        || Path::new(&start_params.path).canonicalize().ok() != installed_core
    {
        return "Core must belong to the installed application".to_string();
    }
    let mut executable_guard = match open_core_for_verification(&start_params.path) {
        Ok(file) => file,
        Err(_) => return "Core verification could not read installed executable".to_string(),
    };
    let sha256 = sha256_reader(&mut executable_guard).unwrap_or_default();
    if sha256 != env!("TOKEN") {
        return format!("The SHA256 hash of the program requesting execution is: {}. The helper program only allows execution of applications with the SHA256 hash: {}.", sha256,  env!("TOKEN"),);
    }
    let mut process = PROCESS.lock().unwrap();
    if let Some(mut child) = process.take() {
        let _ = child.kill();
        let _ = child.wait();
    }
    match Command::new(&start_params.path)
        .stderr(Stdio::piped())
        .arg(&start_params.arg)
        .spawn()
    {
        Ok(child) => {
            *process = Some(child);
            if let Some(ref mut child) = *process {
                let stderr = child.stderr.take().unwrap();
                let reader = io::BufReader::new(stderr);
                thread::spawn(move || {
                    for line in reader.lines() {
                        match line {
                            Ok(output) => {
                                log_message(output);
                            }
                            Err(_) => {
                                break;
                            }
                        }
                    }
                });
            }
            "".to_string()
        }
        Err(e) => {
            log_message(e.to_string());
            e.to_string()
        }
    }
}

fn stop() -> impl Reply {
    let mut process = PROCESS.lock().unwrap();
    if let Some(mut child) = process.take() {
        let _ = child.kill();
        let _ = child.wait();
    }
    *process = None;
    "".to_string()
}

fn log_message(message: String) {
    let mut log_buffer = LOGS.lock().unwrap();
    if log_buffer.len() == 100 {
        log_buffer.pop_front();
    }
    log_buffer.push_back(format!(
        "{}\n",
        message.chars().take(2048).collect::<String>()
    ));
}

fn get_logs() -> impl Reply {
    let log_buffer = LOGS.lock().unwrap();
    let value = log_buffer
        .iter()
        .cloned()
        .collect::<Vec<String>>()
        .join("\n");
    warp::reply::with_header(value, "Content-Type", "text/plain")
}

fn get_status() -> impl Reply {
    let helper_path = std::env::current_exe()
        .ok()
        .map(|path| path.to_string_lossy().to_string());
    let (core_running, core_pid) = {
        let mut process = PROCESS.lock().unwrap();
        if let Some(child) = process.as_mut() {
            match child.try_wait() {
                Ok(Some(_)) => {
                    *process = None;
                    (false, None)
                }
                Ok(None) => (true, Some(child.id())),
                Err(_) => (false, None),
            }
        } else {
            (false, None)
        }
    };

    let recent_logs = {
        let log_buffer = LOGS.lock().unwrap();
        log_buffer.iter().cloned().collect::<Vec<String>>()
    };

    warp::reply::json(&HelperStatus {
        version: env!("CARGO_PKG_VERSION"),
        token: env!("TOKEN"),
        caller_auth: "process-sha256-v1",
        helper_path: helper_path.clone(),
        service_path_matches: service_path_matches(helper_path.as_deref()),
        core_running,
        core_pid,
        recent_logs,
    })
}

fn service_path_matches(current_path: Option<&str>) -> Option<bool> {
    if !cfg!(target_os = "windows") {
        return None;
    }
    let current_path = current_path?;
    let output = Command::new("sc")
        .args(["qc", SERVICE_NAME])
        .output()
        .ok()?;
    if !output.status.success() {
        return Some(false);
    }
    let stdout = String::from_utf8_lossy(&output.stdout);
    let service_path = stdout.lines().find_map(|line| {
        let (_, value) = line.split_once("BINARY_PATH_NAME")?;
        let (_, path) = value.split_once(':')?;
        Some(normalize_windows_service_path(path.trim()))
    })?;
    Some(normalize_windows_path(current_path) == service_path)
}

fn normalize_windows_service_path(value: &str) -> String {
    let trimmed = value.trim();
    let path = if let Some(rest) = trimmed.strip_prefix('"') {
        rest.split('"').next().unwrap_or(rest)
    } else if let Some(index) = trimmed.to_ascii_lowercase().find(".exe") {
        &trimmed[..index + 4]
    } else {
        trimmed
    };
    normalize_windows_path(path)
}

fn normalize_windows_path(value: &str) -> String {
    Path::new(value)
        .to_string_lossy()
        .replace('/', "\\")
        .trim_matches('"')
        .to_ascii_lowercase()
}

pub async fn run_service() -> anyhow::Result<()> {
    let caller = warp::addr::remote()
        .and(warp::header::optional::<String>("origin"))
        .and_then(super::caller::authorize)
        .untuple_one();
    let api_ping = warp::get()
        .and(warp::path("ping"))
        .and(warp::path::end())
        .map(|| env!("TOKEN"));

    let api_start = warp::post()
        .and(warp::path("start"))
        .and(warp::path::end())
        .and(warp::body::content_length_limit(4096))
        .and(warp::body::json())
        .map(|start_params: StartParams| start(start_params));

    let api_stop = warp::post()
        .and(warp::path("stop"))
        .and(warp::path::end())
        .map(|| stop());

    let api_logs = warp::get()
        .and(warp::path("logs"))
        .and(warp::path::end())
        .map(|| get_logs());
    let api_status = warp::get()
        .and(warp::path("status"))
        .and(warp::path::end())
        .map(|| get_status());

    warp::serve(
        caller
            .and(
                api_ping
                    .or(api_status)
                    .or(api_start)
                    .or(api_stop)
                    .or(api_logs),
            )
            .recover(|rejection: warp::Rejection| async move {
                let code = if rejection.find::<super::caller::Unauthorized>().is_some() {
                    warp::http::StatusCode::FORBIDDEN
                } else if rejection.is_not_found() {
                    warp::http::StatusCode::NOT_FOUND
                } else {
                    warp::http::StatusCode::BAD_REQUEST
                };
                Ok::<_, std::convert::Infallible>(warp::reply::with_status(
                    "Helper request rejected",
                    code,
                ))
            }),
    )
    .run(([127, 0, 0, 1], LISTEN_PORT))
    .await;

    Ok(())
}
