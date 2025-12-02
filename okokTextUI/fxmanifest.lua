fx_version 'adamant'

game 'gta5'

author 'okok' -- Discord: okok#3488
description 'okokTextUI'
version '1.0'

ui_page 'web/ui.html'

client_scripts {
	'client.lua',
}
server_scripts {
	'server.lua'
}

files {
	'web/*.*'
}

export 'Open'
export 'Close'