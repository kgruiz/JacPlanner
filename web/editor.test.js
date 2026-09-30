import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { _jac } from "../.jac/client/web/compiled/jac_prelude.js";

// Build with `jac build --as client web` before testing the emitted focus effect.
const compiled = readFileSync(
  new URL("../.jac/client/web/compiled/web/main.js", import.meta.url),
  "utf8",
);
const start = compiled.indexOf("  useEffect(() => {\n    if (!__jacS_editing.val)");
const ending = "  }, [__jacS_editing.val]);";
const effect = new Function(
  "_jac", "useEffect", "__jacS_editing", "__jacS_busy", "document",
  compiled.slice(start, compiled.indexOf(ending, start) + ending.length),
);
const recoveryStart = compiled.indexOf("  useEffect(() => {", compiled.indexOf(ending, start) + ending.length);
const recoveryEnding = "  }, [__jacS_editing.val, __jacS_busy.val]);";
const recoverFocus = new Function(
  "useEffect", "__jacS_editing", "__jacS_busy", "document",
  compiled.slice(recoveryStart, compiled.indexOf(recoveryEnding, recoveryStart) + recoveryEnding.length),
);

function EditorHarness() {
  let cleanup;
  let listener;
  const editing = { val: true, set(value) { this.val = value; } };
  const busy = { val: false };
  const document = {
    addEventListener(name, handler) { listener = handler; },
    removeEventListener(name, handler) { if (listener === handler) listener = null; },
  };

  function Control() {
    return { isConnected: true, matches: () => false, focus() { document.activeElement = this; } };
  }

  const opener = Control();
  const title = Control();
  const save = Control();
  const fallback = Control();
  const editor = {
    ...Control(),
    querySelector: () => title,
    querySelectorAll: () => busy.val ? [] : [title, save],
    contains: control => [title, save, editor].includes(control),
  };
  document.activeElement = opener;
  document.getElementById = () => editor;
  document.querySelector = () => fallback;
  effect(_jac, callback => { cleanup = callback(); }, editing, busy, document);

  return {
    document, editing, busy, opener, title, save, editor, fallback,
    recoverFocus: () => recoverFocus(callback => callback(), editing, busy, document),
    close: () => cleanup(),
    key(key, shiftKey = false) {
      const event = { key, shiftKey, prevented: false, preventDefault() { this.prevented = true; } };
      listener(event);

      return event;
    },
    hasListener: () => listener !== null,
  };
}

test("editor enters focus, wraps both Tab directions, and restores its opener", () => {
  const app = EditorHarness();

  expect(app.document.activeElement).toBe(app.title);
  app.key("Tab", true);
  expect(app.document.activeElement).toBe(app.save);
  app.key("Tab");
  expect(app.document.activeElement).toBe(app.title);
  app.key("Escape");
  expect(app.editing.val).toBe(false);
  app.close();
  expect(app.document.activeElement).toBe(app.opener);
  expect(app.hasListener()).toBe(false);
});

test("pending saves retain focus and suppress Escape with the live busy value", () => {
  const app = EditorHarness();
  app.busy.val = true;

  expect(app.key("Escape").prevented).toBe(true);
  expect(app.editing.val).toBe(true);
  expect(app.key("Tab").prevented).toBe(true);
  expect(app.document.activeElement).toBe(app.editor);
  app.busy.val = false;
  app.key("Escape");
  expect(app.editing.val).toBe(false);
  app.opener.isConnected = false;
  app.close();
  expect(app.document.activeElement).toBe(app.fallback);
});

test("failed saves restore lost dialog focus without moving an active editor control", () => {
  const app = EditorHarness();
  app.busy.val = true;
  app.document.activeElement = app.opener;
  app.recoverFocus();

  expect(app.document.activeElement).toBe(app.opener);
  app.busy.val = false;
  app.recoverFocus();
  expect(app.document.activeElement).toBe(app.title);
  app.document.activeElement = app.save;
  app.recoverFocus();
  expect(app.document.activeElement).toBe(app.save);
  app.editing.val = false;
  app.document.activeElement = app.opener;
  app.recoverFocus();
  expect(app.document.activeElement).toBe(app.opener);
  app.close();
});
