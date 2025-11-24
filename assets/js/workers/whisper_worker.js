// Whisper Web Worker - Module worker for speech recognition
// Bundles via esbuild (no CDN dependencies - CSP compliant)
// Uses Transformers.js with WebGPU acceleration and CPU/WASM fallback

import { pipeline, env } from "@huggingface/transformers";

// Configure Transformers.js environment for local hosting
// All models will be served from the app's static assets
env.allowLocalModels = false; // We'll use HuggingFace hub but cache locally
env.useBrowserCache = true; // Enable IndexedDB caching
env.allowRemoteModels = true; // Allow initial download from HF hub

let transcriber = null;
let modelLoaded = false;
let currentDevice = null;
// Track ONNX file progress for cumulative download calculation
let fileProgress = {};
let lastReportedPercent = 0;

// Listen for messages from main thread
self.onmessage = async (e) => {
  const { type, data } = e.data;

  try {
    switch (type) {
      case 'load_model':
        await loadModel(data.model, data.device);
        break;

      case 'transcribe':
        await transcribe(data.audio);
        break;

      case 'ping':
        // Health check
        self.postMessage({
          type: 'pong',
          data: {
            modelLoaded,
            device: currentDevice
          }
        });
        break;

      default:
        break;
    }
  } catch (error) {
    console.error('[Whisper Worker] Error:', error);
    self.postMessage({
      type: 'error',
      data: { message: error.message, stack: error.stack }
    });
  }
};

/**
 * Load the Whisper model with device selection and progress reporting
 * @param {string} modelName - HuggingFace model identifier (e.g., 'Xenova/whisper-tiny.en')
 * @param {string} device - 'webgpu' or 'wasm' (CPU fallback)
 */
async function loadModel(modelName, device) {
  try {
    // Reset progress tracking for fresh load
    fileProgress = {};
    lastReportedPercent = 0;

    // Report initial loading state
    self.postMessage({
      type: 'model_loading',
      data: {
        progress: 0,
        status: 'Initializing model...',
        device
      }
    });

    // Detect and validate device support
    const detectedDevice = await detectDevice(device);
    currentDevice = detectedDevice;

    // Create the pipeline with progress callback
    transcriber = await pipeline(
      'automatic-speech-recognition',
      modelName,
      {
        device: detectedDevice,
        // Use fp16 for WebGPU (faster), fp32 for CPU/WASM (more compatible)
        dtype: detectedDevice === 'webgpu' ? 'fp16' : 'fp32',

        // Progress callback - only tracks .onnx files (99%+ of download)
        // JSON config files complete instantly and cause false 100% reports
        progress_callback: (progress) => {
          const file = progress.file || '';
          const isOnnxFile = file.endsWith('.onnx');

          if (progress.status === 'initiate' && isOnnxFile) {
            // Only track ONNX files
            fileProgress[file] = { loaded: 0, total: 0 };
          }
          else if (progress.status === 'progress' && isOnnxFile) {
            // Update this ONNX file's progress
            const loaded = progress.loaded || 0;
            let total = progress.total;
            if (!total && progress.progress > 0 && loaded > 0) {
              total = Math.round(loaded / (progress.progress / 100));
            }

            if (total > 0) {
              fileProgress[file] = { loaded, total };
            }

            // Calculate cumulative progress across ONNX files only
            let totalLoaded = 0;
            let totalSize = 0;
            for (const f in fileProgress) {
              totalLoaded += fileProgress[f].loaded;
              totalSize += fileProgress[f].total;
            }

            if (totalSize > 0) {
              const percent = Math.round((totalLoaded / totalSize) * 100);

              // Only report if progress increased (monotonic)
              if (percent > lastReportedPercent) {
                lastReportedPercent = percent;
                self.postMessage({
                  type: 'model_loading',
                  data: {
                    progress: percent,
                    status: `Downloading model...`,
                    file: file,
                    loaded: totalLoaded,
                    total: totalSize
                  }
                });
              }
            }
          }
          else if (progress.status === 'done' && isOnnxFile) {
            // Mark ONNX file as complete
            if (fileProgress[file] && fileProgress[file].total > 0) {
              fileProgress[file].loaded = fileProgress[file].total;
            }
          }
          else if (progress.status === 'ready') {
            lastReportedPercent = 100;
            self.postMessage({
              type: 'model_loading',
              data: {
                progress: 100,
                status: 'Model ready'
              }
            });
          }
        }
      }
    );

    modelLoaded = true;
    self.postMessage({
      type: 'model_ready',
      data: {
        device: detectedDevice,
        model: modelName
      }
    });

  } catch (error) {
    // If WebGPU fails, try falling back to WASM
    if (device === 'webgpu' && !modelLoaded) {
      self.postMessage({
        type: 'model_loading',
        data: {
          progress: 0,
          status: 'WebGPU failed, falling back to CPU...',
          device: 'wasm'
        }
      });

      // Retry with WASM
      return loadModel(modelName, 'wasm');
    }

    self.postMessage({
      type: 'error',
      data: {
        message: `Failed to load model: ${error.message}`,
        details: error.stack
      }
    });
  }
}

/**
 * Detect and validate device support
 * @param {string} requestedDevice - 'webgpu' or 'wasm'
 * @returns {Promise<string>} - Actual device to use
 */
async function detectDevice(requestedDevice) {
  if (requestedDevice === 'wasm') {
    return 'wasm';
  }

  if (requestedDevice === 'webgpu') {
    if (typeof navigator !== 'undefined' && 'gpu' in navigator) {
      try {
        const adapter = await navigator.gpu.requestAdapter();
        if (adapter) {
          return 'webgpu';
        }
      } catch (_) {
        // WebGPU detection failed
      }
    }
  }

  return 'wasm';
}

/**
 * Transcribe audio using the loaded Whisper model
 * @param {Array<number>} audioArray - Audio samples as Float32 array values
 */
async function transcribe(audioArray) {
  if (!modelLoaded || !transcriber) {
    self.postMessage({
      type: 'error',
      data: { message: 'Model not loaded. Please load the model first.' }
    });
    return;
  }

  try {
    const audioData = new Float32Array(audioArray);
    if (audioData.length === 0) {
      self.postMessage({
        type: 'error',
        data: { message: 'Empty audio data received' }
      });
      return;
    }

    const result = await transcriber(audioData, {
      return_timestamps: false,
      chunk_length_s: 30,
      stride_length_s: 5
    });

    const text = typeof result === 'string' ? result : result.text || '';
    self.postMessage({
      type: 'transcript',
      data: {
        text: text.trim(),
        chunks: result.chunks || null
      }
    });
  } catch (error) {
    console.error('[Whisper Worker] Transcription failed:', error);
    self.postMessage({
      type: 'error',
      data: {
        message: `Transcription failed: ${error.message}`,
        details: error.stack
      }
    });
  }
}

// Error handler for uncaught errors in worker
self.onerror = (error) => {
  self.postMessage({
    type: 'error',
    data: {
      message: 'Worker error: ' + error.message,
      details: error.filename + ':' + error.lineno
    }
  });
};
