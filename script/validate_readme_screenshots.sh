#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCREENSHOT_DIR="${1:-$ROOT_DIR/Screenshots}"

fail() {
    print -u2 "error: $1"
    exit 1
}

(( $# <= 1 )) || fail "usage: $0 [screenshot-directory]"
command -v magick >/dev/null || fail "ImageMagick is required."

screenshots=(
    preview-light.png
    preview-dark.png
)
typeset -A median_by_name

for name in "${screenshots[@]}"; do
    image_path="$SCREENSHOT_DIR/$name"
    [[ -s "$image_path" ]] || fail "Missing screenshot: $image_path"

    background="#f0f2f7"
    if [[ "$name" == *-dark.png ]]; then
        background="#141417"
    fi

    dimensions=("${(@s:x:)$(magick identify -format '%wx%h' "$image_path")}")
    [[ ${#dimensions[@]} -eq 2 ]] || fail "Unable to read screenshot dimensions: $name"

    density_info=("${(@s:,:)$(magick identify -format '%x,%U' "$image_path")}")
    [[ ${#density_info[@]} -eq 2 ]] || fail "$name is missing screenshot scale metadata."
    case "${density_info[2]}" in
        PixelsPerInch)
            density="$(printf '%.0f' "${density_info[1]}")"
            ;;
        PixelsPerCentimeter)
            density="$(awk -v value="${density_info[1]}" 'BEGIN { printf "%.0f", value * 2.54 }')"
            ;;
        *)
            fail "$name has unsupported screenshot scale units: ${density_info[2]}"
            ;;
    esac

    expected_padding=$((12 * density / 72))
    measurement=(
        "${(@s:,:)$(magick "$image_path" -background "$background" -fuzz 2% -trim -format '%w,%h,%X,%Y' info:)}"
    )
    [[ ${#measurement[@]} -eq 4 ]] || fail "Unable to measure screenshot margins: $name"

    content_width="${measurement[1]}"
    content_height="${measurement[2]}"
    left="${measurement[3]#+}"
    top="${measurement[4]#+}"
    right=$((dimensions[1] - content_width - left))
    bottom=$((dimensions[2] - content_height - top))
    margins=($left $top $right $bottom)
    minimum=${margins[1]}
    maximum=${margins[1]}
    for margin in "${margins[@]}"; do
        (( margin < minimum )) && minimum=$margin
        (( margin > maximum )) && maximum=$margin
    done

    (( minimum >= expected_padding )) \
        || fail "$name has a clipped shadow or insufficient spacing: left=$left top=$top right=$right bottom=$bottom"
    (( maximum - minimum <= 2 )) \
        || fail "$name has uneven spacing: left=$left top=$top right=$right bottom=$bottom"

    median_by_name[$name]="$(magick "$image_path" -colorspace gray -format '%[fx:median]' info:)"
done

light_median="${median_by_name[preview-light.png]}"
dark_median="${median_by_name[preview-dark.png]}"
awk -v value="$light_median" 'BEGIN { exit(value >= 0.75 ? 0 : 1) }' \
    || fail "preview-light.png does not look like a light appearance (median=$light_median)."
awk -v value="$dark_median" 'BEGIN { exit(value <= 0.45 ? 0 : 1) }' \
    || fail "preview-dark.png does not look like a dark appearance (median=$dark_median)."
awk -v light="$light_median" -v dark="$dark_median" \
    'BEGIN { exit(light - dark >= 0.25 ? 0 : 1) }' \
    || fail "Light and dark screenshots are not visually distinct enough."

print "Validated both README screenshots: complete shadows, even margins, and distinct light/dark appearances."
