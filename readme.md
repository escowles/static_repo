# static repository

thought experiment: what is the minimal implementation of a repository to roughly
equal figgy's functionality, but using the filesystem as the primary interface.


## core repository functionality

1. ingest: stage a set of files using standard naming conventions (00000001.tif,
   etc.) packaged in a directory typically named after a source metadata id
   (alma/aspace/ephemera id).
	- mint a uuid for the object, create a directory in primary repository storage,
      and copy the files to the new directory
	- use any metadata files that exist in the directory (_adm_md.json,
      _desc_md.json, _tech_md.json, _order.json, _struct.json)
	- if metadata files are not included, the following happen by default:
		- _adm_md.json: stub defaults
		- _desc_md.json: if the directory name validates as an alma/aspace/ephemera
          id, use it as the source_metadata id and retrieve the remote metadata
		- _tech_md.json: generate file inventory with technical metadata including
          original filenames, size, format, resolution, checksums, etc.
		- _order.json: use original filenames as default labels
		- _struct.json: stub structure
2. derivatives: convert the ingested files into service formats (ptiff, hls chunks,
   etc.) and store them in a separate directory tree, using the object's uuid.
3. manifest: compile the file inventory, order, structure, and remote metadata and
   compile into a iiif manifest. store in a separate directory tree, using the
   object's uuid.
4. collection_manifest: generate a collection manifest for a collection or admin_set,
   and store it with the object manifests.
4. validate: calculate checksums for files and verify they match the checksums stored
   in tech_md, and parse all metadata files and verify they are valid and all
   required properties exist and are valid (title, rights, visibility, admin_set)
5. collections: accept collection info and store as a file in the collections
   directory
6. admin_sets: accept admin_set info and store as a file in the admin_sets directory
7. sitemap: generate sitemaps for all admin_sets, collections, and objects and store
   them in a separate sitemaps directory.


## command line implementation

- object:create [dir]: ingest the specified directory as a new object
- object:adm_md [uuid] [json]: store the json as the given object's _adm_md.json
- object:desc_md [uuid] [json]: store the json as the given object's _desc_md.json
- object:tech_md [uuid] [json]: store the json as the object's _tech_md.json
- object:order [uuid] [json]: store the json as the given objects's _order.json
- object:struct [uuid] [json]: store the json as the given object's _struct.json
- object:refresh_remote_md [uuid]: update the given object's remote metadata
- object:derivatives [uuid]: (re)generate derivatives for the given object
- object:manifest [uuid]: (re)generate the iiif manifest for the object
- object:validate [uuid]: verify that the object is valid
- admin_set:create [name]: create a new admin set with the given name
- admin_set:update [uuid] [json]: store the json as the given admin_set's metadata
- admin_set:manifest [uuid]: (re)generate the iiif manifest for the collection
- collection:create [name]: create a new collection with the given name
- collection:update [uuid] [json]: store the json as the given collection's metadata
- collection:manifest [uuid]: (re)generate the iiif manifest for the collection
- sitemap: (re) generate sitemaps


## filesystem layout

```
/repo
	admin_sets:
		[uuid].json
	collections:
		[uuid].json
	objects:
		(pairtree)/[uuid]:
			_adm_md.json: admin metadata (rights, visibility, collections, admin_set)
			_desc_md.json: descriptive metadata (from alma/aspace, or from md_editor)
			_tech_md.json: file inventory and technical metadata
			_order.json: file order and labels
			_struct.json: structure/table of contents
			_[timestamp].json: compiled iiif manifest
			_[timestamp].pdf: compiled pdf access file
			_audit.log: events (ingest, edit, validation), each line is a json object
			00000001.tif
/public:
	deriv:
		(pairtree)/[uuid]:
			00000001.ptiff
	iiif:
		admin_set/[uuid].json
		collection/[uuid].json
		object/(pairtree)/[uuid].json
	site_map:
		sitemap.xml
		admin_sets.xml
		collections.xml
		objects.xml
```

## webapp:
here are the tasks that a separate webapp would need to provide to provide
interactive functionality currently in figgy:

- ingest: display a set of directories staged for ingest and allow selecting and
  ingesting them
- md_edit: edit a dublin-core metadata record, using controlled vocabs from
  vocab_editor, to catalog ephemera or other items not cataloged in alma/aspace.
- vocab_edit: create vocabs and terms for use in md_editor
- struct_edit: port the figgy javascript and store the data as a file
- order_edit: port the figgy javascriptn and store the data as a file
- admin_set_edit: port the figgy scanned resource edit view and store the data as
  _adm_md.json
- col_edit: port the figgy collection edit view and store the data as a directory of
  files

## motivation
here are some hypotheses that i have for thinking about this approach:

1. secure: strictly limiting the access to the webapp to PUL staff would dramatically
   reduce the attack surface of the repository.
2. efficient: having all end-user content served statically would reduce the carbon
   footprint of providing the service.
3. robust: current infrastructure used to respond to user requests (e.g., for 
   manifests) can easily be overwhelmed by high amounts of traffic by bots. if all
   of our end-user-visible content is static, it would be much more robust. in
   particular, only the simplest and most-easily-replicated part of our
   infrastructure (static file serving) would be needed for end users.
