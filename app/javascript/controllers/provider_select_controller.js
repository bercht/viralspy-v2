import { Controller } from "@hotwired/stimulus"

const MODELS = {
  openai: [
    { value: "gpt-4o-mini", label: "gpt-4o-mini (recomendado, mais barato)" },
    { value: "gpt-4o",      label: "gpt-4o" }
  ],
  anthropic: [
    { value: "claude-haiku-4-5-20251001", label: "claude-haiku-4-5 (mais barato)" },
    { value: "claude-sonnet-4-6",          label: "claude-sonnet-4-6 (balanceado)" },
    { value: "claude-opus-4-6",            label: "claude-opus-4-6 (máxima qualidade)" }
  ]
}

export default class extends Controller {
  static targets = ["modelSelect"]
  static values  = { currentModel: String }

  connect() {
    const providerSelect = this.element.querySelector("select[data-role='provider']")
    if (providerSelect) this._syncModels(providerSelect.value, this.currentModelValue)
  }

  providerChanged(event) {
    this._syncModels(event.target.value, null)
  }

  _syncModels(provider, currentModel) {
    if (!this.hasModelSelectTarget) return

    const models = MODELS[provider]
    const select = this.modelSelectTarget

    while (select.firstChild) select.removeChild(select.firstChild)

    if (!models || models.length === 0) {
      const opt = document.createElement("option")
      opt.value = ""
      opt.textContent = "Nenhum modelo disponível"
      select.appendChild(opt)
      return
    }

    const valueToSelect = models.find(m => m.value === currentModel)
      ? currentModel
      : models[0].value

    models.forEach(m => {
      const opt = document.createElement("option")
      opt.value = m.value
      opt.textContent = m.label
      opt.selected = m.value === valueToSelect
      select.appendChild(opt)
    })
  }
}
