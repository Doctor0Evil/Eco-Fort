// filename: src/ffi.rs

use crate::{load_manifest_from_repo, load_manifest_from_sql, RepoManifest, ManifestError};
use serde_json;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::Path;

#[no_mangle]
pub extern "C" fn econet_manifest_load_from_repo_path(
    repo_root_c: *const c_char,
) -> *mut c_char {
    if repo_root_c.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = unsafe { CStr::from_ptr(repo_root_c) };
    let repo_root = match c_str.to_str() {
        Ok(s) => Path::new(s),
        Err(_) => return std::ptr::null_mut(),
    };

    match load_manifest_from_repo(repo_root) {
        Ok(manifest) => manifest_to_json_cstring(&manifest),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn econet_manifest_load_from_sql_string(
    sql_c: *const c_char,
) -> *mut c_char {
    if sql_c.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = unsafe { CStr::from_ptr(sql_c) };
    let sql = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    match load_manifest_from_sql(sql) {
        Ok(manifest) => manifest_to_json_cstring(&manifest),
        Err(_) => std::ptr::null_mut(),
    }
}

fn manifest_to_json_cstring(manifest: &RepoManifest) -> *mut c_char {
    match serde_json::to_string(manifest) {
        Ok(json) => match CString::new(json) {
            Ok(c_string) => c_string.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

/// Caller must free the returned string when done.
#[no_mangle]
pub extern "C" fn econet_manifest_free_string(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(s);
    }
}
