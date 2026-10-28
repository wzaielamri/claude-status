// Which SSH host this VS Code window is connected to (Remote-SSH), if any.
// The extension itself always runs on this computer ("extensionKind": ["ui"]),
// so it reaches that host with its own ssh, like any other picked host.

import { spawnSync } from "node:child_process";

// The host names remote.py accepts (its HOST_NAME)
export const HOST_NAME = /^[A-Za-z0-9_.@][A-Za-z0-9_.@:-]*$/;

// "ssh-remote+myhost" -> "myhost". Remote-SSH writes names that don't fit in
// a URI authority (upper case, user@host, …) as hex-encoded JSON:
// "ssh-remote+7b22686f73744e616d65223a…" -> {"hostName":"…","user":"…"}.
export function hostFromAuthority(authority: string | undefined): string | undefined {
  let host = withPort(authority);
  if (!host) return undefined;
  // "user@host:2222": ssh takes no port in the destination; keep host aliases simple
  if (host.includes(":")) host = host.slice(0, host.indexOf(":"));
  return HOST_NAME.test(host) ? host : undefined;
}

// The port the window reached its host on, when one was given ("user@host:2222"
// typed into Remote-SSH's connect box): ssh <host> may go to another one
export function portFromAuthority(authority: string | undefined): number | undefined {
  const host = hostFromAuthority(authority) ? withPort(authority) : undefined;
  const port = host?.includes(":") ? Number(host.slice(host.lastIndexOf(":") + 1)) : NaN;
  return Number.isInteger(port) && port > 0 && port < 65536 ? port : undefined;
}

// The port ssh <host> connects to (ssh -G: ~/.ssh/config applied, nothing
// connected), or undefined when ssh can't say
export function sshPort(host: string): number | undefined {
  const r = spawnSync("ssh", ["-G", host], { encoding: "utf8", timeout: 5000 });
  const m = /^port (\d+)$/m.exec(r.stdout ?? "");
  return m ? Number(m[1]) : undefined;
}

// The authority's user@host[:port]
function withPort(authority: string | undefined): string | undefined {
  if (!authority) return undefined;
  const plus = authority.indexOf("+");
  if (plus < 0 || authority.slice(0, plus) !== "ssh-remote") return undefined;
  let rest = authority.slice(plus + 1);
  try {
    rest = decodeURIComponent(rest);
  } catch {
    return undefined;
  }
  let host = rest;
  if (/^(?:[0-9a-f]{2})+$/i.test(rest) && rest.startsWith("7b")) {
    try {
      const decoded = JSON.parse(Buffer.from(rest, "hex").toString("utf8"));
      if (decoded && typeof decoded.hostName === "string") {
        host = (typeof decoded.user === "string" && decoded.user ? decoded.user + "@" : "") + decoded.hostName;
        if (typeof decoded.port === "number" || (typeof decoded.port === "string" && decoded.port)) host += ":" + decoded.port;
      }
    } catch {
      // not JSON after all: a host name made of hex digits
    }
  }
  return host;
}

// The authority of whatever this window has open: a folder, a workspace file,
// or an editor (hostFromAuthority: its host).
export function currentRemoteAuthority(vscode: typeof import("vscode")): string | undefined {
  if (vscode.env.remoteName !== "ssh-remote") return undefined;
  const uris = [
    ...(vscode.workspace.workspaceFolders ?? []).map((f) => f.uri),
    ...(vscode.workspace.workspaceFile ? [vscode.workspace.workspaceFile] : []),
    ...vscode.window.visibleTextEditors.map((e) => e.document.uri),
  ];
  for (const uri of uris) if (uri.scheme === "vscode-remote" && hostFromAuthority(uri.authority)) return uri.authority;
  return undefined;
}

// A file of the host this window is connected to, as the window names it.
// (VS Code maps file: to and from vscode-local only for extensions running
// on the host: to this one, file: is a file of this computer.)
export function windowHostFile(vscode: typeof import("vscode"), file: string): import("vscode").Uri | undefined {
  const authority = currentRemoteAuthority(vscode);
  return authority ? vscode.Uri.from({ scheme: "vscode-remote", authority, path: file }) : undefined;
}
