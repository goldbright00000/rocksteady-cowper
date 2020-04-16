#!/usr/bin/env bash

# convert the clipping mask to a png
#set -o verbose
set -e
set -u


readonly GRAPHICS_DIR="/Var/motocal/graphics"


trap clean_up INT TERM EXIT


readonly DESIGN_SVG="$1.svg"
readonly MASK_SVG="$1_mask.svg"

readonly DESIGN_PNG="$1.png"
readonly MASK_PNG="$1_mask.png"

readonly MASK_INVERSE_PNG="$1_mask_inverse.png"
readonly CLIPPED_PNG="$1_clipped.png"



check_args() {
    if [[ $# -ne 1 ]]; then
        echo "You must provide the Design SVG filename and I'll assume that the mask is something_mark.svg $*"
        exit 1
    fi

    if [[ ! -f "$1.svg" ]]; then
        echo "The Design SVG ($1.svg) does not exist"
        exit 1
    fi

    if [[ ! -f "$1_mask.svg" ]]; then
        echo "The Mask SVG ($1.svg) does not exist"
        exit 1
    fi
}


clean_up() {
    rm -f "$DESIGN_SVG"
    rm -f "$MASK_PNG"
    rm -f "$MASK_SVG"
    rm -f "$MASK_INVERSE_PNG"
    rm -f "$CLIPPED_PNG"
}


remove_old_conversion() {
    rm -f "$DESIGN_PNG"
    rm -f "$MASK_PNG"
}

remove_old_conversion

check_args $*

export PATH=$PATH:/usr/local/bin

#
#  The comment below is from David's original code, now sure what it means.
#
#now we are using bleed mask so we have to remove some properties from this mask
sed -r -i 's/(fill|stroke|stroke-linejoin|stroke-miterlimit)="[^"]*"//g' $MASK_SVG

#
#  librsvg won't allow http(s) in an image link so we need to make sure that 
#  there is a local copy in /var/motocal/graphics and rewrite the URL
#
sed -E -i 's|image xlink:href=\"https\://.*/graphics/([0-9]*).([a-z]{3})\"|image xlink:href=\"/var/motocal/graphics/\1.\2\"|g' $DESIGN_SVG
#
#   Convert the mask SVG to a smaller PNG
#
convert -alpha copy -resize '200' $MASK_SVG $MASK_PNG

if [[ ! -f "$MASK_PNG" ]]; then exit 1; fi


#
#   Convert the design to a PNG
#
convert -resize '200' $DESIGN_SVG $DESIGN_PNG

if [[ ! -f "$DESIGN_PNG" ]]; then exit 1; fi



#
# Invert the clipping mask
#
convert $MASK_PNG -negate $MASK_INVERSE_PNG

if [[ ! -f "$MASK_INVERSE_PNG" ]]; then exit 1; fi

#
# Apply the clipping mask
#
convert $DESIGN_PNG $MASK_INVERSE_PNG -compose DstOut -composite $CLIPPED_PNG

if [[ ! -f "$CLIPPED_PNG" ]]; then exit 1; fi


# 
# 
# add a drop shadow
convert $CLIPPED_PNG  \( -clone 0 -background black -shadow 50x20+0+0 \) -reverse -background none -layers merge +repage $DESIGN_PNG

if [[ ! -f "$DESIGN_PNG" ]]; then exit 1; fi

trap - INT TERM EXIT

clean_up
