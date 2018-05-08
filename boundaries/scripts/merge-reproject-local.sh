#!/bin/bash

# To call the script open the terminal in the same folder as the script
# Ensure it is executable: $ chmod u+x merge-reproject.sh
# Call it with $ ./merge-distrito-local-reproject.sh

# SET TO PATH WHERE YOU WANT THE SHP TO BE CREATED
FILE='../source/DISTRITO-LOCAL-wgs1984.shp' # name of file to be merged to
LAYER='DISTRITO-LOCAL-wgs1984' # should be the same as
TSRS='EPSG:4326' # target CRS
BASE='/vsizip//vsicurl/http://cartografia.ife.org.mx//descargas/distritacion2017/local'


for i in {01..32}

do

    SRC="$BASE/$i/$i.zip/DISTRITO_LOCAL.shp"

    if [ -f "$FILE" ]
        then
                echo "transforming and merging $SRC..."
                ogr2ogr \
                -f 'ESRI Shapefile' \
                -t_srs $TSRS \
                -update -append $FILE $SRC \
                -nln $LAYER
        else
                echo "creating $FILE..."
                ogr2ogr \
                -f 'ESRI Shapefile' \
                -t_srs $TSRS \
                $FILE $SRC
    fi
done
