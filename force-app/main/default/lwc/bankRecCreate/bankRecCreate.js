import {api, track, wire } from 'lwc';
import {getSObjectValue} from '@salesforce/apex';
import {getRecord, getFieldValue} from 'lightning/uiRecordApi';
import {NavigationService, LabelService} from "c/utils";
import BANK_REC_OBJECT from '@salesforce/schema/Bank_Reconciliation2__c'
import {BankReconciliation} from "c/sobject";
import getPrevNextLastBankRecs from '@salesforce/apex/BankReconciliationHelper.getPrevNextLastBankRecs';
import Labels from './labels';

const FIELDS = [BankReconciliation.modern_br];

const ENTER_DATE_AFTER_BEFORE_ERROR = Labels.INF_DATE_BETWEEN_STMT_BANK_RECONCILIATION;

export default class bankRecCreate extends NavigationService{
    labels = {...LabelService, ...Labels};
    br = BankReconciliation;
    CURRENCY_ISO_CODE = { fieldApiName: 'CurrencyIsoCode', objectApiName: BANK_REC_OBJECT.objectApiName  }
    multiCurrency;
    prevBankRecEndingBalance;

    @api previousBankRecID;
    @api navigationId;

    @track isSpinner = false;
    @track beginningBalance;
    @track disableBegBalance = true;
    @track customUIValidationError;

    isLegacyRecord = false;
    showComponent = false;
    lastBankRec;
    prevBankAccount;
    prevLedger;
    prevGLAV1;
    prevGLAV2;
    prevGLAV3;
    prevGLAV4;
    prevType;
    prevCurrency;
    

    @wire(getPrevNextLastBankRecs, {bankRecId: '$previousBankRecID'})
    wiredRecord({data}) {
        if (data) {
            this.lastBankRec = data.lastBankRec;
            this.nextBankRec = data.nextBankRec;
            this.previousBankRec = data.previousBankRec;
            this.prevBankAccount = getSObjectValue(data.lastBankRec, this.br.bank_account);
            this.prevLedger = getSObjectValue(data.lastBankRec, this.br.ledger);
            this.prevBankRecEndingBalance = getSObjectValue(data.previousBankRec, this.br.ending_balance);
            this.beginningBalance = getSObjectValue(data.previousBankRec, this.br.ending_balance);
            this.prevGLAV1 = getSObjectValue(data.lastBankRec, this.br.gl_account_variable_1);
            this.prevGLAV2 = getSObjectValue(data.lastBankRec, this.br.gl_account_variable_2);
            this.prevGLAV3 = getSObjectValue(data.lastBankRec, this.br.gl_account_variable_3);
            this.prevGLAV4 = getSObjectValue(data.lastBankRec, this.br.gl_account_variable_4);
            this.prevType = getSObjectValue(data.lastBankRec, this.br.type1);
            try {
                this.prevCurrency = getSObjectValue(data.lastBankRec, this.CURRENCY_ISO_CODE);
                this.multiCurrency = true;
              }
            catch(err) {
                this.multiCurrency = false;
              }

            if(this.multiCurrency === 'true'){
                this.prevCurrency = getSObjectValue(data.lastBankRec, this.CURRENCY_ISO_CODE);
            }
            this.hideSpinner();
        }
    }

    @wire(getRecord, { recordId: '$previousBankRecID', fields: FIELDS })
    getRecord({data}) {
        if (data) {
            this.isLegacyRecord = !getFieldValue(data, this.br.modern_br);
            if (this.isLegacyRecord) {
                this.hideSpinner();
            }
            else {
                this.showComponent = true;
            }
        }
    }
    
    get bankRecObjectApiName() { 
        return BANK_REC_OBJECT.objectApiName;
    }
  
    connectedCallback() {
        this.showSpinner();
    }

    handleSave(event) {
        event.preventDefault();
        event.stopPropagation();

        const fields = event.detail.fields;

        const nextEndDate = this.nextBankRec && new Date(getSObjectValue(this.nextBankRec, this.br.end_date));
        const previousEndDate = this.previousBankRec && new Date(getSObjectValue(this.previousBankRec, this.br.end_date));
        const currentEndDate = fields[this.br.end_date.fieldApiName] && new Date(fields[this.br.end_date.fieldApiName]);

        if (!currentEndDate || (currentEndDate > previousEndDate  && (!nextEndDate || currentEndDate < nextEndDate))) {
            this.customUIValidationError = null;
            this.showSpinner();
            this.template.querySelector('lightning-record-edit-form').submit();
        } else {
            this.customUIValidationError = ENTER_DATE_AFTER_BEFORE_ERROR;
        }
    }

    handleSuccess(event){
        this.navigationId = event.detail.id;
        this.hideSpinner();
        this.navigateToViewRecordPage(this.navigationId);
    }

    handleError() {
        this.hideSpinner();
    }

    handleCancel() {
        this.backToRecordHome();
    }

    lightboxCloseEvent() {
        this.navigateToViewRecordPage(this.previousBankRecID);
    }

    backToRecordHome() {
        this.navigateToViewRecordPage(this.previousBankRecID);
    }

    updateBeginningBalance(event){
        this.beginningBalance = event.target.value;
    }

    toggleOverride(event) {
        if(!event.target.value){
            this.beginningBalance = this.prevBankRecEndingBalance;
        }
        this.disableBegBalance = event.target.value ? false : true;
    }

    showSpinner() {
        this.isSpinner = true;
    }

    hideSpinner() {
        this.isSpinner = false;
    }

}