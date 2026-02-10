/**
 * VideoGridHover Hook
 *
 * Manages video player overlay for the video grid.
 * - Desktop: Opens player on hover (with 250ms delay to avoid accidental triggers)
 * - Desktop: Switching videos uses longer delay (600ms) so users can reach player controls
 * - Desktop: Click bypasses delay for immediate switching
 * - Mobile/Touch: Opens player on click, with backdrop and close button
 * Uses mouseover (which bubbles) for card detection.
 */

const HOVER_DELAY_MS = 250
const SWITCH_DELAY_MS = 600 // Longer delay when switching videos, gives time to reach player controls

const VideoGridHover = {
  mounted() {
    this.currentVideoId = null
    this.pendingVideoId = null
    this.hoverTimeout = null
    this.closeTimeout = null

    // Detect if device supports hover (desktop vs touch)
    this.hasHover = window.matchMedia("(hover: hover)").matches

    // mouseover bubbles, so we can detect card hovers from the grid
    // Only trigger on thumbnail hover, not the entire card
    this.handleMouseOver = (e) => {
      // Skip hover handling on touch devices - use click instead
      if (!this.hasHover) return

      const thumbnail = e.target.closest(".video-card__thumbnail-container")
      const card = e.target.closest(".video-card")

      // Hovering a thumbnail - open/switch player
      if (thumbnail && card) {
        const videoId = card.dataset.videoId
        if (videoId && videoId !== this.currentVideoId) {
          this.clearCloseTimeout()

          // If hovering a different card than pending, cancel previous timer
          if (videoId !== this.pendingVideoId) {
            this.clearHoverTimeout()
            this.pendingVideoId = videoId

            // Use longer delay when switching videos (player already open)
            // This gives users time to move cursor to player controls
            const delay = this.currentVideoId ? SWITCH_DELAY_MS : HOVER_DELAY_MS

            this.hoverTimeout = setTimeout(() => {
              this.currentVideoId = videoId
              this.pendingVideoId = null
              this.pushEvent("hover_video", { id: videoId })
            }, delay)
          }
        }
        return
      }

      // Hovering a card's content area (not thumbnail) - close player
      if (card && !thumbnail && this.currentVideoId) {
        this.clearHoverTimeout()
        this.pendingVideoId = null
        this.scheduleClose()
        return
      }

      // Check if over the player - cancel any pending video switch
      const player = e.target.closest("#video-hover-player-container")
      if (player) {
        this.clearCloseTimeout()
        this.clearHoverTimeout()
        this.pendingVideoId = null
      }
    }

    // Handle click on video cards (for touch devices, also works on desktop)
    // Exclude clicks on the TikTok link which should navigate normally
    this.handleClick = (e) => {
      // Let TikTok link clicks pass through to open in new tab
      if (e.target.closest(".video-card__tiktok-link")) return

      const card = e.target.closest(".video-card")
      if (card) {
        const videoId = card.dataset.videoId
        if (videoId) {
          // On touch devices, toggle behavior - clicking same card closes
          if (!this.hasHover && videoId === this.currentVideoId) {
            this.closePlayer()
            return
          }

          this.clearCloseTimeout()
          this.clearHoverTimeout()
          this.currentVideoId = videoId
          this.pendingVideoId = null
          this.pushEvent("hover_video", { id: videoId })
        }
      }
    }

    // Handle clicks on backdrop or close button
    this.handlePlayerClick = (e) => {
      const backdrop = e.target.closest(".video-hover-player__backdrop")
      const closeBtn = e.target.closest(".video-hover-player__close")

      if (backdrop || closeBtn) {
        e.preventDefault()
        this.closePlayer()
      }
    }

    // Only close when leaving the grid entirely
    this.handleGridLeave = (e) => {
      // Skip on touch devices - they use click to close
      if (!this.hasHover) return

      const relatedTarget = e.relatedTarget

      // Check if going to the player container
      const toPlayer = relatedTarget?.closest?.("#video-hover-player-container")
      if (toPlayer) {
        return
      }

      this.scheduleClose()
    }

    // Handle player container hover leave
    this.handlePlayerLeave = (e) => {
      // Skip on touch devices - they use click to close
      if (!this.hasHover) return

      const relatedTarget = e.relatedTarget
      const toCard = relatedTarget?.closest?.(".video-card")
      const toGrid = relatedTarget?.closest?.("#video-grid-container")

      // Only close if not moving to the grid or a card
      if (!toCard && !toGrid) {
        this.scheduleClose()
      }
    }

    // Attach listeners
    this.el.addEventListener("mouseover", this.handleMouseOver)
    this.el.addEventListener("mouseleave", this.handleGridLeave)
    this.el.addEventListener("click", this.handleClick)

    // Listen for player mount events from TikTokEmbed hook
    this.handlePlayerMounted = () => this.checkForPlayer()
    window.addEventListener('tiktok-player-mounted', this.handlePlayerMounted)
  },

  // Called after LiveView DOM updates to attach player listeners if needed
  checkForPlayer() {
    const playerOverlay = document.getElementById("video-hover-player")
    if (playerOverlay && !playerOverlay._hoverListenersAttached) {
      // Attach hover listeners to the container
      const container = playerOverlay.querySelector("#video-hover-player-container")
      if (container) {
        container.addEventListener("mouseleave", this.handlePlayerLeave)
        container.addEventListener("mouseover", () => {
          // Cancel any pending video switch when user reaches the player
          this.clearCloseTimeout()
          this.clearHoverTimeout()
          this.pendingVideoId = null
        })
      }
      // Attach click listener to the overlay for backdrop/close button
      playerOverlay.addEventListener("click", this.handlePlayerClick)
      playerOverlay._hoverListenersAttached = true
    }
  },

  closePlayer() {
    this.clearCloseTimeout()
    this.clearHoverTimeout()
    this.currentVideoId = null
    this.pendingVideoId = null
    this.pushEvent("leave_video", {})
  },

  scheduleClose() {
    this.clearCloseTimeout()
    this.clearHoverTimeout()
    this.closeTimeout = setTimeout(() => {
      this.currentVideoId = null
      this.pendingVideoId = null
      this.pushEvent("leave_video", {})
    }, 150)
  },

  clearCloseTimeout() {
    if (this.closeTimeout) {
      clearTimeout(this.closeTimeout)
      this.closeTimeout = null
    }
  },

  clearHoverTimeout() {
    if (this.hoverTimeout) {
      clearTimeout(this.hoverTimeout)
      this.hoverTimeout = null
    }
  },

  destroyed() {
    this.el.removeEventListener("mouseover", this.handleMouseOver)
    this.el.removeEventListener("mouseleave", this.handleGridLeave)
    this.el.removeEventListener("click", this.handleClick)
    window.removeEventListener('tiktok-player-mounted', this.handlePlayerMounted)
    this.clearCloseTimeout()
    this.clearHoverTimeout()

    const playerOverlay = document.getElementById("video-hover-player")
    if (playerOverlay) {
      playerOverlay.removeEventListener("click", this.handlePlayerClick)
      const container = playerOverlay.querySelector("#video-hover-player-container")
      if (container) {
        container.removeEventListener("mouseleave", this.handlePlayerLeave)
      }
    }
  }
}

export default VideoGridHover
