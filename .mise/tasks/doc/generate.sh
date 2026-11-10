#!/usr/bin/env bash
#MISE description="Generate reference documentation for Terraform modules"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

log_info "Generating Terraform module documentation..."
"$MISE_PROJECT_ROOT/.mise/tasks/tf/docs.sh"

# Ensure target ref directory for terraform modules exists and copy module READMEs to reference docs
TF_REF_DIR="$MISE_PROJECT_ROOT/docs/reference/terraform-modules"
for module_dir in "$MISE_PROJECT_ROOT/modules"/*; do
    if [ -d "$module_dir" ] && [ "$(basename "$module_dir")" != "_template" ]; then
        mod_name="$(basename "$module_dir")"
        mkdir -p "$TF_REF_DIR/$mod_name"
        if [ -f "$module_dir/README.md" ]; then
            # The copy sits four levels below the repo root, so a link that is relative to
            # the module folder must point back to modules/<module>/. The rewrite covers
            # inline links (with a title or an <angle> target), image links and reference
            # definitions. It skips fenced code blocks and inline code. Absolute URLs,
            # anchors and absolute paths stay unchanged.
            awk -v prefix="../../../../modules/$mod_name/" '
                function rel(t) {
                    return t != "" && t !~ /^[A-Za-z][A-Za-z0-9+.-]*:/ && t !~ /^[\/#]/
                }
                function fix(seg,    out, i, rest, ang) {
                    if (match(seg, /^ ? ? ?\[[^]]+\]:[ \t]+/)) {
                        out = substr(seg, 1, RLENGTH)
                        rest = substr(seg, RLENGTH + 1)
                        ang = (substr(rest, 1, 1) == "<")
                        if (ang) { out = out "<"; rest = substr(rest, 2) }
                        return out (rel(rest) ? prefix : "") rest
                    }
                    out = ""
                    while ((i = index(seg, "](")) > 0) {
                        out = out substr(seg, 1, i + 1)
                        rest = substr(seg, i + 2)
                        if (substr(rest, 1, 1) == "<") { out = out "<"; rest = substr(rest, 2) }
                        if (rel(rest)) out = out prefix
                        seg = rest
                    }
                    return out seg
                }
                /^ ? ? ?(```|~~~)/ { fence = !fence; print; next }
                fence { print; next }
                {
                    n = split($0, parts, "`")
                    line = ""
                    for (k = 1; k <= n; k++) {
                        line = line (k > 1 ? "`" : "") (k % 2 == 1 ? fix(parts[k]) : parts[k])
                    }
                    print line
                }
            ' "$module_dir/README.md" > "$TF_REF_DIR/$mod_name/index.md"
        fi
    fi
done

log_info "All documentation generation complete."
