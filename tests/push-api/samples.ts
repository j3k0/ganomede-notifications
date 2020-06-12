import {TokenDef} from '../../src/push-api/token';
import {Notification} from '../../src/types';

export default {
  tokenData: function(type?, value?): TokenDef {
    if (type == null) { type = 'apn'; }
    if (value == null) { value = 'alicesubstracttoken'; }
    return {
      username: 'alice',
      app: 'substract-game/v1',
      type,
      value
    };
  },
  notification: function(push?, reciever?): Notification {
    if (push == null) {
      push = {
        title: ['your_turn_title'],
        message: ['your_turn_title']
      };
    }
    if (reciever == null) { reciever = 'alice'; }
    const ret = {
      from: 'substract-game/v1',
      to: reciever,
      type: 'invitation-created',
      data: {},
      push,
      timestamp: +new Date(),
      id: 1
    };

    ret.push.app = ret.push.app || ret.from;
    return ret;
  }
};
