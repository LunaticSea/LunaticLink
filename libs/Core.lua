-- Classes
local Cache = require('utils/Cache')
local NodeManager = require('manager/NodeManager')
local PlayerManager = require('manager/PlayerManager')
local Emitter = require('utils/Emitter')

-- Drivers
local LavalinkFour = require('drivers/LavalinkFour')

-- Props
local class = require('class')
local enums = require('enums')
local SourceIDs = require('const').SourceIDs
local manifest = require('manifest')
local merge_default = require('utils/MergeDefault')

--- The heart of Lunalink. Manage all package action
--- @class Core: Emitter
--- <!tag:interface>
--- @field library AbstractLibrary Discord library connector
--- @field nodes NodeManager Lavalink server that has been configured
--- @field options LunalinkOptions Lunalink options, see get:default_options
--- @field id string Bot id
--- @field players PlayerManager All currently running players
--- @field searchEngine Cache All search engines
--- @field searchPlugins Cache All search plugins (resolver plugins)
--- @field plugins Cache All plugins (include resolver plugins)
--- @field drivers AbstractDriver All avaliable lunalink drivers
--- @field shardCount number The current bott's shard count
--- @field voices Cache All voice handler currently
--- @field default_options LunalinkConfig the default configurations

local Lunalink, get, set = class('Lunalink', Emitter)

--- @param options LunalinkOptions
function Lunalink:__init(options)
	Emitter.__init(self)
  assert(options, 'Please include options to run this library')
	assert(options.library, 'Please set an new lib to connect, example: \nlibrary = lunalink.library.dia(client) ')
	self._drivers = { LavalinkFour }
  self._library = options.library:set(self)
  self._options = options
	self._options.config = merge_default(self._options.config, self.default_options)
	if (
		self._options.config.additionalDriver and
		#self._options.config.additionalDriver ~= 0
	) then
		for _, value in pairs(self._options.config.additionalDriver) do
			table.insert(self._drivers, value)
		end
	end
	-- Node manager
	self._nodes = NodeManager()
	-- Player manager
	self._players = PlayerManager()
  self._id = nil
  self._searchEngines = Cache()
  self._searchPlugins = Cache()
  self._plugins = Cache()
  self._shardCount = 1
  self.voices = Cache()
  self._manifest = manifest
	self:_initialSearchEngines()
	if (
		not self._options.config.defaultSearchEngine or
		self._options.config.defaultSearchEngine.length == 0
	) then
		self._options.config.defaultSearchEngine = 'youtube'
	end

	if self._options.plugins then
		for _, target_plugin in pairs(self._options.plugins) do
			local plugin = target_plugin()
			assert(plugin.isLunalinkPlugin, 'Plugin must be an instance of Plugin or SourcePlugin')
			plugin:load(self)

			self.plugins:set(plugin.name(), plugin)

			if plugin.type == enums.PluginType.SourceResolver then
				local source_name = plugin.sourceName
				local source_identify = plugin.sourceIdentify
				self._searchEngines:set(source_name, source_identify)
				self._searchPlugins.set(source_name, plugin)
			end
		end
	end
	self._library:listen(self._options.nodes)
end

function get:library()
  return self._library
end

function get:nodes()
  return self._nodes
end

function get:options()
  return self._options
end

function get:id()
  return self._id
end

function get:players()
  return self._players
end

function get:search_engines()
  return self._searchEngines
end

function get:searchPlugins()
  return self._searchPlugins
end

function get:plugins()
  return self._plugins
end

function get:drivers()
  return self._drivers
end

function get:shardCount()
  return self._shardCount
end

function get:voices()
  return self._voices
end

function get:manifest()
  return self._manifest
end

--- Create a new player.
--- @param options VoiceChannelOptions Options for creating player
--- @return Player
function Lunalink:create(options)
	return self._players:create(options)
end

--- Destroy a specific player.
--- @param guild_id string Target guild id
--- @return nil
function Lunalink:destroy(guild_id)
	self._players:destroy(guild_id)
end

--- Search a specific track.
--- @param query string Target guild id
--- @param options SearchOptions Some options when search
--- @return nil
function Lunalink:search(query, options)
	-- Will do later
end

function Lunalink:_initialSearchEngines()
	for _, data in pairs(SourceIDs) do
		self._searchEngines:set(data.name, data.id)
	end
end

function get:default_options()
  local user_agent = 'Discord/Bot/%s/%s (%s)'
  return {
		additionalDriver = {},
		retryTimeout = 3000,
		retryCount = 15,
		voiceConnectionTimeout = 15000,
		defaultSearchEngine = 'youtube',
		defaultVolume = 100,
		searchFallback = {
			enable = true,
			engine = 'soundcloud',
		},
		resume = false,
		userAgent = string.format(user_agent, manifest.name, manifest.version, manifest.github),
		nodeResolver = nil,
		structures = {
			player = nil,
			rest = nil,
			queue = nil,
			filter = nil,
		},
		resumeTimeout = 300,
	}
end

function set:id(data)
	self._id = data
end

return Lunalink