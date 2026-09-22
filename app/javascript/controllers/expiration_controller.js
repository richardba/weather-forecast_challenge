import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    at: String
  }

  connect() {
    const expiresAt = new Date(this.atValue).getTime()
    const remaining = expiresAt - Date.now()

    if (remaining <= 0) {
      this.element.remove()
      return
    }

    this.timeout = setTimeout(() => {
      this.element.remove()
    }, remaining)
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}