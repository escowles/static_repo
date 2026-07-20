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

function remote_metaata_type
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

function update_tech_md
{
  UUID="$1"
  OBJ_DIR=$( obj_dir $UUID )
  TMD="$OBJ_DIR/_tech_md.json"

  # ZZZ object metadata here or _adm_md.json?
  echo '["files":[' > $TMD
  for i in $OBJ_DIR/[0-9a-zA-Z]*.*; do
    if [ "$FIRST" = "1" ]; then
      echo "," >> $TMD
    else
      FIRST=1
    fi
    FN=$( basename $i )
    CR=$( stat -f %B $i )
    CT=$( timestap_to_iso8601 $CRE_RAW )
    MR=$( stat -f %m $i )
    MT=$( timestap_to_iso8601 $MOD_RAW )
    SZ=$( stat -f %z $i )
    MD5=$( md5 -q $i )
    SHA=$( sha256 -q $i )
    echo "{\"filename\":\"$FN\",\"created\":\"$CT\",\"modified\":\"$MT\",\"size\":\"$SZ\",\"md5\":\"$MD5\",\"sha256\":\"$SHA\"}" >> $TMD
  done
  echo ']' > $TMD
}


###############################################################################
# main
###############################################################################
if [ "$1" = "object:create" ]; then
  SRC_DIR="$2"
  # ZZZ check [dir]
  UUID=$( uuidgen )
  OBJ_DIR=$( obj_dir "$UUID" )
  mkdir -p "$OBJ_DIR"
  for i in $SRC_DIR/[0-9a-zA-Z]*.*; do
    cp -av $i $OBJ_DIR/
  done
  for f in $MD_FILES; do
    if [ -f "$SRC_DIR/$f" ]; then
      cp -v "$SRC_DIR/$f" "$OBJ_DIR/$f"
    elif [ "$f" = "_desc_md.json" ]; then
      DIRNAME=$( dirname "$SRC_DIR" )
      ID_TYPE=$( remote_metadata_type "$DIRNAME" )
      if [ "$ID_TYPE" = "alma" -o "$ID_TYPE" = "aspace" ]; then
        update_remote_metadata $UUID $ID_TYPE $DIRNAME
      else
        echo "{\"label\":\"$DIRNAME\"}" > $OBJ_DIR/_desc_md.json
      fi
    elif [ "$f" = "_tech_md.json" ]; then
      update_tech_md $UUID
    else
      # ZZZ stub _admin _order _struct
      echo "XXX"
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
  # XXX
elif [ "$1" = "object:validate" ]; then
  # [uuid]
  # XXX
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
  echo XXX
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
  # XXX
  echo XXX
elif [ "$1" = "sitemap" ]; then
  # XXX
  echo XXX
else
  # ZZZ usage
  echo usage
fi
