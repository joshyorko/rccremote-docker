import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "rr-theme"
const LIGHT_THEME = "light"
const DARK_THEME = "dark"

export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.mediaQueryList = window.matchMedia("(prefers-color-scheme: dark)")
    this.handleSystemThemeChange = this.handleSystemThemeChange.bind(this)
    this.handleStorageChange = this.handleStorageChange.bind(this)

    this.mediaQueryList.addEventListener("change", this.handleSystemThemeChange)
    window.addEventListener("storage", this.handleStorageChange)

    this.applyTheme(this.currentTheme())
  }

  disconnect() {
    if (this.mediaQueryList) {
      this.mediaQueryList.removeEventListener("change", this.handleSystemThemeChange)
    }

    window.removeEventListener("storage", this.handleStorageChange)
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
    const storedTheme = this.storedTheme()
    if (storedTheme) {
      return storedTheme
    }

    const active = document.documentElement.dataset.theme
    if (active === DARK_THEME || active === LIGHT_THEME) {
      return active
    }

    return this.systemTheme()
  }

  applyTheme(theme) {
    const normalizedTheme = theme === DARK_THEME ? DARK_THEME : LIGHT_THEME
    document.documentElement.dataset.theme = normalizedTheme
    document.documentElement.style.colorScheme = normalizedTheme
    this.syncThemeColor(normalizedTheme)

    if (this.hasToggleTarget) {
      const isDark = normalizedTheme === DARK_THEME
      this.toggleTarget.textContent = isDark ? "Light mode" : "Dark mode"
      this.toggleTarget.setAttribute("aria-pressed", String(isDark))
    }
  }

  handleSystemThemeChange() {
    if (this.storedTheme()) {
      return
    }

    this.applyTheme(this.systemTheme())
  }

  handleStorageChange(event) {
    if (event.key !== STORAGE_KEY) {
      return
    }

    this.applyTheme(this.currentTheme())
  }

  storedTheme() {
    try {
      const saved = window.localStorage.getItem(STORAGE_KEY)
      return saved === DARK_THEME || saved === LIGHT_THEME ? saved : null
    } catch (_error) {
      return null
    }
  }

  systemTheme() {
    return this.mediaQueryList?.matches ? DARK_THEME : LIGHT_THEME
  }

  syncThemeColor(theme) {
    const meta = document.querySelector('meta[name="theme-color"]')
    if (meta) {
      meta.setAttribute("content", theme === DARK_THEME ? "#0b1118" : "#f3efe6")
    }
  }
}
