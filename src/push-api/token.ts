import config from '../../config';

export type TokenType = 'apn'|'gcm';

export interface TokenDef {
  username:string;
  app:string;
  type:TokenType;
  device?:string;
  value:string;
}

export interface TokenData {
  type:TokenType;
  device?:string;
  value:string;
}

export class Token {

  key:string;
  type:TokenType;
  device:string;
  value:string;

  static APN = 'apn';
  static GCM = 'gcm';
  static TYPES = [Token.APN, Token.GCM];

  constructor(key:string, {type, device, value}: TokenData) {
    this.key = key;
    this.type = type;
    this.device = device || 'defaultDevice';
    this.value = value;
    if (!this.key) { throw new Error('KeyMissing'); }
    if (!this.type) { throw new Error('TypeMissing'); }
    if (!this.device) { throw new Error('DeviceMissing'); }
    if (!this.value) { throw new Error('ValueMissing'); }
  }

  data() { return this.value; }

  static key(username:string, app:string) {
    return [config.pushApi.tokensPrefix, username, app].join(':');
  }

  static value(type:'apn'|'gcm', device:string) {
    if (device == null) { device = 'defaultDevice'; }
    return [type, device].join(':');
  }

  static fromPayload(data: TokenDef) {
    return new Token(Token.key(data.username, data.app), data);
  }

}

export default Token;
