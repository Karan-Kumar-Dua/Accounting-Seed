import {LightningElement, api} from 'lwc';
import getSettings from '@salesforce/apex/GLAccountCurrentBalanceController.getSettings';
import { LabelService } from 'c/utils';
import Labels from './labels';

export default class CurrentBalance extends LightningElement {

    labels = {...LabelService, ...Labels};
    @api
    recordId;

    collapsed = false;
    isFeatureAvailable = false;
    singleCurrencyMode = true;
    singleLedgerMode = true;
    isProcessing = true;
    ledgers = [];
    baseCurrency;
    isMultiCurrencyOrganization = false;
    total = 0;
    hideTotal = false;
    error;

    handleGlBalanceResult(event) {
        const result = event.detail;
        if (result.success) {
            this.total += result.balance;
        }
        else {
            this.hideTotal = true;
        }
    }

    retrieveSettings() {
        this.isProcessing = true;
        getSettings({recordId: this.recordId})
            .then(result => {
                this.isFeatureAvailable = result.isFeatureAvailable;
                this.singleCurrencyMode = result.singleCurrency;
                this.singleLedgerMode = result.singleLedger;
                this.ledgers = result.ledgers;
                if (this.ledgers.length > 5) {
                    this.collapsed = true;
                }
                this.baseCurrency = result.baseCurrency;
                this.isMultiCurrencyOrganization = result.isMultiCurrencyOrganization;
                this.error = undefined;
                this.isProcessing = false;
            })
            .catch(error => {
                this.error = error;
                this.isProcessing = false;
            });
    }

    connectedCallback() {
        this.retrieveSettings();
    }

}