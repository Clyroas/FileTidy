---
name: frontend-design
description: "Aesthetic direction for designs outside an existing brand system"
user-invocable: true
---

# Frontend design

Use this guidance when designing frontend/UI work that is NOT governed by an existing brand or design system. Create distinctive HTML with exceptional attention to aesthetic details and creative choices.

### Design Thinking

Before coding, understand the context and commit to a BOLD aesthetic direction:
- **Purpose**: What problem does this interface solve? Who uses it?
- **Tone**: Pick an extreme: brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian, etc. Use these for inspiration but design one that is true to the aesthetic direction.
- **Differentiation**: What makes this UNFORGETTABLE? What's the one thing someone will remember?

Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work — the key is intentionality, not intensity.

### Aesthetics Guidelines

- **Typography**: Choose fonts that are beautiful, unique, and interesting. Avoid generic fonts like Arial and Inter; opt for distinctive, characterful choices. Pair a distinctive display font with a refined body font.
- **Color & Theme**: Commit to a cohesive aesthetic. Use CSS variables for consistency. Dominant colors with sharp accents outperform timid, evenly-distributed palettes.
- **Motion**: Use animations for effects and micro-interactions. Prioritize CSS-only solutions for HTML. Focus on high-impact moments: one well-orchestrated page load with staggered reveals creates more delight than scattered micro-interactions.
- **Spatial Composition**: Unexpected layouts. Asymmetry. Overlap. Diagonal flow. Grid-breaking elements. Generous negative space OR controlled density.
- **Backgrounds & Visual Details**: Create atmosphere and depth rather than defaulting to solid colors. Gradient meshes, noise textures, geometric patterns, layered transparencies, dramatic shadows, decorative borders, grain overlays.

Vary between light and dark themes, different fonts, different aesthetics. NEVER converge on the same choices across generations.

Match implementation complexity to the aesthetic vision. Maximalist designs need elaborate animations and effects. Minimalist designs need restraint, precision, and careful attention to spacing and subtle details.

## FileTidy notes

- **The shipped UI is WinForms, not HTML.** `FileTidy.ps1` builds its window from `System.Windows.Forms` controls: no CSS, no web fonts, no animation, and only the fonts installed on the user's machine (Segoe UI is the safe default on Windows). Translate this skill's "aesthetic direction" into what WinForms *can* express (a deliberate type scale via `Font` size and weight per label class, consistent spacing through `Padding`, `Margin` and control heights, alignment with `Dock`/`Anchor`/`TableLayoutPanel`, `BackColor`/`ForeColor` accents and grouping) and say what you are trading away.
- **Use it as written when the output *is* HTML:** a mock-up of a proposed FileTidy redesign, a `/wireframe` option being taken to high fidelity, or a project page. Save such files under `design/`.
- **Do not design away the safety UX.** Whatever the direction, every tool keeps a preview grid that fills before anything can be applied, an action button that stays disabled until a preview exists, and a confirmation dialog on every move, rename or Recycle Bin action.
- The window must still work at the form's `MinimumSize` (760×520) and when resized; check that anchored controls do not overlap.
