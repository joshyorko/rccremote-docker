import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "rr-theme"
const LIGHT_THEME = "light"
const DARK_THEME = "dark"

export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.applyTheme(this.currentTheme())
  }

  toggle() {
    const nextTheme = this.currentTheme() === DARK_THEME ? LIGHT_THEME : DARK_THEME
    this.applyTheme(nextTheme)

    try {
      window.localStorage.setItem(STORAGE_KEY, nextTheme)
    } catch (_error) {
      // Ignore localStorage failures in private browsing or restricted contexts.
    }
  }

  currentTheme() {
    const active = document.documentElement.dataset.theme
    return active === DARK_THEME ? DARK_THEME : LIGHT_THEME
  }

  applyTheme(theme) {
    const normalizedTheme = theme === DARK_THEME ? DARK_THEME : LIGHT_THEME
    document.documentElement.dataset.theme = normalizedTheme

    if (this.hasToggleTarget) {
      const isDark = normalizedTheme === DARK_THEME
      this.toggleTarget.textContent = isDark ? "Light mode" : "Dark mode"
      this.toggleTarget.setAttribute("aria-pressed", String(isDark))
    }
  }
}
