# Description:
#   What is ZeroCater catering us today?
#
# Dependencies:
#   "cheerio": "0.12.x"
#   "moment": "2.0.x"
#
# Configuration:
#   HUBOT_ZEROCATER_MENU_URL - In the format of https://zerocater.com/m/xxxx
#   HUBOT_ZEROCATER_CATERING_TIME - In the format of HH:MM
#
# Commands:
#   hubot zerocater
#   hubot what's for lunch - Pulls your catering menu for today
#
#   hubot zerocater yesterday
#   hubot what's for lunch yesterday - Yesterday's catering menu
#
#   hubot zerocater tomorrow
#   hubot what's for lunch tomorrow - Tomorrow's catering menu
#
# Author:
#   jonursenbach

moment = require 'moment'
cheerio = require 'cheerio'

module.exports = (robot) =>
  robot.respond /(zerocater|what['’]?s for lunch)( .*)?/i, (msg) ->
    date = msg.match[0].trim().split(" ")
    date = date[date.length-1]
    date = if /(today|tomorrow|yesterday)/i.test(date) then date else undefined
    if date isnt undefined && date != ''
      date = getTimestamp(date)
      if date is false
        getCatering msg, false
      else
        getCatering msg, date
    else
      getCatering msg, moment()

getTimestamp = (date) ->
  if !isNaN(new Date(date).getTime())
    return moment(date)

  if /(yesterday|today|tomorrow)/i.test(date)
    switch date
      when 'yesterday'
        return moment().subtract('d', 1)
      when 'today'
        return moment()
      when 'tomorrow'
        return moment().add('d', 1)
  else
    return false

getCatering = (msg, date) ->
  if date is false
    return msg.send 'I don\'t know when that is.'

  return msg.send "You need to set env.HUBOT_FORECAST_API_KEY to get weather data" if not process.env.HUBOT_ZEROCATER_MENU_URL

  msg.http(process.env.HUBOT_ZEROCATER_MENU_URL)
    .get() (err, res, body) ->
      return msg.send "Sorry, Zero Cater doesn't like you. ERROR:#{err}" if err
      return msg.send "Unable to get a catering menu: #{res.statusCode + ':\n' + body}" if res.statusCode != 200

      $ = cheerio.load(body)

      cateringFound = false;
      searchDate = date.format('YYYY-MM-DD');

      $('div.menu[data-date="' + searchDate + '"]').each (i, elem) ->
        if (cateringFound)
          return

        menu = $(this)
        header = menu.find('.meal-header')
        time = menu.find('.header-time').text().split('\n').filter (i, elem) ->
          return !!i.trim();

        deliveryTime = time[1].trim()

        # It seems that ZeroCater sometimes only has one delivery on some days,
        # so if there's only one entry for this date, we can ignore trying to
        # match against the specified catering time.
        if $('div.menu[data-date="' + searchDate + '"]').length > 1
          if deliveryTime.match(process.env.HUBOT_ZEROCATER_CATERING_TIME, 'g') == null
            return

        cateringFound = true

        emit = 'Catering for ' + searchDate + ' at ' + deliveryTime + ' is coming from ' + header.find('.vendor').text().trim().split('\n')[0] + '.\n\n'
        menu.find('.list-group-item').each (i, elem) ->
          item = $(this).find('.item-name').text().trim().replace(/(\r\n|\n|\r)/gm,"")
          description = $(this).find('.item-description').text().trim().replace(/(\r\n|\n|\r)/gm,"")
          instructions = $(this).find('.item-instructions').text().trim().replace(/(\r\n|\n|\r)/gm,"")

          emit += item + '\n'
          if (description != '')
            emit += ' - ' + description + '\n'

          if (instructions != '')
            emit += ' - Note: ' + instructions + '\n'

        msg.send emit

      if (!cateringFound)
        msg.send "Sorry, I was unable to find a menu for #{searchDate}."
