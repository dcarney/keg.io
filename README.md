# keg.io

## (Initial) Setup:

- This assumes you've already installed a working copy of node.js, that is relatively recent (>= v0.6), along with npm, the node.js package manager.  See the [node js site](http://nodejs.org/) for more info on installing node.js and npm.

- Get the code and install all deps:

        # git clone https://github.com/vnc/keg.io.git
	    # cd keg.io
	    # npm install

- Copy the sample config and key files, and set any necessary configuration options in the resulting files.
  The keys.json file contains a mapping of all the access and secret keys for authorized kegerator clients.
  This file should not be checked in, or made publicly accessible in any way.

        # cp conf/configuration-sample.json conf/configuration.json
	# vi conf/configuration.json
        # cp conf/keys-sample.json conf/keys.json
        # vi conf/keys.json

- Create an initial database for keg.io to use.  (This same command can be used for to rebuild the database at any time in the future)

		# keg.rebuild -f conf/configuration.json

## Running:
- Run the node server:

		# npm start
	**OR**

		# keg.io -f conf/configuration.json
  (Depending on the port/HW/OS you're running on, you may need sudo privs to get node to open the configured port)

- Connect a client UI by opening a browser and navigating to the proper IP/port, per the server's config.

## Misc. Info:
- Docco HTML documentation for the 'important' keg.io code can be found in the docs/ directory.
