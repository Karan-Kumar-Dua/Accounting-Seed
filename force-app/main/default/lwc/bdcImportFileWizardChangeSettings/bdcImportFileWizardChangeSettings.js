import {LightningElement, api, track, wire} from 'lwc';
import importBankTransactions from '@salesforce/apex/ImportFileWizardHelper.importBankTransactions';
import getGLAMDefaults from '@salesforce/apex/ImportFileWizardHelper.getGLAMDefaults';
import {ErrorUtils, LabelService} from "c/utils";
import GLAM_OBJECT from '@salesforce/schema/GL_Account_Mapping__c';
import LEDGER_FIELD from '@salesforce/schema/GL_Account_Mapping__c.Ledger__c';
import GL_ACCOUNT_FIELD from '@salesforce/schema/GL_Account_Mapping__c.GL_Account__c';

export default class BdcImportFileWizardChangeSettings extends LightningElement {

    @api importFileDto;
    @track error = { title: LabelService.commonToastErrorTitle };
    @track isSpinner = false;
    ledgerId;
    glAccountId;
    defaults;
    labels = LabelService;

    @api resolveNextStep() {
        let theSubmitBtn = this.template.querySelector('.hiddenSubmitBtn');
        theSubmitBtn.click();
    }

    @wire(getGLAMDefaults, {})
    getDefaults({ data }) {
        if (data) {
            this.defaults = data;
        }
    }

    showSpinner() {
        this.isSpinner = true;
        this.error.msg = null;
    }

    hideSpinner() {
        this.isSpinner = false;
    }

    get defaultLedgerId() {
        return this.defaults && this.defaults[LEDGER_FIELD.fieldApiName];
    }

    get glamObjectApiName() {
        return GLAM_OBJECT.objectApiName;
    }

    get ledgerFieldApiName() {
        return LEDGER_FIELD.fieldApiName;
    }

    get glAccountFieldApiName() {
        return GL_ACCOUNT_FIELD.fieldApiName;
    }

    handleFormValidation(event) {
        event.preventDefault();
        this.showSpinner();
        const fields = event.detail.fields;
        this.ledgerId = fields[LEDGER_FIELD.fieldApiName];
        this.glAccountId = fields[GL_ACCOUNT_FIELD.fieldApiName];
        this.completeFileImport();
    }

    completeFileImport() {
        importBankTransactions({ serializedImportFileDto: JSON.stringify(this.importFileDto), glAccountId: this.glAccountId, ledgerId: this.ledgerId })
            .then(result => {
                this.dispatchEvent(new CustomEvent('nextstepsuccess', { detail: result }));
            })
            .catch(error => {
                this.hideSpinner();
                const parsedError = ErrorUtils.processError(error);
                this.error.msg = parsedError.error;
            });
    }

}