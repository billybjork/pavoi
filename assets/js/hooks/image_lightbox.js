// Image Lightbox Hook
// Click image to view fullscreen, press Esc or click X to close

const ImageLightbox = {
  mounted() {
    this.el.addEventListener("click", () => this.openLightbox())
  },

  openLightbox() {
    const src = this.el.src
    if (!src) return

    // Create lightbox overlay
    const lightbox = document.createElement("div")
    lightbox.className = "image-lightbox"
    lightbox.innerHTML = `
      <button type="button" class="image-lightbox__close" aria-label="Close">&times;</button>
      <img src="${src}" class="image-lightbox__image" alt="Fullscreen image" />
    `

    // Close handlers
    const close = () => {
      lightbox.remove()
      document.removeEventListener("keydown", handleEsc)
    }

    const handleEsc = (e) => {
      if (e.key === "Escape") close()
    }

    // Click close button
    lightbox.querySelector(".image-lightbox__close").addEventListener("click", close)

    // Click backdrop (but not the image)
    lightbox.addEventListener("click", (e) => {
      if (e.target === lightbox) close()
    })

    // Esc key
    document.addEventListener("keydown", handleEsc)

    document.body.appendChild(lightbox)
  }
}

export default ImageLightbox
