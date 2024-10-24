import { LightningElement,track, api, wire } from 'lwc';
import { LabelService, NotificationService, KnowledgeBase } from 'c/utils';
import { updateRecord,getRecord } from 'lightning/uiRecordApi';
import {PaymentProcessor} from 'c/sobject';
import getKeys from '@salesforce/apex/CardknoxMerchantKeysHelper.getKeys';
import upsertKeys from '@salesforce/apex/CardknoxMerchantKeysHelper.upsertUserKeys';
import { labels } from "./labels";

export default class CardknoxMerchantKeys extends LightningElement {
    @api recordId;
    @track keys = {};
    @track showContent = true;
    @track spinnerClass = 'slds-show';
    isShowMerchantForm = true;
    labels = { ...labels, ...LabelService };
    helpURL = KnowledgeBase.cardknoxHelp;
    
    @api 
    hideComp() {
        this.showContent = false;
    }

    @wire(getRecord, { recordId: '$recordId', fields: [PaymentProcessor.externalKey, PaymentProcessor.testmode]})
    paymentProcessorRecord({ data, error }) {
        if (data) {
            this.getStoredKeys(data.fields.AcctSeed__External_Key__c.value);
            if(data.fields.AcctSeed__Test_Mode__c.value){
                this.isShowMerchantForm = false;
            }
        }
    };

    async getStoredKeys(externalKey) {
        try {
            let result = await getKeys({ externalKey: externalKey });
            this.keys = Object.assign({}, result);
        } catch (error) {
            this.showToast(error.body.message, this.labels.commonToastErrorTitle, 'error');
        } finally{
            this.spinnerClass = 'slds-hide';
        }
    }
    handleCancelButton() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }
    handleActionButton() { 
        if (this.isValidInputs()) {
            this.upsertKeys();
        }
    }
    isValidInputs() {
        const inputs = this.template.querySelectorAll('lightning-input');
        let isValid = true;
        inputs && inputs.forEach(input => {
            if(!input.checkValidity()) {
                input.reportValidity();
                isValid = false;
            }
        });
        return isValid;
    }
    async upsertKeys() {
        try {
            this.spinnerClass = 'slds-show';
            await upsertKeys({ jsonKeys: JSON.stringify(this.keys), ppRecordId: this.recordId });
            updateRecord({ fields: { Id: this.recordId } });
            this.showToast(this.labels.keysSuccess, this.labels.commonToastSuccessTitle, 'success');
            this.handleCancelButton();
        } catch (error) {
            this.showToast(error.body.message, this.labels.commonToastErrorTitle, 'error');
            this.spinnerClass = 'slds-hide';
        }
    }
    showToast(message,title,variant) {
        NotificationService.displayToastMessage(this, message, title, variant);
    }
    handleValueChange(evt) {
        this.keys[evt.target.dataset.field] = evt.target.value;
    }
    openMerchantForm(evt) {
        evt.preventDefault();
        this.dispatchEvent(new CustomEvent('createaccount'));
    }
    handleInputFocus(evt) {
        let element = this.template.querySelector('lightning-input[data-field="' + evt.target.dataset.field + '"]');
        element.value = evt.target.value === this.labels.hiddenValue ? '' : this.keys[evt.target.dataset.field];
    }
}