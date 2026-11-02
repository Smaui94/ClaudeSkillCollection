---
name: accessibility-audit
description: Static accessibility audit of web and UI code (HTML, JSX/TSX, Vue, Svelte, Angular, XAML, Android XML, Flutter, Godot Control nodes) against WCAG 2.2 level AA - missing alt texts, unlabeled form fields, non-semantic clickable elements, keyboard access and focus order, visible focus, color contrast, ARIA misuse, missing lang and page title, heading order, target size, autoplay and zoom blocking - naming the WCAG success criterion for each finding. Use when asked to check/review/audit accessibility, a11y, WCAG, screen reader or keyboard support, or barrier-free UI.
---

# Accessibility audit (WCAG 2.2 AA)

Review only: report findings, never change UI code unless the user explicitly asks. A static review finds many problems but can't prove compliance: never claim the UI "is WCAG compliant". Recommend runtime tools and testing with a screen reader and keyboard only.

Source: https://www.w3.org/TR/WCAG22/ · Understanding docs: https://www.w3.org/WAI/WCAG22/Understanding/

## Scope
Check the files/directories the user names, otherwise all UI code: `*.html`, templates (Razor, Jinja, Blade, Thymeleaf), `*.jsx`/`*.tsx`, `*.vue`, `*.svelte`, Angular templates, CSS/SCSS for focus and contrast, XAML, Android layouts, Flutter widgets, Godot `.tscn` UI scenes. Skip `.git/`, build output, `vendor/`, `node_modules/`, generated code and third-party component libraries (report their use, not their internals).

## Steps
1. Detect the UI technology and component library (MUI, Bootstrap, Angular Material … often handle ARIA already).
2. Check page/screen-level rules (AX8, AX9, AX14, AX17), then components (forms, buttons, links, images, dialogs, menus), then CSS (AX5, AX6, AX12).
3. Contrast (AX6): compute the ratio only when both colors are statically known. Relative luminance L = 0.2126 R + 0.7152 G + 0.0722 B with each channel c = c/255, then c ≤ 0.04045 ? c/12.92 : ((c+0.055)/1.055)^2.4; ratio = (L1 + 0.05) / (L2 + 0.05). Required: 4.5:1 normal text, 3:1 large text (≥ 24 px, or ≥ 18.66 px bold) and UI components/graphics.
4. Use linters if installed (never install; mention if helpful): `eslint-plugin-jsx-a11y`, `eslint-plugin-vuejs-accessibility`, `@angular-eslint` template a11y rules, Android Lint accessibility checks.
5. Report (format below) and recommend runtime checks: axe DevTools / `@axe-core/cli`, Lighthouse, Pa11y, Accessibility Insights, Android Accessibility Scanner, plus manual tests with NVDA/VoiceOver/TalkBack and keyboard only.

## Rules (WCAG 2.2 success criterion)
- AX1 error: image/icon without text alternative, or decorative image not hidden (`alt=""`, `aria-hidden`) - 1.1.1 Non-text Content
- AX2 error: form control without a programmatic label (`<label for>`, `aria-label(ledby)`), placeholder used as the only label - 1.3.1, 3.3.2, 4.1.2
- AX3 error: clickable non-semantic element (`div`/`span` with `onClick`) without role, `tabindex` and key handling - use `button`/`a` - 2.1.1 Keyboard, 4.1.2 Name, Role, Value
- AX4 error: keyboard trap, `tabindex` > 0, focus order that doesn't follow the visual order, dialogs that don't move/contain/restore focus - 2.1.2 No Keyboard Trap, 2.4.3 Focus Order
- AX5 error: focus indicator removed (`outline: none`/`0` without a visible replacement) or hidden behind sticky elements - 2.4.7 Focus Visible, 2.4.11 Focus Not Obscured (Minimum)
- AX6 error: text contrast below 4.5:1 (3:1 large text); UI component/graphic contrast below 3:1 - 1.4.3 Contrast (Minimum), 1.4.11 Non-text Contrast
- AX7 warning: ARIA misuse - role that contradicts the native element, `aria-hidden="true"` on focusable content, invalid/misspelled `aria-*` attributes, ARIA where native HTML would do - 4.1.2
- AX8 error: missing or wrong `lang` attribute on the page; language changes not marked - 3.1.1 Language of Page, 3.1.2 Language of Parts
- AX9 warning: skipped heading levels, no `h1`, headings used for styling, missing landmarks (`main`, `nav`) - 1.3.1, 2.4.6 Headings and Labels
- AX10 error: link/button without accessible name (icon-only); warning: non-descriptive text ("click here", "more") - 2.4.4 Link Purpose (In Context), 4.1.2
- AX11 warning: autoplaying audio/video without pause/stop; media without captions - 1.4.2 Audio Control, 1.2.2 Captions (Prerecorded)
- AX12 warning: moving/blinking/auto-updating content longer than 5 s without pause - 2.2.2 Pause, Stop, Hide; info: animations without `prefers-reduced-motion` (best practice, 2.3.3 is AAA)
- AX13 error: information conveyed by color only (error fields only red, links only by color) - 1.4.1 Use of Color
- AX14 warning: missing or generic page title (`<title>`, document title in SPAs on route change) - 2.4.2 Page Titled
- AX15 warning: interactive targets smaller than 24×24 CSS px without enough spacing - 2.5.8 Target Size (Minimum)
- AX16 error: form errors not identified in text or not linked to the field (`aria-describedby`, `aria-invalid`) - 3.3.1 Error Identification
- AX17 error: zoom blocked (`user-scalable=no`, `maximum-scale=1`) or layout that breaks at 200 % / 320 px width - 1.4.4 Resize Text, 1.4.10 Reflow
- AX18 warning: functionality that needs dragging without a single-pointer alternative - 2.5.7 Dragging Movements

## Framework notes
| Technology | Watch for |
| --- | --- |
| React / JSX | `alt`, `htmlFor` (not `for`), `onClick` on `div`, focus management in modals and route changes |
| Vue / Svelte / Angular | `v-html`/`{@html}`/`[innerHTML]` content without structure, custom components that drop `aria-*` attributes |
| XAML (WPF, WinUI, MAUI) | `AutomationProperties.Name`/`HelpText`, `IsTabStop`, `TabIndex`, keyboard accelerators |
| Android | `contentDescription`, `importantForAccessibility`, touch target ≥ 48 dp, `labelFor` |
| Flutter | `Semantics` widgets, `semanticLabel` on `Image`/`Icon`, `excludeSemantics` |
| Godot | `focus_mode`, focus neighbors for keyboard/gamepad navigation, readable font sizes and contrast in themes; screen reader support depends on the engine version - check the docs of the version used |

## False positives to drop
Components from an accessible library used as documented · decorative images correctly marked · contrast findings where colors depend on runtime themes you couldn't resolve (mark as "possible") · hidden content that is intentionally removed from the accessibility tree.

## Report
In the user's language, grouped by file/component:
```
path/to/file:line - error|warning|info - <ID> <rule> - WCAG <number> <name> - <who is affected and how, e.g. "screen reader users hear only 'button'"> - direction: <what must be true afterwards>
```
- Every finding has a concrete location and a WCAG success criterion. Mark findings that depend on runtime state as "possible".
- Bulk hits with one root cause (e.g. one `Button` component without accessible name used 50 times): report once at the component with the count.
- End with a summary: technology, findings per severity and per WCAG principle (perceivable, operable, understandable, robust), the runtime tools to run next, then the 3 most important things to fix first.
- Do not change code. Apply fixes only when the user explicitly asks for it.
