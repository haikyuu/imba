const utils = require './utils'
import np from 'path'
import nfs from 'fs'
import os from 'os'

import crypto from 'crypto'

const hashedKeyCache = {

}

const keyPathCache  = {
	
}

export default class Cache
	def constructor options
		#key = Symbol!
		o = options
		dir = o.cachedir # or np.resolve(program.cwd,'.cache') # file.absdir # np.dirname()
		aliaspath = np.resolve(dir,'.imba-aliases')
		aliasmap = ""
		aliascache = {}

		data = {
			aliases: {}
			cache: {}
		}

		mintime = o.mtime or 0
		idFaucet = utils.idGenerator!
		preload!

	def preload
		unless nfs.existsSync(dir)
			nfs.mkdirSync(dir)

		let entries = nfs.readdirSync(dir)
		for entry in entries
			cache[entry] = {exists: 1}

		unless nfs.existsSync(aliaspath)
			nfs.appendFileSync(aliaspath,"")

		refreshAliasMap!
		self

	def setup
		yes

	def save
		self

	def deserialize
		self

	def serialize
		self

	get cache
		data.cache ||= {}

	get aliases
		data.aliases ||= {}

	def alias src
		unless aliases[src]
			let nr = Object.keys(aliases).length
			aliases[src] = idFaucet(nr) + "0"

		return aliases[src]

	def normalizeKey key
		if hashedKeyCache[key]
			return hashedKeyCache[key]

		let hash = crypto.createHash('sha1')
		hash.update(key)
		hashedKeyCache[key] = hash.digest('hex') # '_' + hash.digest('hex').slice(0,-1)

	def fullKeyPath key
		keyPathCache[key] ||= np.resolve(dir,key)

	def getKeyTime key
		let cached = cache[key]

		if cached and cached.time
			return cached.time

		if cached and cached.exists
			let path = fullKeyPath(key)
			nfs.statSync(path).mtimeMs
		else
			0

	def refreshAliasMap
		aliasmap = nfs.readFileSync(aliaspath,'utf8').split(/\r?\n/)

	def getPathAlias path
		getKeyAlias(path)

	def getKeyAlias key
		if aliascache[key]
			return aliascache[key]
		# should be a standard length
		# let exists = nfs.existsSync(aliaspath)
		# let stat = nfs.statSync(aliaspath)
		let index = aliasmap.indexOf(key)

		if index == -1
			# append to the aliasmap now
			# we need to read to get the new index since
			# another process might have written to the
			# same path at the same time
			# if we read stats before and stats after - we can know for sure
			nfs.appendFileSync(aliaspath,key + '\n','utf8')
			refreshAliasMap!
			index = aliasmap.indexOf(key)

		if index >= 0
			# unless index % 40 == 0
			#	console.log "key not correctly aligned in file",index,key
			#	throw "error"
			return aliascache[key] = idFaucet(index) # idFaucet(index / 40)
		else
			console.log "key not added?",key,aliasmap
			throw "could not add key to aliasmap"
			# ,key,aliasmap


	def getKeyValue key
		let path = fullKeyPath(key)
		let val = await nfs.promises.readFile(path,'utf8')
		JSON.parse(val)

	def setKeyValue key, value
		let path = fullKeyPath(key)
		let json = JSON.stringify(value)
		nfs.promises.writeFile(path,json)


	def memo name, time, cb
		let key = normalizeKey(name)
		time = mintime if mintime > time

		let cached = cache[key]

		if cached and cached.time >= time
			return cached.promise

		let keytime = getKeyTime(key)

		# check for file on disk
		# let file = program.fs.lookup(np.resolve(dir,key))
		# let mtime = file.mtimesync
		# console.log 'memo',dir,key,keytime,cached && cached.exists
	
		if keytime > time
			cached = cache[key] = {
				time: Date.now!
				promise: getKeyValue(key)
			}
		else
			cached = cache[key] = {
				time: Date.now!
				promise: cb!
			}

			cached.promise.then do(val) setKeyValue(key,val)

		return cached.promise