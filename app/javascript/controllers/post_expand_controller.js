import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "toggleBtn"]

  connect() {
    this.collapse()
  }

  toggle(event) {
    event.preventDefault()

    if (this.contentTarget.classList.contains("hidden")) {
      this.expand()
    } else {
      this.collapse()
    }
  }

  expand() {
    this.contentTarget.classList.remove("hidden")
    this.toggleBtnTarget.textContent = "Ver menos"
  }

  collapse() {
    this.contentTarget.classList.add("hidden")
    this.toggleBtnTarget.textContent = "Ver mais"
  }
}
