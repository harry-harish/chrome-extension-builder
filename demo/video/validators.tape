# VHS tape — "the validators are real" cutaway (~18s).
# Renders a real terminal recording: clean extension validates green,
# a broken CSP gets caught, store-readiness passes. Every line is genuine
# output from the plugin's actual validator scripts.
#
# Prereq: bash demo/video/setup-demo-ext.sh   (creates /tmp/cext-video-demo)
# Render: vhs demo/video/validators.tape      (writes demo/video/validators.gif)

Output demo/video/validators.gif

Set Shell "bash"
Set FontSize 21
Set Width 1240
Set Height 720
Set Theme "Dracula"
Set Padding 24
Set TypingSpeed 45ms

# ── hidden setup: point aliases at the real plugin scripts ──
Hide
Type "export CEB=/Users/harishkumar/Desktop/Cap/research/chrome-extension-builder" Enter
Type "alias validate='python3 $CEB/skills/extension-architect/scripts/validate-manifest.py'" Enter
Type "alias check-csp='bash $CEB/skills/extension-security/scripts/validate-csp.sh'" Enter
Type "alias store-ready='bash $CEB/skills/extension-publishing/scripts/check-store-readiness.sh'" Enter
Type "cd /tmp/cext-video-demo/tab-manager" Enter
Type "clear" Enter
Show

Sleep 600ms
Type "# A clean Manifest V3 extension — does it pass?" Sleep 400ms Enter
Type "validate manifest.json" Sleep 300ms Enter
Sleep 1800ms

Type "# Now a manifest with unsafe-eval in the CSP" Sleep 400ms Enter
Type "check-csp ../broken-manifest.json" Sleep 300ms Enter
Sleep 1800ms

Type "# Store-readiness gate before you ever upload" Sleep 400ms Enter
Type "store-ready ." Sleep 300ms Enter
Sleep 2200ms
