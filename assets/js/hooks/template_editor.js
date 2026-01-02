/**
 * TemplateEditor Hook
 *
 * Provides a visual block-based template editor using GrapesJS.
 * Supports two template types:
 * - "email": Uses newsletter preset optimized for email HTML output
 * - "page": Uses webpage preset for web pages (like SMS consent form)
 *
 * GrapesJS is lazy-loaded when this hook mounts to reduce main bundle size.
 */

// Lazy-loaded modules (cached after first load)
let grapesjs = null
let newsletterPlugin = null
let webpagePlugin = null
let cssLoaded = false

/**
 * Load GrapesJS and its dependencies on demand based on template type
 */
async function loadGrapesJS(templateType) {
  if (!grapesjs) {
    const grapes = await import('grapesjs')
    grapesjs = grapes.default
  }

  // Load type-specific preset
  if (templateType === 'email' && !newsletterPlugin) {
    const newsletter = await import('grapesjs-preset-newsletter')
    newsletterPlugin = newsletter.default
  } else if (templateType === 'page' && !webpagePlugin) {
    const webpage = await import('grapesjs-preset-webpage')
    webpagePlugin = webpage.default
  }

  // Inject CSS if not already loaded
  if (!cssLoaded) {
    await import('grapesjs/dist/css/grapes.min.css')
    cssLoaded = true
  }
}

/**
 * Extract body content from a full HTML document.
 */
function extractBodyContent(html) {
  if (!html || typeof html !== 'string') return ''

  const bodyMatch = html.match(/<body[^>]*>([\s\S]*)<\/body>/i)
  if (bodyMatch) {
    return bodyMatch[1].trim()
  }

  if (html.includes('<!DOCTYPE') || html.includes('<html')) {
    const htmlTagMatch = html.match(/<html[^>]*>([\s\S]*)<\/html>/i)
    if (htmlTagMatch) {
      let content = htmlTagMatch[1]
      content = content.replace(/<head[^>]*>[\s\S]*<\/head>/i, '')
      return content.trim()
    }
  }

  return html.trim()
}

/**
 * Wrap body content in a full HTML email document.
 */
