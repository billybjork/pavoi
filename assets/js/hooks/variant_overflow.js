/**
 * VariantOverflow Hook
 *
 * Detects if the variants grid has overflow (more content than fits in 1 line)
 * and shows/hides the expand button accordingly.
 */

const VariantOverflow = {
  mounted() {
    this.checkOverflow()

    // Re-check on window resize
    this.resizeHandler = () => this.checkOverflow()
    window.addEventListener("resize", this.resizeHandler)
  },

  updated() {
    this.checkOverflow()
  },

  destroyed() {
    window.removeEventListener("resize", this.resizeHandler)
  },

  checkOverflow() {
    const wrapper = this.el.querySelector(".product-variants__grid-wrapper")
    const grid = this.el.querySelector(".product-variants__grid")
    const button = this.el.querySelector(".product-variants__expand")

    if (!wrapper || !grid || !button) return

    // Check if grid content overflows the wrapper
    const hasOverflow = grid.scrollHeight > wrapper.clientHeight

    button.style.display = hasOverflow ? "flex" : "none"
  }
}

export default VariantOverflow
