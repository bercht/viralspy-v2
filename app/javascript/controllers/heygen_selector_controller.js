import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, type: String }
  static targets = ["select"]

  connect() {
    this.loadOptions()
  }

  async loadOptions() {
    try {
      const resp = await fetch(this.urlValue, {
        headers: { "Accept": "application/json", "X-CSRF-Token": this.csrfToken }
      })
      const data = await resp.json()
      const items = data[this.typeValue] || []

      this.selectTarget.replaceChildren(...this.buildOptions(items))
    } catch {
      const opt = document.createElement("option")
      opt.textContent = "Erro ao carregar"
      this.selectTarget.replaceChildren(opt)
    }
  }

  buildOptions(items) {
    if (!items.length) {
      const opt = document.createElement("option")
      opt.textContent = "Nenhum disponível"
      return [opt]
    }
    return items.map(item => {
      const opt = document.createElement("option")
      opt.value = item.id
      opt.textContent = item.name
      return opt
    })
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