function wrapInHtmlDocument(bodyContent) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <title>Email</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f5f5f5;">
${bodyContent}
</body>
</html>`
}

function debounce(fn, delay) {
  let timer = null
  return (...args) => {
    if (timer) clearTimeout(timer)
    timer = setTimeout(() => fn(...args), delay)
  }
}

/**
 * Extract form config from page template HTML
 */
function extractFormConfig(html) {
  const parser = new DOMParser()
  const doc = parser.parseFromString(html, 'text/html')
  const formEl = doc.querySelector('[data-form-type="consent"]')

  if (!formEl) return {}

  return {
    button_text: formEl.getAttribute('data-button-text') || 'JOIN THE PROGRAM',
    email_label: formEl.getAttribute('data-email-label') || 'Email',
    phone_label: formEl.getAttribute('data-phone-label') || 'Phone Number',
    phone_placeholder: formEl.getAttribute('data-phone-placeholder') || '(555) 123-4567'
  }
}

/**
 * Register custom Consent Form block for page templates
 */
function registerConsentFormBlock(editor) {
  const blockManager = editor.BlockManager

  // Add the block to the sidebar
  blockManager.add('consent-form', {
    label: 'Consent Form',
    category: 'Forms',
    media: `<svg viewBox="0 0 24 24" fill="currentColor">
      <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V5h14v14z"/>
      <path d="M7 12h2v5H7zm4-3h2v8h-2zm4-3h2v11h-2z"/>
    </svg>`,
    content: {
      type: 'consent-form'
    },
    attributes: { class: 'gjs-block-consent' }
  })

  // Register custom component type
  editor.DomComponents.addType('consent-form', {
    isComponent: el => el.getAttribute && el.getAttribute('data-form-type') === 'consent',
    model: {
      defaults: {
        tagName: 'div',
        droppable: false,
        copyable: false,
        attributes: {
          'data-form-type': 'consent',
          'data-button-text': 'JOIN THE PROGRAM',
          'data-email-label': 'Email',
          'data-phone-label': 'Phone Number',
          'data-phone-placeholder': '(555) 123-4567'
        },
        styles: `
          padding: 30px;
          border: 3px dashed #A9BDB6;
          background: linear-gradient(135deg, #f8faf9 0%, #e8f0ec 100%);
          text-align: center;
          border-radius: 8px;
          margin: 20px 0;
        `,
        components: `
          <div style="color: #2E4042; margin-bottom: 10px;">
            <strong style="font-size: 18px;">📋 Consent Form</strong>
          </div>
          <p style="color: #666; margin: 0; font-size: 14px;">
            The SMS consent form will appear here.<br>
            <small>Edit properties in the right panel to customize button text and labels.</small>
          </p>
        `,
        traits: [
          {
            type: 'text',
            name: 'data-button-text',
            label: 'Button Text',
            changeProp: false
          },
          {
            type: 'text',
            name: 'data-email-label',
            label: 'Email Label',
            changeProp: false
          },
          {
            type: 'text',
            name: 'data-phone-label',
            label: 'Phone Label',
            changeProp: false
          },
          {
            type: 'text',
            name: 'data-phone-placeholder',
            label: 'Phone Placeholder',
            changeProp: false
          }
        ]
      }
    }
  })
}

/**
 * Get default content based on template type
 */
function getDefaultContent(templateType) {
  if (templateType === 'page') {
    return `
      <section style="min-height: 100vh; background: linear-gradient(180deg, #f8f8f8 0%, #e8e8e8 100%); padding: 40px 20px; font-family: Georgia, 'Times New Roman', serif;">
        <div style="max-width: 500px; margin: 0 auto; background: #fff; box-shadow: 0 4px 20px rgba(0,0,0,0.1); border-radius: 8px; overflow: hidden;">
          <div style="text-align: center; padding: 40px 30px 20px; background: #2E4042;">
            <span style="font-size: 28px; letter-spacing: 4px; color: #fff;">PAVOI</span>
          </div>
          <div style="padding: 30px 40px 40px;">
            <h1 style="text-align: center; color: #2E4042; font-weight: normal; margin: 0 0 30px 0; font-size: 24px;">
              Join the Pavoi Creator Program
            </h1>
            <div style="margin-bottom: 30px;">
              <p style="margin: 0 0 15px 0; color: #333;">Get access to:</p>
              <ul style="margin: 0; padding-left: 20px; color: #555; line-height: 1.8;">
                <li><strong>Free product samples</strong> shipped directly to you</li>
                <li><strong>Competitive commissions</strong> on every sale</li>
                <li><strong>Early access</strong> to new drops</li>
                <li><strong>Direct support</strong> from our team</li>
              </ul>
            </div>
            <div data-form-type="consent" data-button-text="JOIN THE PROGRAM" data-email-label="Email" data-phone-label="Phone Number" data-phone-placeholder="(555) 123-4567" style="padding: 30px; border: 3px dashed #A9BDB6; background: linear-gradient(135deg, #f8faf9 0%, #e8f0ec 100%); text-align: center; border-radius: 8px; margin: 20px 0;">
              <div style="color: #2E4042; margin-bottom: 10px;">
                <strong style="font-size: 18px;">📋 Consent Form</strong>
              </div>
              <p style="color: #666; margin: 0; font-size: 14px;">
                The SMS consent form will appear here.<br>
                <small>Edit properties in the right panel to customize button text and labels.</small>
              </p>
            </div>
          </div>
        </div>
      </section>
    `
  }

  // Default email template
  return `
    <table style="width: 100%; max-width: 600px; margin: 0 auto; background-color: #ffffff;">
      <tr>
        <td style="padding: 40px 20px; text-align: center;">
          <h1 style="margin: 0 0 20px 0; color: #333333;">Welcome!</h1>
          <p style="margin: 0; color: #666666;">Start building your email template by dragging blocks from the right panel.</p>
        </td>
      </tr>
    </table>
  `
}

export default {
  async mounted() {
    const templateType = this.el.dataset.templateType || 'email'

    // Lazy load GrapesJS with appropriate preset (reduces main bundle by ~200-300KB)
    await loadGrapesJS(templateType)

    const rawHtml = this.el.dataset.htmlContent || ''
    const initialContent = extractBodyContent(rawHtml)
    const defaultContent = getDefaultContent(templateType)

    // Select plugin based on template type
    const plugin = templateType === 'email' ? newsletterPlugin : webpagePlugin
    const pluginOpts = templateType === 'email'
      ? { inlineCss: true }
      : { blocksBasicOpts: { flexGrid: true } }

    // Initialize GrapesJS
    this.editor = grapesjs.init({
      container: this.el,
      height: '100%',
      width: 'auto',
      fromElement: false,
      storageManager: false,

      plugins: [plugin],
      pluginsOpts: {
        [plugin]: pluginOpts
      },

      // Load initial content
      components: initialContent || defaultContent,

      // Asset manager
      assetManager: {
        embedAsBase64: true,
        upload: false,
      },
    })

    // Register consent form block for page templates
    if (templateType === 'page') {
      registerConsentFormBlock(this.editor)
    }

    // Store template type for later use
    this.templateType = templateType

    // Debounced update function
    const pushHtmlUpdate = debounce(() => {
      if (!this.editor) return

      try {
        let html = null
        const hasCommand = this.editor.Commands.has('gjs-get-inlined-html')
        if (hasCommand) {
          html = this.editor.runCommand('gjs-get-inlined-html')
        }

        if (!html) {
          const bodyHtml = this.editor.getHtml()
          const css = this.editor.getCss()
          html = css ? `<style>${css}</style>${bodyHtml}` : bodyHtml
        }

        if (html && html.trim()) {
          const fullDocument = wrapInHtmlDocument(html)
          const payload = { html: fullDocument }

          // Extract form config for page templates
          if (this.templateType === 'page') {
            payload.form_config = extractFormConfig(html)
          }

          this.pushEvent('template_html_updated', payload)
        }
      } catch (err) {
        console.error('[TemplateEditor] Error exporting HTML:', err)
      }
    }, 800)

    // Listen for content changes
    this.editor.on('component:update', pushHtmlUpdate)
    this.editor.on('component:add', pushHtmlUpdate)
    this.editor.on('component:remove', pushHtmlUpdate)
    this.editor.on('component:clone', pushHtmlUpdate)
    this.editor.on('component:drag:end', pushHtmlUpdate)
    this.editor.on('style:update', pushHtmlUpdate)
  },

  destroyed() {
    if (this.editor) {
      this.editor.destroy()
      this.editor = null
    }
  }
}
