import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    hook: String,
    caption: String,
    hashtags: String
  }
  static targets = ["button", "idle", "copied"]

  async copy(event) {
    event.preventDefault()

    const parts = [this.hookValue, this.captionValue, this.hashtagsValue]
      .map(p => p ? p.trim() : "")
      .filter(p => p.length > 0)

    const text = parts.join("\n\n")

    try {
      await navigator.clipboard.writeText(text)
      this.showCopied()
    } catch (_err) {
      this.fallbackCopy(text)
      this.showCopied()
    }
  }

  showCopied() {
    if (this.hasIdleTarget) this.idleTarget.classList.add("hidden")
    if (this.hasCopiedTarget) this.copiedTarget.classList.remove("hidden")

    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => this.reset(), 2000)
  }

  reset() {
    if (this.hasIdleTarget) this.idleTarget.classList.remove("hidden")
    if (this.hasCopiedTarget) this.copiedTarget.classList.add("hidden")
  }

  fallbackCopy(text) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.select()
    try {
      document.execCommand("copy")
    } finally {
      document.body.removeChild(textarea)
    }
  }

  disconnect() {
    clearTimeout(this.resetTimer)
  }
}
