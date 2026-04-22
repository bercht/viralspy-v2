import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "iconShow", "iconHide", "button"]
  static values = { showLabel: String, hideLabel: String }

  toggle() {
    const isPassword = this.inputTarget.type === "password"
    this.inputTarget.type = isPassword ? "text" : "password"
    this.iconShowTarget.classList.toggle("hidden")
    this.iconHideTarget.classList.toggle("hidden")
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-label", isPassword ? this.hideLabelValue : this.showLabelValue)
    }
  }
}
