#!/bin/bash

# bash implementation of static repository

###############################################################################
# config
###############################################################################

# main location of files
REPO_DIR="$HOME/Downloads/static_repo/tmp/repo"
PUB_DIR="$HOME/Downloads/static_repo/tmp/public"

# derivative generation options
IMG_MGK_OPTS="" # ZZZ maxsize 1024x1024?

# remote metadata endpoints
ALMA_MD_PREFIX="https://catalog.princeton.edu/catalog/"
ALMA_MD_SUFFIX=".jsonld"
ASPACE_MD_PREFIX="https://findingaids.princeton.edu/catalog/"
ASPACE_MD_SUFFIX=".json"

# base url
BASE_URL="http://localhost:4000"


###############################################################################
# variables
###############################################################################
OBJECTS_DIR="$REPO_DIR/objects"
COLLECTIONS_DIR="$REPO_DIR/collections"
ADMIN_SETS_DIR="$REPO_DIR/admin_sets"

DERIV_DIR="$PUB_DIR/deriv"
IIIF_DIR="$PUB_DIR/iiif"
SITEMAP_DIR="$PUB_DIR/sitemap"

MD_FILES="_adm_md.json _desc_md.json _tech_md.json _order.json _struct.json"

STUB_ADM=$( cat << END_ADM
{
  "admin_set":"",
  "collections":[],
  "rights":"https://rightsstatements.org/vocab/CNE/1.0/",
  "remote_metadata_id":"",
  "remote_metadata_type":"none",
  "visibility":"private"
}
END_ADM
)


###############################################################################
# functions
###############################################################################
function obj_dir
{
  PP=$( pair_path "$1" )
  echo "$OBJECTS_DIR/$PP/$1"
}

function deriv_dir
{
  PP=$( pair_path "$1" )
  echo "$DERIV_DIR/$PP/$1"
}

function generate_sitemap
{
  if [ ! -d "$SITEMAP_DIR" ]; then
    mkdir -p "$SITEMAP_DIR"
  fi

  cat << END_INDEX > $SITEMAP_DIR/sitemap.xml
<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/siteindex.xsd" xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>$BASE_URL/objects.xml</loc>
  </sitemap>
</sitemapindex>
END_INDEX

  echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $SITEMAP_DIR/objects.xml
  echo "<urlset xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd\" xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">" >> $SITEMAP_DIR/objects.xml

  for f in `find "$IIIF_DIR" -name *.json`; do
    FN=$( basename $f )
    M1=$( stat -f %m "$f" )
    MT=$( timestamp_to_iso8601 $M1 )
    echo "  <url>" >> $SITEMAP_DIR/objects.xml
    echo "    <loc>$BASE_URL/iiif/$FN</loc>" >> $SITEMAP_DIR/objects.xml
    echo "    <lastmod>$MT</lastmod>" >> $SITEMAP_DIR/objects.xml
    echo "  </url>" >> $SITEMAP_DIR/objects.xml
  done

  echo "</urlset>" >> $SITEMAP_DIR/objects.xml
}

function mint_uuid
{
  UUID=$( uuidgen | tr 'A-Z' 'a-z' )
  echo $UUID
}

function object_derivatives
{
  UUID="$1"
  OBJ_PATH=$( obj_dir $UUID )
  DERIV=$( deriv_dir $UUID )
  for i in $OBJ_PATH/[0-9a-zA-Z]*.*; do
    EXT=$( echo "$i" | sed -e's/.*\.//' )
    FN=$( basename $i .$EXT )
    if [ "$EXT" = "tif" ]; then
      convert -v $IMG_MGK_OPTS $i $DERIV/$FN.jpg
    fi
  done 
}

function pair_path
{
  P1=$( echo "$1" | cut -c1-2 )
  P2=$( echo "$1" | cut -c3-4 )
  echo "$P1/$P2"
}

function remote_metadata_type
{
  ID="$1"
  ASPACE=$( echo "$ID" | grep "^[AC\|MC\|C]" | grep -c "_c" )
  if [ "$ASPACE" = "1" ]; then
    echo aspace
  else
    LEN=$( echo "$ID" | wc -c )
    START=$( echo "$ID" | cut -c1-2 )
    if [ $LEN -gt 9 -a "$START" = "99" ]; then
      echo alma
    else
      echo none
    fi
  fi
}

