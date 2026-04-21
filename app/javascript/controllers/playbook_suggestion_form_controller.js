import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "label", "spinner"]

  submit(event) {
    this.buttonTarget.disabled = true
    this.labelTarget.textContent = "Gerando..."
    this.spinnerTarget.classList.remove("hidden")

    document.addEventListener("turbo:submit-end", this.reset.bind(this), { once: true })
  }

  reset() {
    this.buttonTarget.disabled = false
    this.labelTarget.textContent = "Gerar"
    this.spinnerTarget.classList.add("hidden")
  }
}
