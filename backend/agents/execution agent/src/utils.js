"use strict";

/**
 * Retry an async function up to `maxAttempts` times with exponential backoff.
 *
 * @param {Function} fn           - async function to retry
 * @param {number}   maxAttempts  - total attempts (default 3 = 1 try + 2 retries)
 * @param {number}   baseDelayMs  - initial delay in ms, doubles each attempt
 * @returns {Promise<any>}
 */
async function withRetry(fn, maxAttempts = 3, baseDelayMs = 300) {
  let lastError;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      if (attempt < maxAttempts) {
        const delay = baseDelayMs * Math.pow(2, attempt - 1);
        console.warn(
          `[Retry] Attempt ${attempt}/${maxAttempts} failed — retrying in ${delay}ms. ` +
          `Error: ${err.message}`
        );
        await _sleep(delay);
      }
    }
  }

  throw lastError;
}

function _sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

module.exports = { withRetry };
