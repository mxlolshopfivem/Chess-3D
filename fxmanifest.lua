fx_version 'cerulean'
game 'gta5'

author 'Emixiss Shop'
description 'Emixiss Shop - Chess 3D'
version '1.0'

shared_script 'config.lua'

server_scripts {
    'server/chess.lua',
    'server/ai.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html'
}
