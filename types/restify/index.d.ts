import { Request } from 'restify';
declare module 'restify' {
   interface Request {
      ganomede?: any;
   }
}
