import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "empty", "filterInput", "item", "section", "trigger"]

  connect() {
    this.closingTimer = null
    this.openingHotkeyEvent = null
    this.menuKeyListener = this.handleMenuKeydown.bind(this)
    document.addEventListener("keydown", this.menuKeyListener)
  }

  disconnect() {
    if (this.closingTimer) clearTimeout(this.closingTimer)
    this.openingHotkeyEvent = null
    document.removeEventListener("keydown", this.menuKeyListener)
    if (this.hasDialogTarget && this.dialogTarget.open) {
      this.dialogTarget.classList.remove("is-closing")
      this.dialogTarget.close()
    }
  }

  toggle(event) {
    if (event) event.preventDefault()
    this.dialogTarget.open ? this.close() : this.open()
  }

  open(event) {
    if (event) event.preventDefault()
    if (this.dialogTarget.open) return

    this.dialogTarget.classList.remove("is-closing")
    this.dialogTarget.showModal()
    this.resetMenu()

    requestAnimationFrame(() => this.dialogTarget.focus({ preventScroll: true }))
  }

  openFromHotkey(event) {
    if (this.inEditingContext()) return
    if (event) {
      event.preventDefault()
      this.openingHotkeyEvent = event
    }
    this.open(event)
  }

  close(event) {
    if (event) event.preventDefault()
    if (!this.dialogTarget.open) return

    this.dialogTarget.classList.add("is-closing")
    this.closingTimer = setTimeout(() => {
      if (this.dialogTarget.open) this.dialogTarget.close()
    }, 150)
  }

  afterClose() {
    this.dialogTarget.classList.remove("is-closing")
    this.openingHotkeyEvent = null
    this.resetMenu()
    if (this.hasTriggerTarget) this.triggerTarget.focus({ preventScroll: true })
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  filter() {
    this.applyFilter()
  }

  submitFilter(event) {
    if (event.key !== "Enter") return

    const firstVisibleItem = this.visibleItems()[0]
    if (!firstVisibleItem) return

    event.preventDefault()
    this.activateItem(firstVisibleItem)
  }

  resetMenu() {
    if (this.hasFilterInputTarget) this.filterInputTarget.value = ""
    this.applyFilter()
  }

  handleMenuKeydown(event) {
    if (!this.hasDialogTarget || !this.dialogTarget.open) return
    if (event.metaKey || event.ctrlKey || event.altKey) return

    if (this.openingHotkeyEvent === event) {
      this.openingHotkeyEvent = null
      return
    }

    if (this.inEditingContext()) return

    const key = event.key
    if (key === "/") {
      event.preventDefault()
      this.focusSearch()
      return
    }

    if (/^[1-9]$/.test(key)) {
      const shortcutItem = this.visibleItems().find((item) => item.dataset.omakaseMenuShortcutValue === key)
      if (!shortcutItem) return

      event.preventDefault()
      this.activateItem(shortcutItem)
      return
    }

    if (!this.shouldRouteKeyToFilter(event)) return

    event.preventDefault()
    this.startFilterFromKey(key)
  }

  shouldRouteKeyToFilter(event) {
    const key = event.key

    return key.length === 1 && !event.isComposing && key.trim().length > 0
  }

  startFilterFromKey(key) {
    if (!this.hasFilterInputTarget) return

    this.focusSearch()
    this.filterInputTarget.value = key
    this.filterInputTarget.setSelectionRange(this.filterInputTarget.value.length, this.filterInputTarget.value.length)
    this.applyFilter()
  }

  applyFilter() {
    const query = this.filterQuery()

    this.itemTargets.forEach((item) => {
      const text = `${item.dataset.omakaseMenuTextValue || ""} ${item.textContent || ""}`.toLowerCase()
      item.hidden = query.length > 0 && !text.includes(query)
    })

    this.refreshSections()
    if (this.hasEmptyTarget) this.emptyTarget.hidden = this.visibleItems().length > 0
  }

  refreshSections() {
    this.sectionTargets.forEach((section) => {
      section.hidden = !section.querySelector("[data-omakase-menu-target='item']:not([hidden])")
    })
  }

  visibleItems() {
    return this.itemTargets.filter((item) => !item.hidden)
  }

  filterQuery() {
    if (!this.hasFilterInputTarget) return ""

    return this.filterInputTarget.value.trim().toLowerCase()
  }

  focusSearch() {
    if (!this.hasFilterInputTarget) return

    this.filterInputTarget.focus()
  }

  activateItem(item) {
    if (!item) return

    const actionElement = item.matches("a, button") ? item : item.querySelector("a, button")
    if (!actionElement) return

    if (actionElement.tagName === "A") {
      this.navigateTo(actionElement.href)
      return
    }

    actionElement.click()
  }

  navigateTo(url) {
    if (!url) return

    const destination = new URL(url, window.location.origin)
    const current = new URL(window.location.href)
    const sameLocation = destination.pathname === current.pathname && destination.search === current.search && destination.hash === current.hash

    if (sameLocation) {
      this.close()
      return
    }

    if (window.Turbo?.visit) {
      window.Turbo.visit(destination.toString())
      return
    }

    window.location.assign(destination.toString())
  }

  inEditingContext() {
    const active = document.activeElement

    return !!(
      active &&
      (active.tagName === "INPUT" ||
        active.tagName === "TEXTAREA" ||
        active.isContentEditable)
    )
  }
}
