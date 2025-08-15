fx_version 'cerulean'
game 'gta5'

author 'Cold-Dev-Team'
description 'Cold-Gangs - Comprehensive Gang Management System'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/img/*.png',
    'html/img/*.jpg'
}

lua54 'yes'
