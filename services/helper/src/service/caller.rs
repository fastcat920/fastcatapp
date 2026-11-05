//! Authorize the real TCP peer, not a client-supplied PID/header or the public
//! core checksum. This protects the privileged helper from other local apps.
use std::net::SocketAddr;

#[derive(Debug)]
pub struct Unauthorized;
impl warp::reject::Reject for Unauthorized {}

pub async fn authorize(
    peer: Option<SocketAddr>,
    origin: Option<String>,
) -> Result<(), warp::Rejection> {
    if origin.is_some() || !peer.is_some_and(|addr| addr.ip().is_loopback()) {
        return Err(warp::reject::custom(Unauthorized));
    }
    let allowed = tokio::task::spawn_blocking(move || platform_authorized(peer.unwrap()))
        .await
        .unwrap_or(false);
    if allowed {
        Ok(())
    } else {
        Err(warp::reject::custom(Unauthorized))
    }
}

// Non-Windows helper is not shipped as a privileged service. Fail closed rather
// than accidentally introducing an unauthenticated development listener.
#[cfg(not(windows))]
fn platform_authorized(_peer: SocketAddr) -> bool {
    false
}

#[cfg(windows)]
fn platform_authorized(peer: SocketAddr) -> bool {
    use std::ffi::OsString;
    use std::os::windows::ffi::OsStringExt;
    use std::path::PathBuf;
    use windows_sys::Win32::Foundation::CloseHandle;
    use windows_sys::Win32::NetworkManagement::IpHelper::{
        GetExtendedTcpTable, MIB_TCPROW_OWNER_PID, TCP_TABLE_OWNER_PID_ALL,
    };
    use windows_sys::Win32::Networking::WinSock::AF_INET;
    use windows_sys::Win32::System::Threading::{
        OpenProcess, QueryFullProcessImageNameW, PROCESS_QUERY_LIMITED_INFORMATION,
    };

    let expected = option_env!("CLIENT_SHA256").unwrap_or("");
    if !valid_digest(expected) {
        return false;
    }
    // Query the client's side of the complete established loopback tuple. Never
    // accept a PID supplied in the HTTP request or a port-only match.
    let loopback = u32::from_ne_bytes([127, 0, 0, 1]);
    let mut size = 0u32;
    unsafe {
        GetExtendedTcpTable(
            std::ptr::null_mut(),
            &mut size,
            0,
            AF_INET as u32,
            TCP_TABLE_OWNER_PID_ALL,
            0,
        );
    }
    for _ in 0..3 {
        if size < 4 || size > 16 * 1024 * 1024 {
            return false;
        }
        // DWORD-aligned allocation; table count followed by DWORD-only rows.
        let mut table = vec![0u32; (size as usize + 3) / 4];
        let code = unsafe {
            GetExtendedTcpTable(
                table.as_mut_ptr().cast(),
                &mut size,
                0,
                AF_INET as u32,
                TCP_TABLE_OWNER_PID_ALL,
                0,
            )
        };
        if code == 122 {
            continue;
        } // ERROR_INSUFFICIENT_BUFFER
        if code != 0 {
            return false;
        }
        let count = table[0] as usize;
        if count > (table.len() * 4 - 4) / std::mem::size_of::<MIB_TCPROW_OWNER_PID>() {
            return false;
        }
        let rows = unsafe {
            std::slice::from_raw_parts(table.as_ptr().add(1).cast::<MIB_TCPROW_OWNER_PID>(), count)
        };
        let Some(row) = rows.iter().find(|row| {
            row.dwState == 5
                && row.dwLocalAddr == loopback
                && row.dwRemoteAddr == loopback
                && u16::from_be(row.dwLocalPort as u16) == peer.port()
                && u16::from_be(row.dwRemotePort as u16) == super::hub::LISTEN_PORT
        }) else {
            return false;
        };
        let process = unsafe { OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, row.dwOwningPid) };
        if process == 0 {
            return false;
        }
        let mut buffer = vec![0u16; 32768];
        let mut len = buffer.len() as u32;
        let ok = unsafe { QueryFullProcessImageNameW(process, 0, buffer.as_mut_ptr(), &mut len) };
        let allowed = if ok != 0 {
            let path = PathBuf::from(OsString::from_wide(&buffer[..len as usize]));
            let same_directory = std::env::current_exe()
                .ok()
                .and_then(|p| p.parent().map(|p| p.to_owned()))
                .zip(path.parent().map(|p| p.to_owned()))
                .is_some_and(|(a, b)| {
                    a.canonicalize()
                        .ok()
                        .zip(b.canonicalize().ok())
                        .is_some_and(|(a, b)| a == b)
                });
            same_directory && super::hub::sha256_file(&path).is_ok_and(|hash| hash == expected)
        } else {
            false
        };
        // Keep the process handle alive until after validation, avoiding PID reuse.
        unsafe {
            CloseHandle(process);
        }
        return allowed;
    }
    false
}

#[cfg(any(windows, test))]
fn valid_digest(value: &str) -> bool {
    value.len() == 64
        && value.bytes().all(|c| c.is_ascii_hexdigit())
        && value.bytes().any(|c| c != b'0')
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn bootstrap_hash_never_authorizes() {
        assert!(!valid_digest(""));
        assert!(!valid_digest(&"0".repeat(64)));
        assert!(!valid_digest(&"x".repeat(64)));
        assert!(valid_digest(&"a".repeat(64)));
    }
    #[tokio::test]
    async fn rejects_origin_missing_and_nonlocal_peer() {
        assert!(authorize(None, None).await.is_err());
        assert!(authorize(Some("192.0.2.1:2000".parse().unwrap()), None)
            .await
            .is_err());
        assert!(authorize(
            Some("127.0.0.1:2000".parse().unwrap()),
            Some("https://example.test".into())
        )
        .await
        .is_err());
    }
}
