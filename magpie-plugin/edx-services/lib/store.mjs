// 服务定义、运行时快照与设置的持久化。
// 数据放在 magpie 配置目录下的 edx-services/，与 magpie 自己的文件隔离。
import fs from "node:fs"
import path from "node:path"
import { randomUUID } from "node:crypto"
import { execFile } from "node:child_process"
import { promisify } from "node:util"

const run = promisify(execFile)

export const DEFAULT_SETTINGS = Object.freeze({ autoCheck: true, intervalHours: 12 })
const LEGACY_DEFAULT_INTERVAL = 6

function str(value) {
  return typeof value === "string" ? value : ""
}

function optStr(value) {
  if (typeof value !== "string") return null
  const t = value.trim()
  return t ? value : null
}

function isoOrNull(value) {
  if (typeof value !== "string" || !value) return null
  const d = new Date(value)
  return Number.isNaN(d.getTime()) ? null : d.toISOString()
}

function normalizeEnv(raw) {
  const out = {}
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return out
  for (const [k, v] of Object.entries(raw)) {
    const key = String(k).trim()
    // 只接受合法的环境变量名，避免把脏键写进子进程环境
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key)) continue
    out[key] = v == null ? "" : String(v)
  }
  return out
}

function queueOf(raw) {
  const n = Number(raw)
  return Number.isInteger(n) && n >= 1 ? Math.min(n, 99) : 1
}

function normalizeUpdateStatus(raw) {
  if (!raw || typeof raw !== "object") return null
  return {
    repository: str(raw.repository),
    latestVersion: str(raw.latestVersion),
    latestReleaseTitle: str(raw.latestReleaseTitle),
    latestReleaseURL: str(raw.latestReleaseURL),
    latestPublishedAt: isoOrNull(raw.latestPublishedAt),
    lastCheckedAt: isoOrNull(raw.lastCheckedAt) ?? new Date(0).toISOString(),
    errorMessage: optStr(raw.errorMessage),
    etag: optStr(raw.etag),
  }
}

/** 数据进入系统的唯一归一化入口：API 请求体、磁盘文件、Edx 导入都经过这里。 */
export function normalizeService(raw, { keepId = true } = {}) {
  const src = raw && typeof raw === "object" ? raw : {}
  const id = keepId && typeof src.id === "string" && /^[A-Za-z0-9-]{8,64}$/.test(src.id) ? src.id : randomUUID()
  return {
    id,
    name: str(src.name).trim(),
    command: str(src.command).trim(),
    workingDirectory: optStr(src.workingDirectory)?.trim() ?? null,
    environment: normalizeEnv(src.environment),
    autoStart: src.autoStart === true,
    // 启动队列：自动启动时按数字从小到大分批，前一队列都启动后才开始下一队列；缺省为 1
    startQueue: queueOf(src.startQueue),
    // Edx 用它控制菜单栏显示；magpie 插件无法进入菜单栏，仅原样保留以便数据互通
    showInMenuBar: src.showInMenuBar !== false,
    githubRepository: optStr(src.githubRepository)?.trim() ?? null,
    currentVersion: optStr(src.currentVersion)?.trim() ?? null,
    ignoredVersion: optStr(src.ignoredVersion)?.trim() ?? null,
    versionCommand: optStr(src.versionCommand)?.trim() ?? null,
    // 版本命令自动检测：默认开启；用户手动改过版本命令后关闭
    autoDetectVersionCommand: src.autoDetectVersionCommand !== false,
    updateCommand: optStr(src.updateCommand)?.trim() ?? null,
    stopCommand: optStr(src.stopCommand)?.trim() ?? null,
    updateStatus: normalizeUpdateStatus(src.updateStatus),
    importedFrom: optStr(src.importedFrom),
  }
}

function normalizeSettings(raw) {
  const s = raw && typeof raw === "object" ? raw : {}
  const hours = Number.isFinite(Number(s.intervalHours)) ? Math.round(Number(s.intervalHours)) : DEFAULT_SETTINGS.intervalHours
  const custom = s.intervalHoursCustom === true
  // 早期版本默认 6 小时，并且每次保存服务都会把它写进 services.json；
  // 用户没亲自选过间隔时，把这个旧默认值迁移到现在的默认值
  const migrated = !custom && hours === LEGACY_DEFAULT_INTERVAL ? DEFAULT_SETTINGS.intervalHours : hours
  return {
    autoCheck: s.autoCheck !== false,
    intervalHours: Math.min(168, Math.max(1, migrated)),
    intervalHoursCustom: custom,
  }
}

function readJSON(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"))
  } catch (e) {
    if (e?.code !== "ENOENT") console.error(`edx-services: 读取 ${path.basename(file)} 失败：${e?.message ?? e}`)
    return fallback
  }
}

/** 先写临时文件再改名，避免写到一半时宿主被重启导致文件损坏。 */
function writeJSON(file, data) {
  const tmp = `${file}.${process.pid}.tmp`
  fs.writeFileSync(tmp, JSON.stringify(data, null, 2))
  fs.renameSync(tmp, file)
}

