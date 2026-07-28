# CouchDB for Obsidian Sync
Create an Unraid compatible Docker image for backing up Obsidian locally.

## Credit
I didn't really like any of the existing Unraid Community Applications for Obsidian backup so I started searching for a different solution. I found this site [Self-Host Obsidian Sync in 10 Minutes with Docker](https://www.joshuapack.com/self-host-obsidian-sync-in-10-minutes-with-docker/). And decided to give it a shot. Just using it as a starting point. 

## Issues

### Configuration Files

The files in the config folder are all the configuration files being used. Each one is copied and renamed so they execute in the proper order. Note from CouchDB about configuration file loading: [CouchDB Guide - Configuration Files](https://docs.couchdb.org/en/stable/config/intro.html#configuration-files)

- ```/config/local.ini /opt/couchdb/etc/local.d/a_local.ini```
- ```/config/peruser.ini /opt/couchdb/etc/local.d/b_local.ini```

Special note about the 'peruser.ini'. This configuration is only copied into the proper folder (local.d) after the initial reboot. This configuration file enables the feature Database per User when the environment variable COUCHDB_PERUSER is 'true'. This configuration can't be used until after the initial boot of CouchDB. After the initial boot we shutdown CouchDB then copy the file to the proper folder and start CouchDB.

You will see this error message in the logs if for some reason the original /config/local.ini file is missing: Our local.ini file is missing! Open a ticket but you may want to see if the file can be restored from the source.

#### Adding Your Config

Create your own files but the file name must start with the letter 'c' or higher because the last processed configuration file (based on load rules from CouchDB site) will override any previous file settings.

## License
See the LICENSE file.