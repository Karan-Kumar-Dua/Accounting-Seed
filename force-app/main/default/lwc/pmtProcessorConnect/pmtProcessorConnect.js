import { api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import { LabelService, NotificationService, NavigationService } from "c/utils";
import getPaymentProcessorAuthorizationURL from '@salesforce/apex/PaymentProcessorHelper.getPaymentProcessorAuthorizationURL';

export default class PmtProcessorConnect extends NavigationService {
  labels = LabelService;
  @api
  recordId;

  @wire (getPaymentProcessorAuthorizationURL, { paymentProcessorId: '$recordId' })
  authLink;

  @wire(getRecord, { recordId: '$recordId', layoutTypes: ['Full'], modes: ['View']})
  paymentProcessor;

  get paymentType() {
    return this.paymentProcessor.data ? this.paymentProcessor.data.fields.AcctSeed__Type__c.value : '';
  }
  get isTestMode() {
    return this.paymentProcessor.data ? this.paymentProcessor.data.fields.AcctSeed__Test_Mode__c.value : '';
  }
  get note() {
    return this.labels.connectNote.replace('{0}', this.paymentType);
  }
  cancel() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  connect() {
    if (this.authLink.data) {
      window.open(this.authLink.data, '_self');
    } else if (this.authLink.error) {
      NotificationService.displayToastMessage(
            this,
            this.authLink.error?.body?.message,
            LabelService.commonToastErrorTitle,
            'error'
        );
    }
  }

}