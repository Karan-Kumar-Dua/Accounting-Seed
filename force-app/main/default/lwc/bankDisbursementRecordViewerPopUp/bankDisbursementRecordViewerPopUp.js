import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi'
import getFieldSetFields from '@salesforce/apex/BankDisbursementManager.getFieldSetFields';
import {bankDisbursementPopUpLabels} from './bankDisbursementRecordViewerPopUpLabels';

export default class BankDisbursementRecordViewerPopUp extends LightningElement {

    labelFactory = { ...bankDisbursementPopUpLabels() };
    @api detailrecordid;
    @api detailrecordname;
    @api isModalOpen = false;
    @api objectApiName;
    @track fields = [];
    objectLabel;
    objectIcon;
    showSpinner = true;

    get fieldSetName() {
        return this.labelFactory.BANK_DISBURSEMENT_SEARCH_FIELDSET;
    }

    get cashDisbursementObjectLabel() {
        return this.labelFactory.COMMON_CASH_DISBURSEMENT;
    }

    get journalEntryLineObjectLabel() {
        return this.labelFactory.COMMON_JOURNAL_ENTRY_LINE;
    }
    
    @wire(getRecord, { recordId: "$detailrecordid", layoutTypes: ["Compact"] })
    wiredRecord({ error, data }) {
        if (data) {
            this.objectApiName = data.apiName;
        } else if (error) {
            NotificationService.displayToastMessage(
                this,
                JSON.stringify(err),
                this.labelFactory.ERR_IN_OBJ_DETAILS,
                this.labelFactory.commonErrorText
            );
        }
    }
    
    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    objectInfo({ error, data }) {
        if (data) {
            this.objectLabel = data.label;
            if(this.objectLabel == this.cashDisbursementObjectLabel){
                this.objectIcon = "custom:custom41";
            }else if(this.objectLabel == this.journalEntryLineObjectLabel){
                this.objectIcon = "custom:custom90";
            }
        }  else if (error) {
            this.fields = undefined;
            NotificationService.displayToastMessage(
                this,
                JSON.stringify(err),
                this.labelFactory.ERR_IN_OBJ_DETAILS,
                this.labelFactory.commonErrorText
            );
        }
        this.showSpinner = false;
    }

    @wire(getFieldSetFields, { objectName: '$objectApiName', fieldSetName: '$fieldSetName' })
    wiredFields({ error, data }) {
        if (data) {
            this.fields = data.map(field => ({ fieldPath: field }));
        } else if (error) {
            this.fields = undefined;
            NotificationService.displayToastMessage(
                this,
                JSON.stringify(err),
                this.labelFactory.ERR_IN_OBJ_DETAILS,
                this.labelFactory.commonErrorText
            );
        }
        this.showSpinner = false;
    }

    closeModal() {
        this.isModalOpen = false;
        const closePopUpEvent = new CustomEvent('closepopup', {
            detail: this.isModalOpen
        });
        this.dispatchEvent(closePopUpEvent);
    }
}