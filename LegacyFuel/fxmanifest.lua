fx_version 'bodacious'
game 'gta5'

author 'InZidiuZ'
description 'Legacy Fuel'
version '1.3'

shared_script 'config.lua'

files {
    "source/digital-counter-7.ttf",
	"source/index.html"
}
ui_page "source/index.html"

client_scripts {
	'config.lua',
	'source/fuel_client.lua'
}

server_scripts {
	'config.lua',
	'source/fuel_server.lua'
}

exports {
	'GetFuel',
	'SetFuel'
}

lua54 'yes'