import {Notification} from '../../src/types';

export default {
  notification(secret?, reciever?, pushObj?):Partial<Notification> {
    if (reciever == null) { reciever = 'bob'; }
    const ret:Partial<Notification> = {
      from: 'invitations/v1',
      to: reciever,
      type: 'invitation-created',
      secret,
      data: {}
    };

    if (pushObj) {
      ret.push = pushObj;
    }

    return ret;
  },

  malformedNotification(secret) {
    return {secret};
  },

  users: {
    alice: {
      token: 'alice-token',
      account: {username: 'alice'}
    },

    bob: {
      token: 'bob-token',
      account: {username: 'bob'}
    },

    pushNotified: {
      token: 'push-notified-token',
      account: {username: 'push-notified'}
    }
  }
};
