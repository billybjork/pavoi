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

import { initLinkEditor } from '../lib/grapesjs/link-editor'
import { initListEditor } from '../lib/grapesjs/list-editor'

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
 * Extract <style> tags from a full document head so we can preserve CSS.
 */
function extractHeadStyleTags(html) {
  if (!html || typeof html !== 'string') return ''

  const headMatch = html.match(/<head[^>]*>([\s\S]*?)<\/head>/i)
  if (!headMatch) return ''

  const styleMatches = headMatch[1].match(/<style[^>]*>[\s\S]*?<\/style>/gi)
  return styleMatches ? styleMatches.join('\n') : ''
}

function hasStyleTag(html) {
  return /<style[^>]*>[\s\S]*?<\/style>/i.test(html || '')
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
<body style="margin: 0; padding: 0; background-color: #e6e7e5;">
${bodyContent}
</body>
</html>`
}

/**
 * Export current editor state into the full template payload expected by LiveView.
 */
function exportTemplatePayload(editor, templateType) {
  if (!editor) return null

  let html = null
  const hasCommand = editor.Commands.has('gjs-get-inlined-html')

  if (hasCommand) {
    html = editor.runCommand('gjs-get-inlined-html')
  }

  if (!html) {
    const bodyHtml = editor.getHtml()
    const css = editor.getCss()
    html = css ? `<style>${css}</style>${bodyHtml}` : bodyHtml
  }

  const bodyContent = extractBodyContent(html)

  if (!bodyContent || !bodyContent.trim()) return null

  let css = ''

  if (!hasStyleTag(bodyContent)) {
    const headStyles = extractHeadStyleTags(html)

    if (headStyles && headStyles.trim()) {
      css = headStyles
    } else {
      const cssText = editor.getCss()
      if (cssText && cssText.trim()) {
        css = `<style>${cssText}</style>`
      }
    }
  }

  const normalizedBody = css ? `${css}\n${bodyContent}` : bodyContent
  const payload = { html: wrapInHtmlDocument(normalizedBody) }

  if (templateType === 'page') {
    payload.form_config = extractFormConfig(normalizedBody)
  }

  return payload
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
 * Uses Pavoi brand guidelines:
 * - Trebuchet MS (modern, geometric feel similar to Mier A)
 * - Dark Teal #2e4042 for primary/headers
 * - Sage Green #a9bdb6 for accents/footer
 * - Near Black #282828 for body text
 * - Monospace for button labels (Aperçu Mono equivalent)
 */
function getDefaultContent(templateType) {
  if (templateType === 'page') {
    return `
      <section style="min-height: 100vh; background: linear-gradient(180deg, #e6e7e5 0%, #d8dad8 100%); padding: 40px 20px; font-family: 'Trebuchet MS', Arial, Helvetica, sans-serif;">
        <div style="max-width: 500px; margin: 0 auto; background: #ffffff; box-shadow: 0 4px 20px rgba(0,0,0,0.08); overflow: hidden;">
          <!-- Sage Header -->
          <div style="text-align: center; padding: 30px; background: #a9bdb6;">
            <img src="/images/pavoi-logo-email.png" alt="PAVOI" width="200" style="display: block; height: auto; margin: 0 auto;">
          </div>
          <!-- Content Area -->
          <div style="padding: 40px;">
            <h1 style="text-align: center; color: #2e4042; font-weight: normal; margin: 0 0 30px 0; font-size: 24px; letter-spacing: 2px; text-transform: uppercase;">
              Join the Creator Program
            </h1>
            <div style="margin-bottom: 30px; color: #282828; line-height: 1.7;">
              <p style="margin: 0 0 15px 0;">Get access to:</p>
              <ul style="margin: 0; padding-left: 20px; line-height: 1.8;">
                <li style="margin-bottom: 8px;"><strong>Free product samples</strong> shipped directly to you</li>
                <li style="margin-bottom: 8px;"><strong>Competitive commissions</strong> on every sale</li>
                <li style="margin-bottom: 8px;"><strong>Early access</strong> to new drops</li>
                <li style="margin-bottom: 8px;"><strong>Direct support</strong> from our team</li>
              </ul>
            </div>
            <div data-form-type="consent" data-button-text="JOIN THE PROGRAM" data-email-label="Email" data-phone-label="Phone Number" data-phone-placeholder="(555) 123-4567" style="padding: 30px; border: 3px dashed #a9bdb6; background: linear-gradient(135deg, #f8faf9 0%, #e8f0ec 100%); text-align: center; border-radius: 8px; margin: 20px 0;">
              <div style="color: #2e4042; margin-bottom: 10px;">
                <strong style="font-size: 18px;">📋 Consent Form</strong>
              </div>
              <p style="color: #666; margin: 0; font-size: 14px;">
                The SMS consent form will appear here.<br>
                <small>Edit properties in the right panel to customize button text and labels.</small>
              </p>
            </div>
          </div>
          <!-- Sage Footer -->
          <div style="text-align: center; padding: 25px; background: #a9bdb6;">
            <p style="margin: 0; color: #2e4042; font-size: 14px; letter-spacing: 1px;">Together, we're redefining luxury.</p>
          </div>
        </div>
      </section>
    `
  }

  // Default email template - brand-aligned with sage header/footer
  return `
    <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #e6e7e5;">
      <tr>
        <td align="center" style="padding: 20px;">
          <table width="600" cellpadding="0" cellspacing="0" border="0" style="max-width: 600px; width: 100%;">
            <!-- Sage Header -->
            <tr>
              <td style="background-color: #a9bdb6; padding: 25px; text-align: center;">
                <img src="/images/pavoi-logo-email.png" alt="PAVOI" width="200" style="display: block; height: auto; margin: 0 auto;">
              </td>
            </tr>
            <!-- White Content Area -->
            <tr>
              <td style="background-color: #ffffff; padding: 40px; font-family: 'Trebuchet MS', Arial, Helvetica, sans-serif; color: #282828; line-height: 1.7;">
                <h1 style="color: #2e4042; font-size: 26px; font-weight: normal; text-align: center; letter-spacing: 2px; text-transform: uppercase; margin: 0 0 30px 0;">
                  Welcome to the Creator Program
                </h1>
                <p style="margin: 0 0 20px 0;">Start building your email template by dragging blocks from the right panel.</p>
                <!-- CTA Button -->
                <table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 30px 0;">
                  <tr>
                    <td align="center">
                      <a href="#" style="display: inline-block; background-color: #2e4042; color: #ffffff; padding: 16px 40px; text-decoration: none; font-family: Consolas, Monaco, 'Courier New', monospace; font-size: 13px; letter-spacing: 2px; text-transform: uppercase;">
                        CALL TO ACTION
                      </a>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <!-- Sage Footer -->
            <tr>
              <td style="background-color: #a9bdb6; padding: 25px; text-align: center;">
                <p style="margin: 0; font-family: 'Trebuchet MS', Arial, Helvetica, sans-serif; color: #2e4042; font-size: 14px; letter-spacing: 1px;">Together, we're redefining luxury.</p>
              </td>
            </tr>
          </table>
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

    // Canvas styles injected into the iframe
    // - Background matches the body background used when emails are sent
    // - Disable visited link purple color so links always appear blue
    const canvasCss = templateType === 'email'
      ? 'body { background-color: #e6e7e5; } a:visited { color: #0000EE; }'
      : 'a:visited { color: #0000EE; }'

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

      // Canvas styles - inject CSS into the iframe to match sent email appearance
      canvasCss,

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

    // Initialize custom plugins
    initLinkEditor(this.editor)
    initListEditor(this.editor)

    // Store template type for later use
    this.templateType = templateType
    this.formEl = this.el.closest('form')
    this.htmlInputEl = this.formEl?.querySelector('#email_template_html_body')
    this.formConfigInputEl = this.formEl?.querySelector('#email_template_form_config')

    const syncHiddenFieldsFromEditor = () => {
      try {
        const payload = exportTemplatePayload(this.editor, this.templateType)
        if (!payload) return null

        if (this.htmlInputEl) {
          this.htmlInputEl.value = payload.html
        }

        if (
          this.templateType === 'page' &&
            this.formConfigInputEl &&
            payload.form_config &&
            typeof payload.form_config === 'object'
        ) {
          this.formConfigInputEl.value = JSON.stringify(payload.form_config)
        }

        return payload
      } catch (err) {
        console.error('[TemplateEditor] Error syncing template payload:', err)
        return null
      }
    }

    // Debounced update function
    const pushHtmlUpdate = debounce(() => {
      const payload = syncHiddenFieldsFromEditor()
      if (payload) {
        this.pushEvent('template_html_updated', payload)
      }
    }, 800)

    // Save must always include latest HTML, even if debounce has not fired yet.
    this.handleSubmit = () => {
      const activeElement = document.activeElement
      if (activeElement && typeof activeElement.blur === 'function') {
        activeElement.blur()
      }

      syncHiddenFieldsFromEditor()
    }

    if (this.formEl) {
      this.formEl.addEventListener('submit', this.handleSubmit, true)
    }

    // Listen for content changes
    this.editor.on('component:update', pushHtmlUpdate)
    this.editor.on('component:add', pushHtmlUpdate)
    this.editor.on('component:remove', pushHtmlUpdate)
    this.editor.on('component:clone', pushHtmlUpdate)
    this.editor.on('component:drag:end', pushHtmlUpdate)
    this.editor.on('style:update', pushHtmlUpdate)
  },

  destroyed() {
    if (this.formEl && this.handleSubmit) {
      this.formEl.removeEventListener('submit', this.handleSubmit, true)
    }

    if (this.editor) {
      this.editor.destroy()
      this.editor = null
    }
  }
}
