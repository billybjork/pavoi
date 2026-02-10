/**
 * TikTokEmbed Hook
 *
 * Embeds TikTok video using player/v1 iframe API.
 * Falls back to "Open in TikTok" link if embed fails.
 * Reuses iframe when video changes (via updated callback) to avoid destroy/recreate cycle.
 *
 * Structure: Hook is on container with data attributes, manages player in child #tiktok-embed div.
 * The child div has phx-update="ignore" so LiveView preserves our iframe.
 */

const TikTokEmbed = {
  mounted() {
    this.videoId = this.el.dataset.videoId
    this.videoUrl = this.el.dataset.videoUrl
    this.embedContainer = this.el.querySelector("#tiktok-embed")
    this.iframe = null
    this.timeout = null

    // Notify VideoGridHover hook that player container is ready
    window.dispatchEvent(new CustomEvent('tiktok-player-mounted'))

    this.createPlayer()
  },

  updated() {
    const newVideoId = this.el.dataset.videoId
    const newVideoUrl = this.el.dataset.videoUrl

    // Only update if video actually changed
    if (newVideoId && newVideoId !== this.videoId) {
      this.videoId = newVideoId
      this.videoUrl = newVideoUrl

      // Reuse existing iframe by updating src
      if (this.iframe && this.embedContainer.contains(this.iframe)) {
        this.updateIframeSrc()
      } else {
        this.iframe = null
        this.createPlayer()
      }
    }
  },

  getPlayerUrl() {
    const params = new URLSearchParams({
      autoplay: "1",
      loop: "0",
      controls: "1",
      music_info: "0",
      description: "0",
      rel: "0"
    })
    return `https://www.tiktok.com/player/v1/${this.videoId}?${params}`
  },

  getSpinnerSVG() {
    return `<svg class="tiktok-player-loading__spinner" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <circle cx="12" cy="12" r="10" stroke-opacity="0.25" />
      <path d="M12 2a10 10 0 0 1 10 10" stroke-linecap="round" />
    </svg>`
  },

  updateIframeSrc() {
    // Clear previous timeout
    if (this.timeout) clearTimeout(this.timeout)

    // Show loading state
    this.iframe.style.display = "none"
    let loading = this.embedContainer.querySelector(".tiktok-player-loading")
    if (!loading) {
      loading = document.createElement("div")
      loading.className = "tiktok-player-loading"
      loading.innerHTML = this.getSpinnerSVG()
      this.embedContainer.insertBefore(loading, this.iframe)
    }

    // Update iframe src - this triggers a reload
    this.iframe.src = this.getPlayerUrl()

    // Set fallback timeout
    this.timeout = setTimeout(() => {
      if (this.iframe && this.iframe.style.display === "none") {
        this.showFallback()
      }
    }, 10000)
  },

  createPlayer() {
    // Show loading state (skeleton with spinner)
    this.embedContainer.innerHTML = `
      <div class="tiktok-player-loading">
        ${this.getSpinnerSVG()}
      </div>
    `

    // Create iframe with player/v1 API
    this.iframe = document.createElement("iframe")
    this.iframe.src = this.getPlayerUrl()
    this.iframe.className = "tiktok-player"
    this.iframe.allow = "accelerometer; autoplay; encrypted-media; gyroscope; fullscreen"
    this.iframe.allowFullscreen = true
    this.iframe.style.display = "none"

    this.iframe.onload = () => {
      // Hide loading, show iframe
      const loading = this.embedContainer.querySelector(".tiktok-player-loading")
      if (loading) loading.remove()
      this.iframe.style.display = "block"
      if (this.timeout) clearTimeout(this.timeout)
    }

    this.iframe.onerror = () => {
      this.showFallback()
    }

    this.embedContainer.appendChild(this.iframe)

    // Fallback timeout if iframe doesn't load
    this.timeout = setTimeout(() => {
      if (this.iframe && this.iframe.style.display === "none") {
        this.showFallback()
      }
    }, 10000)
  },

  showFallback() {
    if (this.timeout) clearTimeout(this.timeout)

    this.embedContainer.innerHTML = `
      <div class="tiktok-player-fallback">
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <path d="m22 8-6 4 6 4V8Z" /><rect x="2" y="6" width="14" height="12" rx="2" />
        </svg>
        <p>Video preview unavailable</p>
        <a href="${this.videoUrl}" target="_blank" rel="noopener noreferrer" class="tiktok-player-fallback__link">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
            <polyline points="15 3 21 3 21 9" />
            <line x1="10" y1="14" x2="21" y2="3" />
          </svg>
          Watch on TikTok
        </a>
      </div>
    `
    this.iframe = null
  },

  destroyed() {
    if (this.timeout) clearTimeout(this.timeout)
    if (this.iframe) {
      // Pause before removing
      try {
        this.iframe.contentWindow?.postMessage(
          JSON.stringify({ type: "pause", "x-tiktok-player": true }),
          "*"
        )
      } catch (e) {
        // Ignore cross-origin errors
      }
      this.iframe.remove()
    }
  }
}

export default TikTokEmbed
