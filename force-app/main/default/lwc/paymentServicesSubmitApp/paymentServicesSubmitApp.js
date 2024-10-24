import { LightningElement, api, track, wire } from 'lwc';
import { Ledger } from "c/sobject";
import { ErrorUtils, NotificationService, LabelService } from "c/utils";
import PaymentServicesSubmitAppHelper from './PaymentServicesSubmitAppHelper';
import { applyPaymentLabels } from './labels';
import postMessageToSQS from '@salesforce/apex/APAutomationService.postMessage';
import { CloseActionScreenEvent } from 'lightning/actions';
import {getRecord} from 'lightning/uiRecordApi';

const CONSTANTS = {NOT_ENROLLED: 'Not Enrolled', DECLINED: 'Declined'};

export default class ApplyPaymentService extends LightningElement {

    @api recordId;

    @track isSpinner = true;
    @track error;
    @track isError;
    @track errorForTransactionalLedger;
    /*variable used to store the information that need to send in accountingSeedInfoBox as LWC:spread
      and passed the icon related properties based on type of messgae with boxtheme e.g. in case of
      error icon, pass boxTheme as a slds-theme_error and it will apply css to child component
      drectly from renderedCallback as AccountingSeedInfoBox is light dom 
    */
    @track properties = {
        iconName: 'utility:info', iconTitle: 'Info', 
        boxTheme: 'slds-theme_shade', infoText: applyPaymentLabels()?.PAYMENT_APPLICATION_PROCESS_DESCRIPTION
    };
    @track fields = [Ledger.PaymentServicesEnrollmentStatus, Ledger.type1];

    ledgerFields = Ledger;
    paymentServiceHelper = new PaymentServicesSubmitAppHelper();
    labelFactory = { ...LabelService, ...applyPaymentLabels() };
    disableSubmit = false;

    renderedCallback() {
        try {
            //query the infoBox class of accountingSeedInfoBox Html and then add theme in it
            let childDiv = this.template.querySelector('.infoBox');
            childDiv.classList.add(this.properties.boxTheme);
        } catch (err) {
            NotificationService.displayToastMessage(this, err.message, LabelService.commonToastErrorTitle + ':', LabelService.commonErrorText);
        }
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: '$fields'
    })
    fetchCommonRecord({ data, error }) {
        if (data) {
            const paymentEnrollValue = data.fields[Ledger.PaymentServicesEnrollmentStatus.fieldApiName].value;
            if (paymentEnrollValue && (paymentEnrollValue.trim().toLowerCase() !== CONSTANTS.NOT_ENROLLED.trim().toLowerCase() && paymentEnrollValue.trim().toLowerCase() !== CONSTANTS.DECLINED.trim().toLowerCase())) {
                this.properties = { ...this.properties, infoText: this.labelFactory.APPLICATION_UNAVAILABLE };
                this.disableSubmit = true;
            }

            const typeValue = data.fields[Ledger.type1.fieldApiName].value;
            if(typeValue !== this.labelFactory.COMMON_TRANSACTIONAL){
                this.errorForTransactionalLedger = this.labelFactory.ERR_PAYMENT_SERVICES;
                this.disableSubmit = true;
                this.properties = {
                    iconName: 'utility:error', iconTitle: 'Error',
                    boxTheme: 'slds-theme_shade', infoText: this.labelFactory.ERR_ON_PAYMENT_SERVICE_FOR_TRASACTIONAL_LEDGER
                };
            }
        }   
    }

    getRemoteCallData(promiseFunc) {
        promiseFunc.then(item => {
            this.handleCancel();
        })
            .catch(err => {
                NotificationService.displayToastMessage(this, err, this.labelFactory.ERR_PAYMENT_SERVICES + ':', this.labelFactory.commonErrorText);
                this.handleCancel();
            })

    }

    handleSubmit(event) {

        try {
            event.preventDefault(); // stop the form from submitting
            this.isSpinner = true;
            const fields = event.detail.fields;
            this.queryDOMElemnts('record_edit_form').submit(fields);
        }
        catch (err) {
            NotificationService.displayToastMessage(this, err.message, LabelService.commonToastErrorTitle + ':', LabelService.commonErrorText);
        }
    }

    handleSuccess(event) {
        this.isSpinner = true;
        // call apex dynamically 
        this.getRemoteCallData(this.paymentServiceHelper.remoteCall(postMessageToSQS, { recordIds: [this.recordId], action: 'SUBMIT_APPLICATION' }, this));
    }

    handleCancel() {
        //close quick action on cancel press
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleLoad() {
        this.isSpinner = false;
    }

    processError(e) {
        let { isError, error } = ErrorUtils.processError(e);
        if (isError) {
            this.error = error;
            this.isError = isError;
        } else {
            this.error = error.toString();
            this.isError = true;
        }
    }

    handleErrors(event) {
        NotificationService.displayToastMessage(this, event.detail.detail, LabelService.commonToastErrorTitle + ':', LabelService.commonErrorText);
        this.handleCancel();
    }

    //query all elements based on passed selector using ref api
    queryDOMElemnts = (selectorName) => this.refs[selectorName];

}