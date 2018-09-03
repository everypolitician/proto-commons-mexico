#!/bin/bash

# To call the script open the terminal in the same folder as the script
# Ensure it is executable: $ chmod u+x merge-reproject.sh
# Call it with $ ./merge-distrito-local-reproject.sh

# SET TO PATH WHERE YOU WANT THE SHP TO BE CREATED
FILE='../source/MUNICIPALITIES-wgs1984.shp' # name of file to be merged to
LAYER='MUNICIPALITIES-wgs1984' # should be the same as
TSRS='EPSG:4326' # target CRS
BASE='../source/municipalities'


for ZIP_DIR in $BASE/*

do
    if [[ ${ZIP_DIR:25:2} = '08' ]] || [[ ${ZIP_DIR:25:2} = '27' ]] #Hack because file number 08 and 27 is a different structure to the rest
        then
            SRC="/vsizip/${ZIP_DIR}/conjunto_de_datos/${ZIP_DIR:25:2}mun.shp"
        else
            SRC="/vsizip/${ZIP_DIR}/conjunto de datos/${ZIP_DIR:25:2}mun.shp"
    fi

    # SRC="/vsizip/${ZIP_DIR}/conjunto de datos${ZIP_DIR:24:3}mun.shp"

    if [ -f "$FILE" ]
        then
                echo "transforming and merging ${SRC}..."
                ogr2ogr \
                -f 'ESRI Shapefile' \
                -t_srs $TSRS \
                -update -append $FILE "${SRC}" \
                -nln $LAYER
        else
                echo "creating $FILE..."
                ogr2ogr \
                -f 'ESRI Shapefile' \
                -t_srs $TSRS \
                $FILE "${SRC}" \
                -lco ENCODING=utf-8
    fi
done
