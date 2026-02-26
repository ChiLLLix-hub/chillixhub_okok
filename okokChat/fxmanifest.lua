fx_version 'adamant'

game 'gta5'

author 'okok#3488'
description 'okokChat'

ui_page 'web/ui.html'

files {
	'web/*.*',
}

dependencies {
	'qb-core',
}

shared_script 'config.lua'

client_scripts {
	'client.lua',
	'ooc.lua',
}

server_scripts {
	'server.lua',
	'commands.lua',
}