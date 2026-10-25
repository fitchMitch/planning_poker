import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.ping()
    this.interval = setInterval(() => this.ping(), 5 * 60 * 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  ping() {
    fetch(this.urlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
    })
  }
}
