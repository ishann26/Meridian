/**
 * logger.js — Lightweight structured logger.
 * Prefixes every line with timestamp + level.
 */

"use strict";

const LEVELS = { debug: 0, info: 1, warn: 2, error: 3 };
const currentLevel = LEVELS[process.env.LOG_LEVEL ?? "info"] ?? 1;

function log(level, ...args) {
  if (LEVELS[level] < currentLevel) return;
  const ts = new Date().toISOString();
  const prefix = `[${ts}] [${level.toUpperCase().padEnd(5)}]`;
  if (level === "error") {
    console.error(prefix, ...args);
  } else {
    console.log(prefix, ...args);
  }
}

module.exports = {
  debug: (...a) => log("debug", ...a),
  info:  (...a) => log("info",  ...a),
  warn:  (...a) => log("warn",  ...a),
  error: (...a) => log("error", ...a),
};
