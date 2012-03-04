Sequelize = require 'sequelize'

# populate some 'seed data'
module.exports.populate = (models, cb) ->
  chainer = new Sequelize.Utils.QueryChainer

  vnc_kegerator = models.Kegerator.build({
    access_key: 1111,
    name: 'VNC Seattle'
    description: 'The original home of keg.io',
    created_date: '2011-03-12T01:23:45Z',
    owner_email: 'chris.castle@vivaki.com'
  })

  mannys = models.Keg.build({
    kegerator_id: 1111,
    beer: "Mannys",
    brewery: 'Georgetown Brewery',
    beer_style: 'Pale Ale',
    description: 'A solid pale ale, brewed in Seattle least-douchey neighborhood.',
    tapped_date: '2011-03-12T01:23:45Z',
    volume_gallons: '15.5',
    active: 'false',
    image_path: 'images/MannysPint3.gif'
  })

  dc = models.User.build({
    rfid: '44004C234A',
    first_name: 'Dylan',
    last_name: 'Carney',
    nickname: 'Beardo',
    email: 'dcarney@gmail.com',
    twitter_handle:  '@_dcarney_'
  })

  crc = models.User.build({
    rfid: '44004C3A1A',
    first_name: 'Chris',
    last_name: 'Castle',
    nickname: '',
    email: 'crcastle@gmail.com',
    twitter_handle:  '@crc'
  })

  ck = models.User.build({
    rfid: '4400561A0A',
    first_name: 'Carl',
    last_name: 'Krauss',
    nickname: '',
    email: '',
    twitter_handle:  ''
  })

  gp = models.User.build({
    rfid: '440055F873',
    first_name: 'Garrett',
    last_name: 'Patterson',
    nickname: '',
    email: 'garrett.patterson@vivaki.com',
    twitter_handle:  '@thegarrettp'
  })

  pour1 = models.Pour.build({
    rfid: dc.rfid
    keg_id: 1
    pour_date: '2011-03-19T16:34:17Z'
    volume_ounces: 16
  })

  pour2 = models.Pour.build({
    rfid: crc.rfid
    keg_id: 1
    pour_date: '2011-03-19T16:44:17Z'
    volume_ounces: 32
    })

  temp1 = models.Temperature.build({
    temperature: 36
    kegerator_id: 1111
    })

  temp2 = models.Temperature.build({
    temperature: 39
    kegerator_id: 1111
    })

  welcome = models.Coaster.build({
    name: 'Welcome'
    description: 'Pour a beer with keg.io!'
    image_path: 'images/coasters/firstbeer.png'
    })

  early_bird = models.Coaster.build({
    name: 'Early Bird'
    description: 'Pour a beer before noon.'
    image_path: 'images/coasters/earlybird.png'
    })

  chainer.add(mannys.save())
         .add(vnc_kegerator.save())
         .add(dc.save())
         .add(crc.save())
         .add(ck.save())
         .add(gp.save())
         .add(pour1.save())
         .add(pour2.save())
         .add(temp1.save())
         .add(temp2.save())
         .add(welcome.save())
         .add(early_bird.save())

  chainer.run()
    .success () ->
      cb()
    .error (error) ->
      cb(error)