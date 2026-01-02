// Image Lightbox Hook
// Captures Escape key to close lightbox without closing parent modal

const ImageLightbox = {
  mounted() {
    this.handleKeydown = (e) => {
      if (e.key === "Escape") {
        // Stop the event from reaching the modal's handler
        e.stopImmediatePropagation()
        e.preventDefault()
        // Push the close event to LiveView
        this.pushEvent("close_lightbox", {})
      }
    }

    // Use capture phase to intercept before other handlers
    document.addEventListener("keydown", this.handleKeydown, true)
  },

  destroyed() {
    document.removeEventListener("keydown", this.handleKeydown, true)
  }
}

export default ImageLightbox
