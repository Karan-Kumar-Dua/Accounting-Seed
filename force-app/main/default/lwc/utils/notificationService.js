import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class NotificationService {

  static displayToastMessage(_this, message, title, variant, mode) {
    _this.dispatchEvent(new ShowToastEvent({
      title: title !== undefined ? title : '',
      message: message,
      variant: variant !== undefined ? variant : 'success',
      mode: mode !== undefined ? mode : 'dismissable'
    }));
  }

  static displayCommonToastMessage(_this, message, messageData, title, variant, mode) {
    _this.dispatchEvent(new ShowToastEvent({
      title: title !== undefined ? title : '',
      message: message,
      messageData: messageData,
      variant: variant !== undefined ? variant : 'success',
      mode: mode !== undefined ? mode : 'dismissable'
    }));
  }

  static displayToastLinkMessage(_this, recordId, recordName, message, title, variant) {
    _this.getNavigationUrl(recordId).then(url => {
      const event = new ShowToastEvent({
        title:  title !== undefined ? title : '',
        message: message,
        variant: variant !== undefined ? variant : 'success',
        messageData: [
          recordName,
          {
            url,
            label: 'here'
          }
        ]
      });
      _this.dispatchEvent(event);
    });
  }

}