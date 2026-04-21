import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "message"]

  validate() {
    this.buttonTarget.textContent = "Validando..."
    this.buttonTarget.disabled = true

    fetch("/settings/media_generation/validate_key", {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "application/json"
      }
    })
      .then(r => r.json())
      .then(data => {
        this.buttonTarget.textContent = "Testar agora"
        this.buttonTarget.disabled = false
        this.messageTarget.textContent = data.message
      })
      .catch(() => {
        this.buttonTarget.textContent = "Testar agora"
        this.buttonTarget.disabled = false
        this.messageTarget.textContent = "Erro ao validar"
      })
  }
}
