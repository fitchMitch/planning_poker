import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "toggle", "lowercase", "uppercase", "digit"]

  toggle() {
    const show = this.inputTarget.type === "password"
    this.inputTarget.type = show ? "text" : "password"
    this.toggleTarget.textContent = show ? "Masquer" : "Afficher"
  }

  check() {
    const value = this.inputTarget.value
    this.setMet(this.lowercaseTarget, /[a-z]/.test(value))
    this.setMet(this.uppercaseTarget, /[A-Z]/.test(value))
    this.setMet(this.digitTarget, /\d/.test(value))
  }

  setMet(target, met) {
    target.classList.toggle("ds-requirement--met", met)
  }
}
