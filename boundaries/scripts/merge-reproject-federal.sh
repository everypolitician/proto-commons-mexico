#!/bin/bash
# To call the script open the terminal in the same folder as the script
# Ensure it is executable: $ chmod u+x merge-reproject.sh
# Call it with the layer you wish to combine: eg. $ merge-reproject.sh ENTIDAD
# LAYERS are 'SECCION' 'ENTIDAD' and 'DISTRITO'

LYR=$1


#SET TO PATH WHERE YOU WANT THE SHP TO BE CREATED
FILE="../source/${LYR}-wgs84.shp" # name of file to be merged to
LAYER="${LYR}-wgs84" # should be the same as
TSRS='EPSG:4326' # target CRS
BASE='/vsizip//vsicurl/http://cartografia.ife.org.mx/descargas/distritacion2017/federal'


for i in {01..32}

do
    if [ $i = 06 ] #Hack because file number 6 is a different structure to the rest
        then
            SRC="$BASE/$i/$i.zip/${LYR}.shp"
        else
            SRC="$BASE/$i/$i.zip/$i/${LYR}.shp"
    fi

    if [ -f "$FILE" ]
        then
                echo "Reprojecting and merging $SRC..."
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
