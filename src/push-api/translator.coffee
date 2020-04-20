# hard coded until I load them from google spreadsheet
strings =
  new_message_title: '{1}'
  new_message_message: '{1}'
  opponent_has_left_title: 'Game Ended'
  opponent_has_left_message: '{1} has resigned from the game.'
  your_turn_title: 'Your Turn'
  your_turn_message: 'It\'s your turn to play against {1}, play now!'
  invitation_received_title: 'Let\s Play'
  invitation_received_message: 'New invitation received from {1}'
  game_over_title: 'Game Finished'
  game_over_message: 'Your game against {1} is finished, check it out!'

class Translator
  # constructor: () ->

  # "dataTypes": [
  #   "string",
  #   "directory:name"
  # ],
  # "data": [
  #   "new_message_message",
  #   "yo",
  #   "nipe755"
  # ],
  translate: (data, argsType, callback) ->
    # TODO: fetch usernames from directory and show the display name
    if data.length == 0
      return
    ret = strings[data[0]]
    if not ret
      return
    for index in [1..data.length - 1]
      # type = argsType[index - 1]
      # if type == 'directory:name'
      #   # translate it
      ret = ret.replace "{#{index}}", data[index]
    callback ret

module.exports = Translator

# Example notification data:
#    notification: {
#   "from": "chat/v1",
#   "to": "kago042",
#   "type": "message",
#   "data": {
#     "roomId": "triominos/v1/kago042/nipe755",
#     "from": "nipe755",
#     "timestamp": "1587367081025",
#     "type": "triominos/v1",
#     "message": "yo"
#   },
#   "push": {
#     "titleArgsTypes": [
#       "directory:name"
#     ],
#     "messageArgsTypes": [
#       "string",
#       "directory:name"
#     ],
#     "message": [
#       "new_message_message",
#       "yo",
#       "nipe755"
#     ],
#     "app": "triominos/v1",
#     "title": [
#       "new_message_title",
#       "nipe755"
#     ]
#   },
#   "timestamp": 1587367081519,
#   "id": 1132529133
# }
