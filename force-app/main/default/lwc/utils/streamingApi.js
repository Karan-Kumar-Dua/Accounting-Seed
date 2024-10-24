import { subscribe, unsubscribe, onError } from 'lightning/empApi';
const INTERNAL_ERRORS = [
  'Unknown client',
  'Authentication invalid',
  'Handshake denied'
]

export default class StreamingApi {

  channelName = '';
  subscription = {};
  customErrorCallback;
  responseError;

  // Handles subscribe button click
  handleSubscribe(messageCallback) {
    // Invoke subscribe method of empApi. Pass reference to messageCallback
    subscribe(this.channelName, -1, messageCallback).then(response => {
      // Response contains the subscription information on subscribe call
      this.subscription = response;
    });
    this.registerErrorListener(this.customErrorCallback);
  }

  // Handles unsubscribe button click
  handleUnsubscribe() {
    // Invoke unsubscribe method of empApi
    unsubscribe(this.subscription, () => {
      // Response is true for successful unsubscribe
    });
  }

  registerErrorListener(errorCallback = this.defaultErrorCallback) {
    // Invoke onError empApi method
    onError(errorCallback);
  }

  defaultErrorCallback = error => {
    this.responseError = error;
  }

  isInternalError = errorMsg => INTERNAL_ERRORS.some(a =>errorMsg.includes(a));

}