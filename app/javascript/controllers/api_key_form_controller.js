import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]

  connect() {
    this.element.addEventListener("submit", this.handleSubmit.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("submit", this.handleSubmit.bind(this))
  }

  handleSubmit() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = true
    this.submitTarget.value = "Validando..."
  }
}