export class Store {
  constructor(directory) {
    this.dir = path.join(directory, "edx-services")
    this.logDir = path.join(this.dir, "logs")
    this.servicesFile = path.join(this.dir, "services.json")
    this.runtimeFile = path.join(this.dir, "runtime.json")
    // GitHub 访问令牌单独存放（权限 0600），不进 services.json，也不返回给面板
    this.githubTokenFile = path.join(this.dir, "github-token")
    fs.mkdirSync(this.logDir, { recursive: true })
    // 上次删除后留着备撤销的日志，宿主重启后已无法撤销，清掉
    for (const f of fs.readdirSync(this.logDir)) if (f.endsWith(".log.trash")) fs.rmSync(path.join(this.logDir, f), { force: true })
    const data = readJSON(this.servicesFile, {})
    this.services = Array.isArray(data.services) ? data.services.map((s) => normalizeService(s)) : []
    this.settings = normalizeSettings(data.settings)
  }

  save() {
    writeJSON(this.servicesFile, { version: 1, services: this.services, settings: this.settings })
  }

  readGithubToken() {
    try {
      const t = fs.readFileSync(this.githubTokenFile, "utf8").trim()
      return t || null
    } catch (e) {
      if (e?.code !== "ENOENT") console.error(`edx-services: 读取 GitHub 令牌失败：${e?.code ?? e?.message}`)
      return null
    }
  }

  writeGithubToken(token) {
    if (!token) {
      fs.rmSync(this.githubTokenFile, { force: true })
      return
    }
    const tmp = `${this.githubTokenFile}.${process.pid}.tmp`
    fs.writeFileSync(tmp, token, { mode: 0o600 })
    fs.renameSync(tmp, this.githubTokenFile)
  }

  get(id) {
    return this.services.find((s) => s.id === id) ?? null
  }

  logPath(id) {
    return path.join(this.logDir, `${id}.log`)
  }

  readRuntime() {
    const data = readJSON(this.runtimeFile, {})
    return {
      session: data.session && typeof data.session === "object" ? data.session : null,
      instances: data.instances && typeof data.instances === "object" ? data.instances : {},
      failures: data.failures && typeof data.failures === "object" ? data.failures : {},
    }
  }

  writeRuntime(runtime) {
    writeJSON(this.runtimeFile, runtime)
  }

  updateSettings(patch) {
    // 只有用户在面板里亲自选过间隔，才标记为自定义（之后不再迁移）
    const custom = this.settings.intervalHoursCustom || (patch && "intervalHours" in patch)
    this.settings = normalizeSettings({ ...this.settings, ...patch, intervalHoursCustom: custom })
    this.save()
    return this.settings
  }
}

// ---- 从 Edx 导入 ----------------------------------------------------------

const EDX_DOMAIN = "dev.edx.desktop"
// Swift JSONEncoder 默认把 Date 编码为距 2001-01-01 的秒数
const SWIFT_REFERENCE_EPOCH = 978307200

function swiftDate(value) {
  if (typeof value === "number" && Number.isFinite(value)) return new Date((value + SWIFT_REFERENCE_EPOCH) * 1000).toISOString()
  if (typeof value === "string") return isoOrNull(value)
  return null
}

/** 读取 Edx 保存在 UserDefaults 里的 customServices（JSON Data）。读不到时返回空数组。 */
export async function readEdxServices() {
  let base64
  try {
    // defaults export 把整个偏好域输出为 plist，plutil 取出 Data 字段的 base64
    const exported = await run("/usr/bin/defaults", ["export", EDX_DOMAIN, "-"], { maxBuffer: 64 << 20 })
    const child = execFile("/usr/bin/plutil", ["-extract", "customServices", "raw", "-o", "-", "-"], { maxBuffer: 64 << 20 })
    const out = await new Promise((resolve, reject) => {
      let buf = ""
      child.stdout.on("data", (d) => (buf += d))
      child.on("error", reject)
      child.on("close", (code) => (code === 0 ? resolve(buf) : reject(new Error(`plutil exit ${code}`))))
      child.stdin.end(exported.stdout)
    })
    base64 = out.trim()
  } catch {
    return []
  }
  let list
  try {
    list = JSON.parse(Buffer.from(base64, "base64").toString("utf8"))
  } catch {
    return []
  }
  if (!Array.isArray(list)) return []
  return list.map((s) => ({
    edxId: typeof s.id === "string" ? s.id : null,
    service: {
      name: s.name,
      command: s.command,
      workingDirectory: s.working_directory,
      environment: s.environment,
      showInMenuBar: s.show_in_menu_bar,
      // 导入后默认不自动启动：Edx 可能仍在自动启动同一服务，两边同时启动会抢端口
      autoStart: false,
      githubRepository: s.github_repository,
      currentVersion: s.current_version,
      ignoredVersion: s.ignored_version,
      versionCommand: s.version_command,
      updateCommand: s.update_command,
      stopCommand: s.stop_command,
      updateStatus: s.update_status
        ? {
            repository: s.update_status.repository,
            latestVersion: s.update_status.latest_version,
            latestReleaseTitle: s.update_status.latest_release_title,
            latestReleaseURL: s.update_status.latest_release_url,
            latestPublishedAt: swiftDate(s.update_status.latest_published_at),
            lastCheckedAt: swiftDate(s.update_status.last_checked_at),
            errorMessage: s.update_status.error_message,
            etag: s.update_status.etag,
          }
        : null,
    },
    edxAutoStart: s.auto_start === true,
  }))
}
