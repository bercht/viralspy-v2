import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.closeHandler = this.closeOnOutsideClick.bind(this)
    this.escHandler = this.closeOnEsc.bind(this)
  }

  toggle() {
    this.panelTarget.classList.toggle("hidden")
    if (!this.panelTarget.classList.contains("hidden")) {
      document.addEventListener("click", this.closeHandler)
      document.addEventListener("keydown", this.escHandler)
    } else {
      this.cleanup()
    }
  }

  close() {
    this.panelTarget.classList.add("hidden")
    this.cleanup()
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEsc(event) {
    if (event.key === "Escape") this.close()
  }

  cleanup() {
    document.removeEventListener("click", this.closeHandler)
    document.removeEventListener("keydown", this.escHandler)
  }

  disconnect() {
    this.cleanup()
  }
}
