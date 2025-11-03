fx_version 'cerulean'
game 'gta5'

author 'Cold-Dev-Team'
description 'Cold-Gangs - Comprehensive Gang Management System'
version '1.0.0'

shared_scripts {
  '@qb-core/shared/locale.lua',

  'config/config.lua',
  'config/businesses.lua',
  'config/drugs.lua',
  'config/gangs.lua',
  'config/graffiti.lua',
  'config/heists.lua',
  'config/labs.lua',
  'config/mapzones.lua',
  'config/wars.lua',
}

client_scripts {
  '@PolyZone/client.lua',
  '@PolyZone/BoxZone.lua',
  '@PolyZone/EntityZone.lua',
  '@PolyZone/CircleZone.lua',
  '@PolyZone/ComboZone.lua',
  'client/utils.lua',
  'client/ui.lua',
  'client/main.lua',
  'client/modules/members.lua',
  'client/modules/territories.lua',
  'client/modules/heists.lua',
  'client/modules/wars.lua',
  'client/modules/labs.lua',
  'client/modules/labraids.lua',
  'client/modules/graffiti.lua',
  'client/modules/drugs.lua',
  'client/modules/businesses.lua',
  'client/modules/stashes.lua',
  'client/modules/vehicles.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/core/init.lua',
  'server/core/ratelimit.lua',
  'server/core/validation.lua',
  'server/core/permissions.lua',
  'server/core/db.lua',
  'server/core/api.lua',
  'server/core/compat.lua',
  'server/modules/members.lua',
  'server/modules/territories.lua',
  'server/modules/heists.lua',
  'server/modules/wars.lua',
  'server/modules/admin.lua',
  'server/modules/labs.lua',
  'server/modules/graffiti.lua',
  'server/modules/businesses.lua',
  'server/modules/economy.lua',
  'server/modules/stashes.lua',
  'server/modules/vehicles.lua',
}

ui_page 'html/index.html'

data_file 'DLC_ITYP_REQUEST' 'stream/gang_logos.ytyp'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/images/ganglogos/*.png',
    'html/img/*.png',
    'stream/sprayfont*.gfx',
    'stream/graffiti*.gfx'
}

lua54 'yes'

dependency 'qb-core'
dependency 'oxmysql'