function update_remote_metadata
{
  UUID="$1"
  TYPE="$2"
  ID="$3"
  OBJ_DIR=$( obj_dir "$UUID" )
  DESC_MD_FILE="$OBJ_DIR/_desc_md.json"
  if [ "$TYPE" = "alma" ]; then
    curl "${ALMA_MD_PREFIX}${ID}${ALMA_MD_SUFFIX}" > "$DESC_MD_FILE"
  elif [ "$TYPE" = "aspace" ]; then
    curl "${ASPACE_MD_PREFIX}${ID}${ASPACE_MD_SUFFIX}"> "$DESC_MD_FILE"
  else
    echo "error"
    # ZZZ error
  fi
}

function timestamp_to_iso8601
{
  date -j -f "%s" +"%Y-%m-%dT%T%z" $1
}

function update_order
{
  UUID="$1"
  OBJ_DIR=$( obj_dir $UUID )
  ORD="$OBJ_DIR/_order.json"

  echo '{"files":[' > $ORD
  P=1
  for i in $OBJ_DIR/[0-9a-zA-Z]*.*; do
    if [ "$P" -gt "1" ]; then
      echo "," >> $ORD
    fi
    FN=$( basename $i )
    echo -n "{\"filename\":\"$FN\",\"label\":\"$P\"}" >> $ORD
    P=$(( $P + 1 ))
  done
  echo "" >> $ORD
  echo ']}' >> $ORD
}

function update_struct
{
  UUID="$1"
  OBJ_DIR=$( obj_dir $UUID )
  STR="$OBJ_DIR/_struct.json"

  echo '{"label":"top","nodes":[' > $STR
  P=1
  for i in $OBJ_DIR/[0-9a-zA-Z]*.*; do
    if [ "$P" -gt "1" ]; then
      echo "," >> $STR
    fi
    FN=$( basename $i )
    echo -n "{\"proxy:\":\"$FN\"}" >> $STR
    P=$(( $P + 1 ))
  done
  echo "" >> $STR
  echo ']}' >> $STR
}

