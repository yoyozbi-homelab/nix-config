-- Window rules

-- Terminal / file manager transparency
hl.window_rule({ match = { class = "^(kitty)$" }, opacity = 0.8 })
hl.window_rule({ match = { class = "^(ghostty)$" }, opacity = 0.8 })
hl.window_rule({ match = { class = "^(thunar)$" }, opacity = 0.8 })

-- Floating windows
hl.window_rule({ match = { class = "(floating)" }, floating = true })
hl.window_rule({ match = { class = "^(nm-openconnect-auth-dialog)$" }, floating = true })

-- xwaylandvideobridge: fully hidden, no interaction
hl.window_rule({
	match = { class = "^(xwaylandvideobridge)$" },
	opacity = 0.0,
	noanim = true,
	noinitialfocus = true,
	maxsize = "1 1",
	noblur = true,
})
