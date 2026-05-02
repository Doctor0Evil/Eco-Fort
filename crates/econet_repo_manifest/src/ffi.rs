// filename: src/ffi.rs

use crate::{load_manifest_from_repo, load_manifest_from_sql, ManifestError, RepoManifest};
use serde_json::json;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::Path;

fn manifest_error_to_json(err: &ManifestError) -> String {
    json!({
        "error": err.to_string()
    })
    .to_string()
}

fn manifest_to_json(manifest: &RepoManifest) -> String {
    serde_json::to_string(manifest).unwrap_or_else(|e| {
        json!({ "error": format!("serialization failed: {e}") }).to_string()
    })
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

fn error_json_cstring(message: &str) -> *mut c_char {
    let json = json!({ "error": message }).to_string();
    CString::new(json).map_or(std::ptr::null_mut(), |c| c.into_raw())
}

#[no_mangle]
pub unsafe extern "C" fn econet_repo_manifest_load(
    repo_root_c: *const c_char,
) -> *mut c_char {
    if repo_root_c.is_null() {
        return error_json_cstring("null repo_root");
    }

    let c_str = CStr::from_ptr(repo_root_c);
    let repo_root_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return error_json_cstring("invalid UTF-8 repo_root"),
    };

    let path = Path::new(repo_root_str);
    let result = load_manifest_from_repo(path);

    let json = match result {
        Ok(manifest) => manifest_to_json(&manifest),
        Err(err) => manifest_error_to_json(&err),
    };

    CString::new(json)
        .map(|c| c.into_raw())
        .unwrap_or_else(|_| error_json_cstring("manifest JSON encoding failed"))
}

#[no_mangle]
pub unsafe extern "C" fn econet_repo_manifest_load_here() -> *mut c_char {
    let path = std::env::current_dir().unwrap_or_else(|_| ".".into());
    let result = load_manifest_from_repo(&path);
    let json = match result {
        Ok(manifest) => manifest_to_json(&manifest),
        Err(err) => manifest_error_to_json(&err),
    };

    CString::new(json)
        .map(|c| c.into_raw())
        .unwrap_or_else(|_| error_json_cstring("manifest JSON encoding failed"))
}

#[no_mangle]
pub unsafe extern "C" fn econet_repo_manifest_free(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    let _ = CString::from_raw(s);
}

#[no_mangle]
pub unsafe extern "C" fn econet_manifest_load_from_repo_path(
    repo_root_c: *const c_char,
) -> *mut c_char {
    if repo_root_c.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = CStr::from_ptr(repo_root_c);
    let repo_root_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let path = Path::new(repo_root_str);
    match load_manifest_from_repo(path) {
        Ok(manifest) => manifest_to_json_cstring(&manifest),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn econet_manifest_load_from_sql_string(
    sql_c: *const c_char,
) -> *mut c_char {
    if sql_c.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = CStr::from_ptr(sql_c);
    let sql_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    match load_manifest_from_sql(sql_str) {
        Ok(manifest) => manifest_to_json_cstring(&manifest),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn econet_manifest_free_string(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    let _ = CString::from_raw(s);
}
