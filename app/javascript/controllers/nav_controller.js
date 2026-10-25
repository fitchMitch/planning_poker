import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["links"]

  toggle() {
    this.linksTarget.classList.toggle("nav-links--open")
  }
}
