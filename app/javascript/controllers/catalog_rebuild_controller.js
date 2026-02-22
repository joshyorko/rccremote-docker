import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "form", "submit", "progress", "bar", "percent", "status", "log" ]
  static values = { refreshUrl: String }

  connect() {
    this.running = false
    this.progressValue = 0
    this.progressTimer = null
    this.stageTimer = null
    this.stageIndex = 0
    this.stages = [
      "Initializing rebuild process...",
      "Scanning robots for robot.yaml files...",
      "Building environments from conda.yaml definitions...",
      "Exporting bundles and importing into holotree...",
      "Finalizing catalog state..."
    ]
  }

  disconnect() {
    this.clearTimers()
  }

  async start(event) {
    event.preventDefault()
    if (this.running) return

    this.running = true
    this.stageIndex = 0
    this.progressValue = 2

    this.showProgress()
    this.resetLog()
    this.setStatus("Rebuild in progress", "is-running")
    this.setButtonLoading(true)
    this.updateProgress(this.progressValue)
    this.appendLog("Rebuild request submitted.")
    this.startProgressAnimation()
    this.startStageMessages()

    try {
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        credentials: "same-origin"
      })

      const payload = await response.json().catch(() => ({}))

      if (!response.ok || !payload.success) {
        const message = payload.error || payload.message || "Catalog rebuild failed"
        throw new Error(message)
      }

      this.completeSuccess(payload)
    } catch (error) {
      this.completeFailure(error)
    }
  }

  completeSuccess(payload) {
    this.clearTimers()
    this.updateProgress(100)
    this.setStatus("Catalog rebuild completed", "is-success")
    this.appendLog(payload.message || "Catalog rebuild completed.")
    this.appendOutput(payload.output)
    this.appendLog("Refreshing catalog list...")
    this.finish()

    setTimeout(() => this.refreshCatalogs(), 900)
  }

  completeFailure(error) {
    this.clearTimers()
    this.updateProgress(100)
    this.setStatus("Catalog rebuild failed", "is-failure")
    this.appendLog(error.message || "Catalog rebuild failed.")
    this.finish()
  }

  finish() {
    this.running = false
    this.setButtonLoading(false)
  }

  startProgressAnimation() {
    this.progressTimer = setInterval(() => {
      if (this.progressValue >= 92) return

      const remaining = 92 - this.progressValue
      const increment = Math.max(1, Math.ceil(remaining / 10))
      this.progressValue = Math.min(92, this.progressValue + increment)
      this.updateProgress(this.progressValue)
    }, 420)
  }

  startStageMessages() {
    this.stageTimer = setInterval(() => {
      if (this.stageIndex >= this.stages.length) return

      this.appendLog(this.stages[this.stageIndex])
      this.stageIndex += 1
    }, 900)
  }

  updateProgress(value) {
    this.progressValue = value
    if (this.hasBarTarget) {
      this.barTarget.style.width = `${value}%`
    }
    if (this.hasPercentTarget) {
      this.percentTarget.textContent = `${value}%`
    }
  }

  showProgress() {
    if (this.hasProgressTarget) {
      this.progressTarget.hidden = false
    }
  }

  resetLog() {
    if (!this.hasLogTarget) return

    this.logTarget.innerHTML = ""
    this.appendLog("Ready.")
  }

  appendLog(message) {
    if (!this.hasLogTarget) return

    const line = document.createElement("div")
    line.className = "rebuild-progress__line"
    line.textContent = `> ${message}`
    this.logTarget.appendChild(line)
    this.logTarget.scrollTop = this.logTarget.scrollHeight
  }

  appendOutput(output) {
    const lines = output.toString().split(/\r?\n/).map((line) => line.trim()).filter(Boolean)
    if (lines.length === 0) return

    this.appendLog("RCC output:")
    lines.slice(-8).forEach((line) => this.appendLog(line))
  }

  setStatus(message, stateClass) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("is-running", "is-success", "is-failure")
    this.statusTarget.classList.add(stateClass)
  }

  setButtonLoading(loading) {
    if (!this.hasSubmitTarget) return

    if (loading) {
      this.submitTarget.disabled = true
      this.submitTarget.classList.add("is-loading")
      this.submitTarget.dataset.originalLabel ||= this.submitTarget.textContent.trim()
      this.submitTarget.textContent = "Rebuilding..."
      return
    }

    this.submitTarget.disabled = false
    this.submitTarget.classList.remove("is-loading")
    this.submitTarget.textContent = this.submitTarget.dataset.originalLabel || "Rebuild catalogs"
  }

  refreshCatalogs() {
    const refreshUrl = this.hasRefreshUrlValue && this.refreshUrlValue.length > 0 ? this.refreshUrlValue : window.location.pathname

    if (window.Turbo) {
      window.Turbo.visit(refreshUrl)
    } else {
      window.location.assign(refreshUrl)
    }
  }

  clearTimers() {
    clearInterval(this.progressTimer)
    clearInterval(this.stageTimer)
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content.toString() || ""
  }
}
