/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS202: Simplify dynamic range loops
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */

import { log } from "../log";

// hard coded until I load them from google spreadsheet
const languages = {
  en: {
    your_turn_title: 'Your Turn',
    your_turn_message: 'It\'s your turn to play against {1}, play now!',
    invitation_received_title: 'Let\s Play',
    invitation_received_message: 'New invitation received from {1}',
    game_over_title: 'Game Finished',
    game_over_message: 'Your game against {1} is finished, check it out!',
    opponent_has_left_title: 'Game Ended',
    opponent_has_left_message: '{1} has resigned from the game.',
    new_message_title: '{1}',
    new_message_message: '{1}'
  },
  fr: {
    your_turn_title: 'Votre Tour',
    your_turn_message: 'C\'est à votre tour de jouer contre {1}, ' +
      'jouez maintenant !',
    invitation_received_title: 'Envie de jouer contre moi ?',
    invitation_received_message: 'Invitation reçue de la part de {1}',
    game_over_title: 'Fin de partie',
    game_over_message: 'Votre partie contre {1} est finie. Voir résultat !',
    opponent_has_left_title: 'Partie Terminée',
    opponent_has_left_message: '{1} a abandonné la partie.',
    new_message_title: '{1}',
    new_message_message: '{1}'
  },
  nl: {
    your_turn_title: 'Jouw beurt',
    your_turn_message: 'Het is jouw beurt om te spelen tegen {1}, speel nu!',
    invitation_received_title: 'Uitnodiging',
    invitation_received_message: 'Nieuwe uitnodiging ontvangen van {1}',
    game_over_title: 'Spel Afgelopen',
    game_over_message: 'Je spel met {1} is afgelopen, bekijk het!',
    opponent_has_left_title: 'Spel afgelopen',
    opponent_has_left_message: '{1} geeft het spel op.',
    new_message_title: '{1}',
    new_message_message: '{1}'
  }
};

class Translator {
  // constructor: () ->

  // "dataTypes": [
  //   "string",
  //   "directory:name"
  // ],
  // "data": [
  //   "new_message_message",
  //   "yo",
  //   "nipe755"
  // ],
  translate(locale:string, data:Array<string>, argsType:Array<string>, callback:(tr:string)=>void): void {
    log.debug({ locale, data }, 'translate');
    // TODO: fetch usernames from directory and show the display name
    if (!data || data.length === 0) {
      return callback('');
    }
    let strings = languages[locale];
    if (!strings) {
      strings = languages['en'];
    }
    let ret = strings[data[0]] || languages['en'][data[0]];
    if (!ret) {
      return callback('');
    }
    for (let index = 1, end = data.length - 1, asc = 1 <= end; asc ? index <= end : index >= end; asc ? index++ : index--) {
      // type = argsType[index - 1]
      // if type == 'directory:name'
      //   # translate it
      ret = ret.replace(`{${index}}`, data[index]);
    }
    callback(ret);
  }
}

export default Translator;

// Example notification data:
//    notification: {
//   "from": "chat/v1",
//   "to": "kago042",
//   "type": "message",
//   "data": {
//     "roomId": "triominos/v1/kago042/nipe755",
//     "from": "nipe755",
//     "timestamp": "1587367081025",
//     "type": "triominos/v1",
//     "message": "yo"
//   },
//   "push": {
//     "titleArgsTypes": [
//       "directory:name"
//     ],
//     "messageArgsTypes": [
//       "string",
//       "directory:name"
//     ],
//     "message": [
//       "new_message_message",
//       "yo",
//       "nipe755"
//     ],
//     "app": "triominos/v1",
//     "title": [
//       "new_message_title",
//       "nipe755"
//     ]
//   },
//   "timestamp": 1587367081519,
//   "id": 1132529133
// }
