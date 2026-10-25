import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form"]

  toggle() {
    this.displayTarget.hidden = !this.displayTarget.hidden
    this.formTarget.hidden = !this.formTarget.hidden
  }

  cancel() {
    this.displayTarget.hidden = false
    this.formTarget.hidden = true
  }
}
