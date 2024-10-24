import { LightningElement, api } from 'lwc';
import updateFile from '@salesforce/apex/FileManagerController.updateFile';
import getFileId from '@salesforce/apex/FileManagerController.getFileId';
import { NotificationService, LabelService } from 'c/utils';
import Labels from './labels';

export default class FileManager extends LightningElement {

    @api recordId;
    @api objectApiName;
    @api fieldName;

    file = '';
    error = '';
    cardTitle = '';
    fileId = '';

    showSpinner = false;

    labels = { ...Labels, ...LabelService };

    connectedCallback() {
        this.setCardTitle();
        this.callApexForFileId();
    }

    callApexForFileId() {
        getFileId({ recordId: this.recordId, objectApiName: this.objectApiName,fieldName: this.fieldName })
            .then(result => {
                this.fileId = result;
            });
    }

    setCardTitle() {
        if (this.objectApiName === 'AcctSeed__Ledger__c') {
            this.cardTitle = this.labels.INF_FILE_MANAGER_LEDGER_LOGO_TITLE;
        } else if (this.objectApiName === 'AcctSeed__Bank_Account__c' && this.fieldName === 'Signature_Block__c') {
            this.cardTitle = this.labels.INF_FILE_MANAGER_BANK_ACCOUNT_SIGNATURE_BLOCK_TITLE;
        }
        else if(this.objectApiName === 'AcctSeed__Bank_Account__c' && this.fieldName === 'Signature_Block_2__c'){
            this.cardTitle = this.labels.INF_FILE_MANAGER_BANK_ACCOUNT_SIGNATURE_BLOCK_2_TITLE;

        }
    }

    handleUploadFinished(event) {

        this.fileId = null;
        this.file = event.detail.files[0];
        const documentId = event.detail.files[0].documentId;

        const fileDetail = {
            'documentId': documentId,
            'record_id': this.recordId,
            'object_api_name': this.objectApiName
        }

        this.showSpinner = true;

        let successMessage;

        if (this.objectApiName === 'AcctSeed__Ledger__c') {
            successMessage = this.labels.INF_FILE_MANAGER_LEDGER_LOGO_SUCCESS;
        } else if (this.objectApiName === 'AcctSeed__Bank_Account__c') {
            successMessage = this.labels.INF_FILE_MANAGER_BANK_ACCOUNT_SIGNATURE_BLOCK_SUCCESS;
        }

        updateFile({ fileDetailsParam: JSON.stringify(fileDetail),fieldName: this.fieldName }).then(result => {
            this.fileId = result;
            this.file = null;
            this.showSpinner = false;
            NotificationService.displayToastMessage(
                this,
                successMessage,
                this.labels.commonSuccess
            );
        }).catch(error => {
            this.file = null;
            this.showSpinner = false;
            NotificationService.displayToastMessage(
                this,
                error.body.message,
                this.labels.commonToastErrorTitle,
                this.labels.commonErrorText
            );
        })

    }

    get fileName() {
        if (this.file != null) {
            return this.file.name;
        } else {
            return null;
        }
    }

}