function update_tech_md
{
  UUID="$1"
  OBJ_DIR=$( obj_dir $UUID )
  TMD="$OBJ_DIR/_tech_md.json"

  OC1=$( stat -f %B "$OBJ_DIR" )
  OCT=$( timestamp_to_iso8601 $OC1 )
  OM1=$( stat -f %m "$OBJ_DIR"/* | sort | tail -1 )
  OMT=$( timestamp_to_iso8601 $OM1 )

  echo "{" > $TMD
  echo "  \"created\":\"$OCT\"," >> $TMD
  echo "  \"modified\":\"$OMT\"," >> $TMD
  echo "  \"files\":[" >> $TMD
  for i in $OBJ_DIR/[0-9a-zA-Z]*.*; do
    if [ "$FIRST" = "1" ]; then
      echo "," >> $TMD
    else
      FIRST=1
    fi
    FN=$( basename $i )
    C1=$( stat -f %B $i )
    CT=$( timestamp_to_iso8601 $C1 )
    M1=$( stat -f %m $i )
    MT=$( timestamp_to_iso8601 $M1 )
    SZ=$( stat -f %z $i )
    MD5=$( md5 -q $i )
    SHA=$( sha256 -q $i )
    echo -n "    {\"filename\":\"$FN\",\"created\":\"$CT\",\"modified\":\"$MT\",\"size\":\"$SZ\",\"md5\":\"$MD5\",\"sha256\":\"$SHA\"}" >> $TMD
  done
  echo "" >> $TMD
  echo ']}' >> $TMD
}

function validate_object
{
  UUID="$1"
  echo "validating $UUID"
  OBJ_DIR=$( obj_dir $UUID )
  TMD="$OBJ_DIR/_tech_md.json"
  ERR=0
  for i in $OBJ_DIR/[0-9a-zA-Z]*.*; do
    FN=$( basename $i )
    echo "  $FN"
    C1=$( stat -f %B $i )
    CT=$( timestamp_to_iso8601 $C1 )
    TMD_CT=$( jq -r ".files[] | select(.filename == \"$FN\").created" $TMD )
    if [ "$CT" != "$TMD_CT" ]; then
      echo "    created mismatch: $CT <> $TMD_CT"
      ERR=$(( $ERR + 1 ))
    fi

    M1=$( stat -f %m $i )
    MT=$( timestamp_to_iso8601 $M1 )
    TMD_MT=$( jq -r ".files[] | select(.filename == \"$FN\").modified" $TMD )
    if [ "$MT" != "$TMD_MT" ]; then
      echo "    modified mismatch: $MT <> $TMD_MT"
      ERR=$(( $ERR + 1 ))
    fi

    SZ=$( stat -f %z $i )
    TMD_SZ=$( jq -r ".files[] | select(.filename == \"$FN\").size" $TMD )
    if [ "$SZ" != "$TMD_SZ" ]; then
      echo "    size mismatch: $SZ <> $TMD_SZ"
      ERR=$(( $ERR + 1 ))
    fi

    MD5=$( md5 -q $i )
    TMD_MD5=$( jq -r ".files[] | select(.filename == \"$FN\").md5" $TMD )
    if [ "$MD5" != "$TMD_MD5" ]; then
      echo "    md5 mismatch: $MD5 <> $TMD_MD5"
      ERR=$(( $ERR + 1 ))
    fi

    SHA256=$( sha256 -q $i )
    TMD_SHA256=$( jq -r ".files[] | select(.filename == \"$FN\").sha256" $TMD )
    if [ "$SHA256" != "$TMD_SHA256" ]; then
      echo "    sha256 mismatch: $SHA256 <> $TMD_SHA256"
      ERR=$(( $ERR + 1 ))
    fi

    echo "    $ERR errors"

  done
}

###############################################################################
# main
###############################################################################
if [ "$1" = "object:create" ]; then
  SRC_DIR="$2"
  # ZZZ check [dir]
  UUID=$( mint_uuid )
  OBJ_DIR=$( obj_dir "$UUID" )
  mkdir -p "$OBJ_DIR"
  echo "$UUID:"
  for i in $SRC_DIR/[0-9a-zA-Z]*.*; do
    FN=$( basename $i )
    echo " > $FN"
    cp -a $i $OBJ_DIR/
  done
  for f in $MD_FILES; do
    if [ -f "$SRC_DIR/$f" ]; then
      echo " > $f"
      cp -v "$SRC_DIR/$f" "$OBJ_DIR/$f"
    elif [ "$f" = "_adm_md.json" ]; then
      echo " s $f"
      echo "$STUB_ADM" > $OBJ_DIR/_adm_md.json
    elif [ "$f" = "_desc_md.json" ]; then
      DIRNAME=$( basename "$SRC_DIR" )
      ID_TYPE=$( remote_metadata_type "$DIRNAME" )
      if [ "$ID_TYPE" = "alma" -o "$ID_TYPE" = "aspace" ]; then
        echo " r $f"
        update_remote_metadata $UUID $ID_TYPE $DIRNAME
      else
        echo " s $f"
        echo "{\"label\":\"$DIRNAME\"}" > $OBJ_DIR/_desc_md.json
      fi
    elif [ "$f" = "_order.json" ]; then
      echo " s $f"
      update_order "$UUID"
    elif [ "$f" = "_struct.json" ]; then
      echo " s $f"
      update_struct "$UUID"
    elif [ "$f" = "_tech_md.json" ]; then
      echo " s $f"
      update_tech_md "$UUID"
    fi
  done
  # ZZZ error if no files copied? or warn if only md files copied?
  # ZZZ generate deriv
elif [ "$1" = "object:adm_md" ]; then
  UUID="$2"
  JSON="$3"
  OBJ_DIR=$( obj_dir "$UUID" )
  # ZZZ error if no JSON file
  # ZZZ error if no UUID or dir not found
  cp -v "$JSON" "$OBJ_DIR/_adm_md.json"
elif [ "$1" = "object:desc_md" ]; then
  UUID="$2"
  JSON="$3"
  OBJ_DIR=$( obj_dir "$UUID" )
  # ZZZ error if no JSON file
  # ZZZ error if no UUID or dir not found
  cp -v "$JSON" "$OBJ_DIR/_desc_md.json"
elif [ "$1" = "object:tech_md" ]; then
  UUID="$2"
  JSON="$3"
  OBJ_DIR=$( obj_dir "$UUID" )
  # ZZZ error if no JSON file
  # ZZZ error if no UUID or dir not found
  cp -v "$JSON" "$OBJ_DIR/_tech_md.json"
elif [ "$1" = "object:order" ]; then
  UUID="$2"
  JSON="$3"
  OBJ_DIR=$( obj_dir "$UUID" )
  # ZZZ error if no JSON file
  # ZZZ error if no UUID or dir not found
  cp -v "$JSON" "$OBJ_DIR/_order.json"
elif [ "$1" = "object:struct" ]; then
  UUID="$2"
  JSON="$3"
  OBJ_DIR=$( obj_dir "$UUID" )
  # ZZZ error if no JSON file
  # ZZZ error if no UUID or dir not found
  cp -v "$JSON" "$OBJ_DIR/_struct.json"
elif [ "$1" = "object:refresh_remote_md" ]; then
  UUID="$2"
  OBJ_DIR=$( obj_dir "$UUID" )
  ID_TYPE=$( jq -r .remote_metadata_type "$OBJ_DIR/_adm_md.json" )
  if [ "$ID_TYPE" = "alma" -o "$ID_TYPE" = "aspace" ]; then
    ID=$( jq -r .remote_metadata_id "$OBJ_DIR/_adm_md.json" )
    update_remote_metadata $UUID $ID_TYPE $ID
  fi
elif [ "$1" = "object:derivatives" ]; then
  UUID="$2"
  object_derivatives "$UUID"
elif [ "$1" = "object:manifest" ]; then
  # [uuid]
  echo XXX1
elif [ "$1" = "object:validate" ]; then
  UUID="$2"
  validate_object "$UUID"
elif [ "$1" = "admin_set:create" ]; then
  UUID=$( mint_uuid )
  JSON="$2"
  # ZZZ error if no JSON file
  cp -v "$JSON" "$ADMIN_SETS_DIR/$UUID.json"
elif [ "$1" = "admin_set:update" ]; then
  UUID="$2"
  JSON="$3"
  # ZZZ error if no UUID
  # ZZZ error if no JSON file
  cp -v "$JSON" "$ADMIN_SETS_DIR/$UUID.json"
elif [ "$1" = "admin_set:manifest" ]; then
  # [uuid]
  echo XXX3
elif [ "$1" = "collection:create" ]; then
  UUID=$( mint_uuid )
  JSON="$2"
  # ZZZ error if no JSON file
  cp -v "$JSON" "$COLLECTIONS_DIR/$UUID.json"
elif [ "$1" = "collection:update" ]; then
  UUID="$2"
  JSON="$3"
  # ZZZ error if no UUID
  # ZZZ error if no JSON file
  cp -v "$JSON" "$COLLECTIONS_DIR/$UUID.json"
elif [ "$1" = "collection:manifest" ]; then
  # [uuid]
  echo XXX4
elif [ "$1" = "sitemap" ]; then
  generate_sitemap
else
  cat << END_USAGE
error: verb "$1" not found

usage: $0 [verb] [params]

  verbs:
  - object:create [dir]: ingest the specified directory as a new object
  - object:adm_md [uuid] [json]: store json as the given object's _adm_md.json
  - object:desc_md [uuid] [json]: store json as the given object's _desc_md.json
  - object:tech_md [uuid] [json]: store json as the object's _tech_md.json
  - object:order [uuid] [json]: store json as the given objects's _order.json
  - object:struct [uuid] [json]: store json as the given object's _struct.json
  - object:refresh_remote_md [uuid]: update the given object's remote metadata
  - object:derivatives [uuid]: (re)generate derivatives for the given object
  - object:manifest [uuid]: (re)generate the iiif manifest for the object
  - object:validate [uuid]: verify that the object is valid
  - admin_set:create [json]: ingest json as a new admin_set
  - admin_set:update [uuid] [json]: store json as the given admin_set's metadata
  - admin_set:manifest [uuid]: (re)generate the iiif manifest for the collection
  - collection:create [json]: ingest json as a new collection
  - collection:update [uuid] [json]: store json as the given collection's metadata
  - collection:manifest [uuid]: (re)generate the iiif manifest for the collection
  - sitemap: (re) generate sitemaps
END_USAGE
fi
