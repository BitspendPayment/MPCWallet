//! Minimal gRPC-over-`wasi:http` unary client for the guest. The guest composes the
//! gRPC request; the host's `ArkH2Hooks` carries it over HTTP/2 to the ASP. Must be
//! driven inside `wstd::runtime::block_on` (wstd owns its reactor).
//!
//! Unary gRPC framing: request/response bodies are `[compressed_flag: u8][len: u32 BE]
//! [protobuf message]`. The method path is `/<package>.<Service>/<Method>`.

use http_body_util::BodyExt;
use prost::Message;
use wstd::http::{Body, Client, Request};

/// Frame the gRPC request body: `[compressed: u8][len: u32 BE][protobuf]`.
fn frame_request<Req: Message>(req: &Req) -> Result<Vec<u8>, String> {
    let mut msg = Vec::new();
    req.encode(&mut msg).map_err(|e| format!("grpc encode: {e}"))?;
    let mut framed = Vec::with_capacity(5 + msg.len());
    framed.push(0u8); // not compressed
    framed.extend_from_slice(&(msg.len() as u32).to_be_bytes());
    framed.extend_from_slice(&msg);
    Ok(framed)
}

/// Make a unary gRPC call: encode `req`, frame it, POST to `base_url + method`, and
/// decode the response message. (Happy-path: assumes `grpc-status: 0`; a non-zero status
/// typically yields a non-200 or an undecodable body, surfaced as `Err`.)
pub async fn unary<Req, Resp>(base_url: &str, method: &str, req: &Req) -> Result<Resp, String>
where
    Req: Message,
    Resp: Message + Default,
{
    let mut msg = Vec::new();
    req.encode(&mut msg).map_err(|e| format!("grpc encode: {e}"))?;

    let mut framed = Vec::with_capacity(5 + msg.len());
    framed.push(0u8); // not compressed
    framed.extend_from_slice(&(msg.len() as u32).to_be_bytes());
    framed.extend_from_slice(&msg);

    let url = format!("{}{}", base_url.trim_end_matches('/'), method);
    let request = Request::post(&url)
        .header("content-type", "application/grpc")
        .header("te", "trailers")
        .body(Body::from(framed))
        .map_err(|e| format!("grpc build request: {e}"))?;

    let resp = Client::new()
        .send(request)
        .await
        .map_err(|e| format!("grpc send: {e}"))?;
    let status = resp.status();
    if status != 200 {
        return Err(format!("grpc http status {status}"));
    }

    let mut body = resp.into_body();
    let bytes = body
        .bytes_contents()
        .await
        .map_err(|e| format!("grpc read body: {e}"))?;
    if bytes.len() < 5 {
        return Err(format!("grpc frame too short: {} bytes", bytes.len()));
    }
    // Strip the 5-byte length-prefix; decode the protobuf message.
    Resp::decode(&bytes[5..]).map_err(|e| format!("grpc decode: {e}"))
}

/// A server-streaming gRPC call: the response body is a sequence of length-prefixed
/// messages delivered across HTTP/2 DATA frames over a long-lived response. `next()`
/// reads incrementally — awaiting the next DATA frame only when the buffer lacks a
/// complete message — so the caller can act (sign, make unary calls) between events.
/// This is the transport the Settle batch event loop runs on.
pub struct ServerStream {
    body: http_body_util::combinators::UnsyncBoxBody<bytes::Bytes, wstd::http::Error>,
    buf: Vec<u8>,
    ended: bool,
}

impl ServerStream {
    /// Open the stream: frame `req`, POST, and hold the streaming response body.
    pub async fn open<Req: Message>(
        base_url: &str,
        method: &str,
        req: &Req,
    ) -> Result<Self, String> {
        let framed = frame_request(req)?;
        let url = format!("{}{}", base_url.trim_end_matches('/'), method);
        let request = Request::post(&url)
            .header("content-type", "application/grpc")
            .header("te", "trailers")
            .body(Body::from(framed))
            .map_err(|e| format!("grpc build request: {e}"))?;
        let resp = Client::new()
            .send(request)
            .await
            .map_err(|e| format!("grpc send: {e}"))?;
        if resp.status() != 200 {
            return Err(format!("grpc http status {}", resp.status()));
        }
        Ok(Self {
            body: resp.into_body().into_boxed_body(),
            buf: Vec::new(),
            ended: false,
        })
    }

    /// Pull one complete gRPC message off the stream, decoding it as `Resp`. Returns
    /// `Ok(None)` at end-of-stream. Reads further DATA frames only as needed.
    pub async fn next<Resp: Message + Default>(&mut self) -> Result<Option<Resp>, String> {
        loop {
            if let Some(frame) = self.take_buffered_frame() {
                return Ok(Some(Resp::decode(&frame[..]).map_err(|e| format!("grpc decode: {e}"))?));
            }
            if self.ended {
                return Ok(None);
            }
            match self.body.frame().await {
                Some(Ok(frame)) => {
                    if let Ok(data) = frame.into_data() {
                        self.buf.extend_from_slice(data.as_ref());
                    }
                    // Non-data (trailers) frames carry no message bytes.
                }
                Some(Err(e)) => return Err(format!("grpc stream frame: {e}")),
                None => self.ended = true,
            }
        }
    }

    /// Pop one complete `[compressed][len][payload]` message from `buf` if present,
    /// returning just the protobuf payload bytes.
    fn take_buffered_frame(&mut self) -> Option<Vec<u8>> {
        if self.buf.len() < 5 {
            return None;
        }
        let len = u32::from_be_bytes([self.buf[1], self.buf[2], self.buf[3], self.buf[4]]) as usize;
        if self.buf.len() < 5 + len {
            return None;
        }
        let payload = self.buf[5..5 + len].to_vec();
        self.buf.drain(0..5 + len);
        Some(payload)
    }
}
