import {LightningElement, api} from 'lwc';
import getCurrentBalance from '@salesforce/apex/GLAccountCurrentBalanceController.getCurrentBalance';
import { LabelService } from 'c/utils';
import Labels from './labels';

export default class CurrentBalanceLine extends LightningElement {

    labels = {...LabelService, ...Labels};
    @api
    recordId;
    @api
    ledgerId
    @api
    errorInTableMode = false;
    @api
    hideIsoCode = false;

    balanceResult;
    error;
    isProcessing = true;

    handleLoad() {
        this.isProcessing = true;
        getCurrentBalance({recordId: this.recordId, ledgerId: this.ledgerId})
            .then(result => {
                this.balanceResult = {
                    balance: result.balance,
                    currencyIsoCode: result.currencyIsoCode,
                    isMultiCurrencyOrganization: result.isMultiCurrencyOrganization
                };
                this.error = undefined;
                this.isProcessing = false;
                this.dispatchEvent(
                    new CustomEvent(
                        'glbalanceresult',
                        {detail: {success: true, balance: result.balance}}
                    )
                );
            })
            .catch(err => {
                this.error = err;
                this.balanceResult = undefined;
                this.isProcessing = false;
                this.dispatchEvent(
                    new CustomEvent(
                        'glbalanceresult',
                        {detail: {success: false}}
                    )
                );
            });
    }

    connectedCallback() {
        this.handleLoad();
    }

}