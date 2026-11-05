import type { Register } from 'claude-code'

// The app replaces these two labels with the Mac's language when it installs the mod.
const SESSION = 'Session'
const WEEK = 'Week'

const LABELS: [kind: string, label: string][] = [
  ['five_hour', SESSION],
  ['seven_day', WEEK],
]

export const register: Register = on => {
  on('session.measure', ($, e, next) => {
    const parts = LABELS.flatMap(([kind, label]) => {
      const window = e.rateLimits.find(w => w.kind === kind)

      return window ? [`${label} ${Math.round(window.percentUsed)}%`] : []
    })

    $.ui.status(parts.length > 0 ? parts.join(' · ') : undefined)

    return next(e)
  })
}
